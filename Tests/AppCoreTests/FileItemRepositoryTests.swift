import Foundation
import Testing
@testable import AppCore
@testable import Persistence

/// 落盘实现的用例。全部走临时目录，不碰真正的应用支持目录。
///
/// 这几条同时也是 `ItemRepository` 这个协议的行为契约 ——
/// 以后换 SwiftData / GRDB 实现时，把构造那一行换掉即可原样复用。
@Suite("文件仓库")
struct FileItemRepositoryTests {

    /// 每个用例一个独立的临时目录，互不干扰；用例结束时删掉。
    /// 不用闭包包一层：`#expect(try await …)` 在闭包体里推不出 throwing 上下文。
    private final class TemporaryFile {
        let url: URL

        init() {
            let directory = URL.temporaryDirectory
                .appending(path: "letitgo-tests-\(UUID().uuidString)")
            url = directory.appending(path: "items.json")
        }

        deinit {
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }
    }

    @Test("文件还不存在时读出来是空的，不是错误")
    func missingFileIsEmpty() async throws {
        let temp = TemporaryFile()
        let repository = FileItemRepository(fileURL: temp.url)

        #expect(try await repository.fetchAll().isEmpty)
        // 只读不该凭空造出文件
        #expect(!FileManager.default.fileExists(atPath: temp.url.path(percentEncoded: false)))
    }

    @Test("写进去的数据换一个实例还读得到 —— 这条就是落盘的意义")
    func survivesNewInstance() async throws {
        let temp = TemporaryFile()
        try await FileItemRepository(fileURL: temp.url).insert(Item(text: "留下来"))

        // 全新实例 = 模拟应用重启，缓存是空的，只能从磁盘读。
        let reader = FileItemRepository(fileURL: temp.url)
        #expect(try await reader.fetchAll().map(\.text) == ["留下来"])
    }

    @Test("按创建时间升序返回")
    func sortsByCreatedAt() async throws {
        let temp = TemporaryFile()
        let repository = FileItemRepository(fileURL: temp.url)
        try await repository.insert(Item(text: "后", createdAt: .init(timeIntervalSince1970: 200)))
        try await repository.insert(Item(text: "先", createdAt: .init(timeIntervalSince1970: 100)))

        #expect(try await repository.fetchAll().map(\.text) == ["先", "后"])
    }

    @Test("同 id 再插入是覆盖，不是追加")
    func insertSameIDUpdates() async throws {
        let temp = TemporaryFile()
        let repository = FileItemRepository(fileURL: temp.url)
        let original = Item(text: "旧的一条")
        try await repository.insert(original)

        var edited = original
        edited.text = "新的一条"
        try await repository.insert(edited)

        #expect(try await repository.fetchAll().map(\.text) == ["新的一条"])
    }

    @Test("打勾会落盘，换一个实例还是完成的")
    func updatePersists() async throws {
        let temp = TemporaryFile()
        let item = Item(text: "买牛奶")
        try await FileItemRepository(fileURL: temp.url).insert(item)

        var done = item
        done.isDone = true
        try await FileItemRepository(fileURL: temp.url).update(done)

        #expect(try await FileItemRepository(fileURL: temp.url).fetchAll().map(\.isDone) == [true])
    }

