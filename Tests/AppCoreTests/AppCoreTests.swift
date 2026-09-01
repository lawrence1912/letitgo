import Testing
@testable import AppCore
@testable import Persistence

@Suite("导航")
struct NavigationTests {
    @Test("每个分区都有标题、说明和图标")
    func sidebarItemsAreComplete() {
        for item in SidebarItem.allCases {
            #expect(!item.title.isEmpty)
            #expect(!item.subtitle.isEmpty)
            #expect(!item.systemImage.isEmpty)
        }
    }

    @Test("每个分区都归在某一组里，组拼起来正好是全部")
    func groupsCoverEveryItemExactlyOnce() {
        let grouped = SidebarGroup.allCases.flatMap(\.items)

        #expect(Set(grouped) == Set(SidebarItem.allCases))
        #expect(grouped.count == SidebarItem.allCases.count)
    }

    // MARK: - 快捷键编号
    //
    // 菜单（AppCommands）和概览的卡片读的是同一个 `shortcutNumber`，
    // 所以这里钉住它，两边就不会对不上。

    @Test("编号只发给能用的分区，按声明顺序数下来")
    func shortcutNumbersSkipPlaceholders() {
        let numbered = SidebarItem.allCases.filter { !$0.isPlaceholder }

        for (index, item) in numbered.enumerated() where index < 9 {
            #expect(item.shortcutNumber == index + 1)
        }
        // 留白分区不占号 —— 九个位置得留给真能干活的东西
        for item in SidebarItem.allCases where item.isPlaceholder {
            #expect(item.shortcutNumber == nil)
        }
    }

    /// `KeyEquivalent(Character("10"))` 会在运行时直接崩 ——
    /// 编号必须是一位数，第 10 个分区开始就不该有快捷键。
    @Test("编号只能是一位数，第十个能用的分区开始就没有了")
    func shortcutNumbersAreAlwaysASingleDigit() {
        for item in SidebarItem.allCases {
            guard let number = item.shortcutNumber else { continue }
            #expect(String(number).count == 1)
        }
        let numbered = SidebarItem.allCases.filter { !$0.isPlaceholder }
        #expect(numbered.dropFirst(9).allSatisfy { $0.shortcutNumber == nil })
    }

    // MARK: - 图标色

    @Test("快速入口里每个分区的颜色都不一样 —— 颜色是用来区分的")
    func quickLaunchTintsAreAllDifferent() {
        let tints = SidebarItem.quickLaunch.map(\.tint)

        #expect(Set(tints).count == tints.count)
    }

    @Test("能用的分区都上了色，留白的才留在中性档")
    func onlyPlaceholdersStayNeutral() {
        for item in SidebarItem.quickLaunch {
            #expect(item.tint != .neutral, "\(item.rawValue) 还没分配颜色")
        }
    }

    // MARK: - 概览的快速入口

    @Test("快速入口不列概览自己 —— 点进去还是这一页")
    func quickLaunchExcludesItself() {
        #expect(!SidebarItem.quickLaunch.contains(.overview))
    }

    @Test("快速入口不列留白分区 —— 那是死路，不是入口")
    func quickLaunchExcludesPlaceholders() {
        #expect(SidebarItem.quickLaunch.allSatisfy { !$0.isPlaceholder })
        #expect(SidebarItem.allCases.contains { $0.isPlaceholder })   // 确实还有留白，测的不是空集
    }

    @Test("除了概览和留白，别的分区都得在快速入口里 —— 加了新分区忘了露出来会红")
    func quickLaunchCoversEveryUsableSection() {
        let expected = SidebarItem.allCases.filter { $0 != .overview && !$0.isPlaceholder }

        #expect(SidebarItem.quickLaunch == expected)
        #expect(!SidebarItem.quickLaunch.isEmpty)
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
