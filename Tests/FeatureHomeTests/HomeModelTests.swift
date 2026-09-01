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
    func delete(id: Item.ID) async throws {}
}

/// 只有写会失败的仓库，用来验证「写抛错」那一半。
private struct ReadOnlyItemRepository: ItemRepository {
    func fetchAll() async throws -> [Item] { [] }
    func insert(_ item: Item) async throws { throw AppError.storage("磁盘满了") }
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
        let seed = [Item(title: "甲"), Item(title: "乙")]
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

    // MARK: - 写

    @Test("新建之后列表里就有了")
    func createAppends() async throws {
        let model = HomeModel(repository: InMemoryItemRepository())
        await model.load()

        let created = try await model.create(title: "新的一条")

        #expect(created.title == "新的一条")
        #expect(model.items.map(\.title) == ["新的一条"])
        #expect(model.error == nil)
    }

    @Test("正文和标题一起存下来")
    func createKeepsContent() async throws {
        let model = HomeModel(repository: InMemoryItemRepository())
        let created = try await model.create(title: "买菜", content: "西红柿\n鸡蛋")

        #expect(created.content == "西红柿\n鸡蛋")
        #expect(model.items.map(\.content) == ["西红柿\n鸡蛋"])
    }

    @Test("不给正文也能新建 —— 一行标题就是一条备忘")
    func createWithoutContent() async throws {
        let model = HomeModel(repository: InMemoryItemRepository())
        let created = try await model.create(title: "买牛奶")

        #expect(created.content.isEmpty)
    }

    @Test("正文只切两头的空白，中间的空行是用户排的版，留着")
    func createTrimsContentEdgesOnly() async throws {
        let model = HomeModel(repository: InMemoryItemRepository())
        let created = try await model.create(title: "分段", content: "\n\n上半段\n\n下半段\n  ")

        #expect(created.content == "上半段\n\n下半段")
    }

    @Test("标题前后的空白会被去掉")
    func createTrimsTitle() async throws {
        let model = HomeModel(repository: InMemoryItemRepository())
        let created = try await model.create(title: "  留白  ")

        #expect(created.title == "留白")
    }

    @Test("只有空白的标题会被拒绝，且不写进仓库")
    func createRejectsBlankTitle() async throws {
        let repository = InMemoryItemRepository()
        let model = HomeModel(repository: repository)

        await #expect(throws: AppError.invalidInput("标题不能为空。")) {
            try await model.create(title: "   \n  ")
        }
        #expect(try await repository.fetchAll().isEmpty)
    }

    @Test("createdAt 用的是注入的时钟，不是真实时间")
    func createUsesInjectedClock() async throws {
        let frozen = Date(timeIntervalSince1970: 1_000)
        let model = HomeModel(repository: InMemoryItemRepository(), now: { frozen })

        let created = try await model.create(title: "定时")
        #expect(created.createdAt == frozen)
    }

    @Test("写失败：错误抛给调用方（壳会弹全局 alert），不是悄悄收起来")
    func createThrowsOnFailure() async {
        let model = HomeModel(repository: ReadOnlyItemRepository())

        await #expect(throws: AppError.storage("磁盘满了")) {
            try await model.create(title: "写不进去")
        }
    }

    @Test("删除后列表里就没了")
    func deleteRemoves() async throws {
        let keep = Item(title: "留着")
        let drop = Item(title: "删掉")
        let model = HomeModel(repository: InMemoryItemRepository(seed: [keep, drop]))
        await model.load()

        try await model.delete(ids: [drop.id])

        #expect(model.items.map(\.title) == ["留着"])
    }

    @Test("一次删多条")
    func deleteMultiple() async throws {
        let items = [Item(title: "甲"), Item(title: "乙"), Item(title: "丙")]
        let model = HomeModel(repository: InMemoryItemRepository(seed: items))
        await model.load()

        try await model.delete(ids: [items[0].id, items[2].id])

        #expect(model.items.map(\.title) == ["乙"])
    }

    @Test("没选中任何行就按 ⌫ 是空操作，不报错")
    func deleteNothingIsNoop() async throws {
        let model = HomeModel(repository: InMemoryItemRepository(seed: [Item(title: "甲")]))
        await model.load()

        try await model.delete(ids: [])

        #expect(model.items.count == 1)
    }

    @Test("删掉别人已经删过的 id 会抛 notFound")
    func deleteMissingThrows() async {
        let model = HomeModel(repository: InMemoryItemRepository())

        await #expect(throws: AppError.notFound) {
            try await model.delete(ids: [Item(title: "幽灵").id])
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
        try await recovered.create(title: "恢复")
        #expect(recovered.error == nil)
    }
}
