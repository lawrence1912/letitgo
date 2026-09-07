import Foundation
import Testing
import AppCore
import Persistence
@testable import FeatureHome

/// 读会失败的仓库，用来验证「读吞错」那一半。
/// 这就是「依赖从 init 注入」的回报 —— 不用碰任何全局状态。
private struct FailingItemRepository: ItemRepository {
    func fetchAll() async throws -> [Item] { throw AppError.storage("磁盘炸了") }
    func insert(_ item: Item) async throws {}
    func update(_ item: Item) async throws {}
    func delete(id: Item.ID) async throws {}
}

/// 数写了几次的仓库。用来验证「拖回原来那一列不写盘」——
/// 这件事只能从**没有发生的写**上看出来，读状态是看不见的。
private actor CountingItemRepository: ItemRepository {
    private var storage: [Item.ID: Item]
    private(set) var updates = 0

    init(seed: [Item] = []) {
        storage = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    func fetchAll() async throws -> [Item] {
        storage.values.sorted { $0.createdAt < $1.createdAt }
    }
    func insert(_ item: Item) async throws { storage[item.id] = item }
    func update(_ item: Item) async throws {
        guard storage[item.id] != nil else { throw AppError.notFound }
        updates += 1
        storage[item.id] = item
    }
    func delete(id: Item.ID) async throws {
        guard storage.removeValue(forKey: id) != nil else { throw AppError.notFound }
    }
}

/// 只有写会失败的仓库，用来验证「写抛错」那一半。
private struct ReadOnlyItemRepository: ItemRepository {
    func fetchAll() async throws -> [Item] { [] }
    func insert(_ item: Item) async throws { throw AppError.storage("磁盘满了") }
    func update(_ item: Item) async throws { throw AppError.storage("磁盘满了") }
    func delete(id: Item.ID) async throws { throw AppError.storage("磁盘满了") }
}

@Suite("HomeModel")
@MainActor
struct HomeModelTests {

    // MARK: - 读

    @Test("空仓库载入后是空列表，且没有错误")
    func loadsEmpty() async {
        let model = HomeModel(repository: InMemoryItemRepository())
        await model.load()

        #expect(model.items.isEmpty)
        #expect(model.error == nil)
        #expect(model.isLoading == false)
    }

    @Test("载入仓库里已有的数据")
    func loadsSeededItems() async {
        let seed = [Item(text: "甲"), Item(text: "乙")]
        let model = HomeModel(repository: InMemoryItemRepository(seed: seed))
        await model.load()

        #expect(model.items.count == 2)
        #expect(model.error == nil)
    }

    @Test("读失败：错误收进 error 属性，不抛出去（界面就地显示错误态）")
    func loadSwallowsFailure() async {
        let model = HomeModel(repository: FailingItemRepository())
        await model.load()

        #expect(model.error == .storage("磁盘炸了"))
        #expect(model.items.isEmpty)
        #expect(model.isLoading == false)
    }

    // MARK: - 加

    @Test("加一条之后列表里就有了，而且是没做完的")
    func createAppends() async throws {
        let model = HomeModel(repository: InMemoryItemRepository())
        await model.load()

        let created = try await model.create(text: "买牛奶")

        #expect(created.text == "买牛奶")
        #expect(created.isDone == false)
        #expect(model.items.map(\.text) == ["买牛奶"])
        #expect(model.error == nil)
    }

    @Test("前后的空白会被去掉")
    func createTrimsEdges() async throws {
        let model = HomeModel(repository: InMemoryItemRepository())
        let created = try await model.create(text: "  留白  ")

        #expect(created.text == "留白")
    }

    @Test("中间的换行是用户排的版，留着 —— 粘一段清单进来就是一条")
    func createKeepsInnerNewlines() async throws {
        let model = HomeModel(repository: InMemoryItemRepository())
        let created = try await model.create(text: "\n买菜\n西红柿\n鸡蛋\n  ")

        #expect(created.text == "买菜\n西红柿\n鸡蛋")
    }

    @Test("只有空白的一条会被拒绝，且不写进仓库")
    func createRejectsBlankText() async throws {
        let repository = InMemoryItemRepository()
        let model = HomeModel(repository: repository)

        await #expect(throws: AppError.invalidInput("待办不能为空。")) {
            try await model.create(text: "   \n  ")
        }
        #expect(try await repository.fetchAll().isEmpty)
    }

    @Test("createdAt 用的是注入的时钟，不是真实时间")
    func createUsesInjectedClock() async throws {
        let frozen = Date(timeIntervalSince1970: 1_000)
        let model = HomeModel(repository: InMemoryItemRepository(), now: { frozen })

        let created = try await model.create(text: "定时")
        #expect(created.createdAt == frozen)
    }

    @Test("写失败：错误抛给调用方（壳会弹全局 alert），不是悄悄收起来")
    func createThrowsOnFailure() async {
        let model = HomeModel(repository: ReadOnlyItemRepository())

        await #expect(throws: AppError.storage("磁盘满了")) {
            try await model.create(text: "写不进去")
        }
    }

    // MARK: - 打勾

    @Test("打勾之后这条是完成的")
    func toggleMarksDone() async throws {
        let item = Item(text: "买牛奶")
        let model = HomeModel(repository: InMemoryItemRepository(seed: [item]))
        await model.load()

        let toggled = try await model.toggle(id: item.id)

        #expect(toggled.isDone)
        #expect(model.items.map(\.isDone) == [true])
    }

    @Test("再点一下就取消打勾 —— 同一个方框，来回都走这一个方法")
    func toggleTwiceComesBack() async throws {
        let item = Item(text: "买牛奶", isDone: true)
        let model = HomeModel(repository: InMemoryItemRepository(seed: [item]))
        await model.load()

        try await model.toggle(id: item.id)
        #expect(model.items.map(\.isDone) == [false])

        try await model.toggle(id: item.id)
        #expect(model.items.map(\.isDone) == [true])
    }

    @Test("打勾会落库 —— 重新载入之后还是完成的")
    func togglePersists() async throws {
        let item = Item(text: "买牛奶")
        let repository = InMemoryItemRepository(seed: [item])
        let model = HomeModel(repository: repository)
        await model.load()

        try await model.toggle(id: item.id)

        #expect(try await repository.fetchAll().map(\.isDone) == [true])
    }

    @Test("打勾打在别人已经删掉的一条上会抛 notFound，不会凭空造一条出来")
    func toggleMissingThrows() async throws {
        let repository = InMemoryItemRepository()
        let model = HomeModel(repository: repository)
        await model.load()

        await #expect(throws: AppError.notFound) {
            try await model.toggle(id: Item(text: "幽灵").id)
        }
        #expect(try await repository.fetchAll().isEmpty)
    }

    @Test("打勾会记下完成时间，用的是注入的时钟")
    func toggleStampsCompletedAt() async throws {
        let frozen = Date(timeIntervalSince1970: 5_000)
        let item = Item(text: "买牛奶")
        let model = HomeModel(repository: InMemoryItemRepository(seed: [item]), now: { frozen })
        await model.load()

        let done = try await model.setDone(true, id: item.id)

        #expect(done.completedAt == frozen)
    }

    @Test("取消打勾会把完成时间清掉 —— 留着的话「已完成」那列的排序里会躺着上辈子的时间戳")
    func undoneClearsCompletedAt() async throws {
        let item = Item(text: "买牛奶", isDone: true, completedAt: Date(timeIntervalSince1970: 5_000))
        let model = HomeModel(repository: InMemoryItemRepository(seed: [item]))
        await model.load()

        let undone = try await model.setDone(false, id: item.id)

        #expect(undone.isDone == false)
        #expect(undone.completedAt == nil)
    }

    @Test("拖回它本来就在的那一列是空操作：不写盘，完成时间也不会被刷新")
    func setDoneToSameStateWritesNothing() async throws {
        let stamped = Date(timeIntervalSince1970: 5_000)
        let item = Item(text: "写周报", isDone: true, completedAt: stamped)
        let repository = CountingItemRepository(seed: [item])
        let model = HomeModel(repository: repository, now: { Date(timeIntervalSince1970: 9_999) })
        await model.load()

        let unchanged = try await model.setDone(true, id: item.id)

        #expect(unchanged.completedAt == stamped)
        #expect(await repository.updates == 0)
    }

    @Test("setDone 用在别人已经删掉的一条上会抛 notFound")
    func setDoneMissingThrows() async {
        let model = HomeModel(repository: InMemoryItemRepository())

        await #expect(throws: AppError.notFound) {
            try await model.setDone(true, id: Item(text: "幽灵").id)
        }
    }

    // MARK: - 两列

    @Test("左列只有没做完的，最新的排最前")
    func pendingIsNewestFirst() async {
        let seed = [
            Item(text: "先", createdAt: Date(timeIntervalSince1970: 100)),
            Item(text: "做完了", isDone: true, createdAt: Date(timeIntervalSince1970: 150)),
            Item(text: "后", createdAt: Date(timeIntervalSince1970: 200)),
        ]
        let model = HomeModel(repository: InMemoryItemRepository(seed: seed))
        await model.load()

        #expect(model.pending.map(\.text) == ["后", "先"])
    }

    @Test("右列按打勾的时间倒序 —— 刚拖过去的那张在列首，不是按写下的时间")
    func completedIsSortedByCompletionTime() async {
        // 「早写的」后完成，所以它该排在前面 —— 按 createdAt 排就会反过来。
        let seed = [
            Item(
                text: "早写的",
                isDone: true,
                createdAt: Date(timeIntervalSince1970: 100),
                completedAt: Date(timeIntervalSince1970: 900)
            ),
            Item(
                text: "晚写的",
                isDone: true,
                createdAt: Date(timeIntervalSince1970: 200),
                completedAt: Date(timeIntervalSince1970: 800)
            ),
        ]
        let model = HomeModel(repository: InMemoryItemRepository(seed: seed))
        await model.load()

        #expect(model.completed.map(\.text) == ["早写的", "晚写的"])
    }

    @Test("没有完成时间的（升级前存的）回落到写下的时间，不会把整列排乱")
    func completedFallsBackToCreatedAt() async {
        let seed = [
            Item(text: "老的", isDone: true, createdAt: Date(timeIntervalSince1970: 100)),
            Item(
                text: "新的",
                isDone: true,
                createdAt: Date(timeIntervalSince1970: 200),
                completedAt: Date(timeIntervalSince1970: 300)
            ),
        ]
        let model = HomeModel(repository: InMemoryItemRepository(seed: seed))
        await model.load()

        #expect(model.completed.map(\.text) == ["新的", "老的"])
    }

    @Test("remaining 只数没做完的")
    func remainingCountsUndone() async throws {
        let seed = [Item(text: "甲"), Item(text: "乙", isDone: true), Item(text: "丙")]
        let model = HomeModel(repository: InMemoryItemRepository(seed: seed))
        await model.load()

        #expect(model.remaining == 2)

        try await model.toggle(id: seed[0].id)
        #expect(model.remaining == 1)
    }

    // MARK: - 删

    @Test("删除后列表里就没了")
    func deleteRemoves() async throws {
        let keep = Item(text: "留着")
        let drop = Item(text: "删掉")
        let model = HomeModel(repository: InMemoryItemRepository(seed: [keep, drop]))
        await model.load()

        try await model.delete(ids: [drop.id])

        #expect(model.items.map(\.text) == ["留着"])
    }

    @Test("一次删多条")
    func deleteMultiple() async throws {
        let items = [Item(text: "甲"), Item(text: "乙"), Item(text: "丙")]
        let model = HomeModel(repository: InMemoryItemRepository(seed: items))
        await model.load()

        try await model.delete(ids: [items[0].id, items[2].id])

        #expect(model.items.map(\.text) == ["乙"])
    }

    @Test("没选中任何行就按 ⌫ 是空操作，不报错")
    func deleteNothingIsNoop() async throws {
        let model = HomeModel(repository: InMemoryItemRepository(seed: [Item(text: "甲")]))
        await model.load()

        try await model.delete(ids: [])

        #expect(model.items.count == 1)
    }

    @Test("删掉别人已经删过的 id 会抛 notFound")
    func deleteMissingThrows() async {
        let model = HomeModel(repository: InMemoryItemRepository())

        await #expect(throws: AppError.notFound) {
            try await model.delete(ids: [Item(text: "幽灵").id])
        }
    }

    @Test("写成功会清掉上一次的读错误")
    func successfulWriteClearsStaleError() async throws {
        // 先制造一次读失败，再换成正常仓库写一条 —— 错误态不该赖着不走。
        let model = HomeModel(repository: FailingItemRepository())
        await model.load()
        #expect(model.error != nil)

        let recovered = HomeModel(repository: InMemoryItemRepository())
        await recovered.load()
        try await recovered.create(text: "恢复")
        #expect(recovered.error == nil)
    }
}
