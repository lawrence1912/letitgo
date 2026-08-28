import Testing
@testable import AppCore
@testable import Persistence

@Suite("导航")
struct NavigationTests {
    @Test("每个分区都有标题和图标")
    func sidebarItemsAreComplete() {
        for item in SidebarItem.allCases {
            #expect(!item.title.isEmpty)
            #expect(!item.systemImage.isEmpty)
        }
    }
}

@Suite("全局状态")
@MainActor
struct AppStateTests {
    @Test("默认落在概览")
    func defaultSelection() {
        #expect(AppState().selection == .overview)
    }

    @Test("初始没有错误和状态文案")
    func cleanInitialState() {
        let state = AppState()
        #expect(state.presentedError == nil)
        #expect(state.statusMessage == nil)
    }
}

@Suite("内存仓库")
struct InMemoryItemRepositoryTests {
    @Test("初始为空")
    func startsEmpty() async throws {
        let repository = InMemoryItemRepository()
        #expect(try await repository.fetchAll().isEmpty)
    }

    @Test("按创建时间升序返回")
    func sortsByCreatedAt() async throws {
        let older = Item(title: "先", createdAt: .init(timeIntervalSince1970: 100))
        let newer = Item(title: "后", createdAt: .init(timeIntervalSince1970: 200))
        let repository = InMemoryItemRepository(seed: [newer, older])

        let result = try await repository.fetchAll()
        #expect(result.map(\.title) == ["先", "后"])
    }

    @Test("插入后能读回")
    func insertThenFetch() async throws {
        let repository = InMemoryItemRepository()
        let item = Item(title: "一条")
        try await repository.insert(item)
        #expect(try await repository.fetchAll() == [item])
    }

    @Test("删不存在的 id 会抛 notFound")
    func deleteMissingThrows() async throws {
        let repository = InMemoryItemRepository()
        await #expect(throws: AppError.notFound) {
            try await repository.delete(id: Item(title: "x").id)
        }
    }
}