    @Test("update 一条不存在的会抛 notFound —— 不是悄悄插一条新的进去")
    func updateMissingThrows() async throws {
        let temp = TemporaryFile()
        let repository = FileItemRepository(fileURL: temp.url)

        await #expect(throws: AppError.notFound) {
            try await repository.update(Item(text: "幽灵", isDone: true))
        }
        #expect(try await repository.fetchAll().isEmpty)
    }

    @Test("删除会落盘，不只是改内存")
    func deletePersists() async throws {
        let temp = TemporaryFile()
        let item = Item(text: "删我")
        let repository = FileItemRepository(fileURL: temp.url)
        try await repository.insert(item)
        try await repository.delete(id: item.id)

        #expect(try await FileItemRepository(fileURL: temp.url).fetchAll().isEmpty)
    }

    @Test("删不存在的 id 会抛 notFound")
    func deleteMissingThrows() async throws {
        let temp = TemporaryFile()
        let repository = FileItemRepository(fileURL: temp.url)

        await #expect(throws: AppError.notFound) {
            try await repository.delete(id: Item(text: "x").id)
        }
    }

    @Test("文件坏掉时抛 storage，而不是崩或者静默当成空")
    func corruptFileSurfacesStorageError() async throws {
        let temp = TemporaryFile()
        try FileManager.default.createDirectory(
            at: temp.url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("这不是 JSON".utf8).write(to: temp.url)

        let repository = FileItemRepository(fileURL: temp.url)
        // 静默当成空最危险：用户会看到一个空列表，然后新建一条把旧数据彻底盖掉。
        await #expect(throws: (any Error).self) {
            _ = try await repository.fetchAll()
        }
    }

    @Test("落盘的 JSON 是人能读的（日期 ISO 8601、键有序）")
    func writesReadableJSON() async throws {
        let temp = TemporaryFile()
        let repository = FileItemRepository(fileURL: temp.url)
        try await repository.insert(
            Item(text: "看得懂", createdAt: .init(timeIntervalSince1970: 0))
        )

        let text = try String(contentsOf: temp.url, encoding: .utf8)
        #expect(text.contains("1970-01-01T00:00:00Z"))
        #expect(text.contains("看得懂"))
        // sortedKeys：createdAt 排在 id 前面
        let createdAtPosition = try #require(text.range(of: "createdAt")).lowerBound
        let idPosition = try #require(text.range(of: "\"id\"")).lowerBound
        #expect(createdAtPosition < idPosition)
    }

    @Test("完成时间跟着一起落盘 —— 「已完成」那一列的排序全靠它")
    func persistsCompletedAt() async throws {
        let temp = TemporaryFile()
        let stamped = Date(timeIntervalSince1970: 1_000)
        try await FileItemRepository(fileURL: temp.url)
            .insert(Item(text: "写周报", isDone: true, completedAt: stamped))

        let items = try await FileItemRepository(fileURL: temp.url).fetchAll()
        #expect(items.map(\.completedAt) == [stamped])
    }

    @Test("多行的一条原样落盘")
    func persistsMultilineText() async throws {
        let temp = TemporaryFile()
        try await FileItemRepository(fileURL: temp.url)
            .insert(Item(text: "买菜\n西红柿\n鸡蛋"))

        let items = try await FileItemRepository(fileURL: temp.url).fetchAll()
        #expect(items.map(\.text) == ["买菜\n西红柿\n鸡蛋"])
    }

    @Test("备忘时代的 items.json 还读得出来 —— 标题和正文拼成一条待办，一个字不丢")
    func readsLegacyMemoItems() async throws {
        let temp = TemporaryFile()
        try FileManager.default.createDirectory(
            at: temp.url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // 改成待办之前，落盘的就是这个样子（标题 + 可选的正文，没有 isDone）。
        // 这条要是红了，用户之前写的**全部**内容会一起消失在
        // 「读不了 items.json」后面。
        let legacy = """
        [
          {
            "createdAt" : "1970-01-01T00:00:00Z",
            "id" : "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
            "title" : "只有标题的那条"
          },
          {
            "content" : "西红柿\\n鸡蛋",
            "createdAt" : "1970-01-01T00:00:01Z",
            "id" : "3F2504E0-4F89-11D3-9A0C-0305E82C3302",
            "title" : "买菜"
          }
        ]
        """
        try Data(legacy.utf8).write(to: temp.url)

        let items = try await FileItemRepository(fileURL: temp.url).fetchAll()

        #expect(items.map(\.text) == ["只有标题的那条", "买菜\n西红柿\n鸡蛋"])
        // 老记录没有 isDone / completedAt，缺席的意思是「还没做」。
        #expect(items.allSatisfy { !$0.isDone })
        #expect(items.allSatisfy { $0.completedAt == nil })
    }
}
