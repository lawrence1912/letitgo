import AppCore
import Foundation
import Observation

/// 一个功能模块的 Model 长什么样 —— 这是给后续功能抄的模板。
///
/// 三条规矩:
///   1. `@MainActor`，UI 状态只在主线程改，不用到处 `await MainActor.run`。
///   2. 依赖从 init 注入（仓库、时钟），不在内部 new 单例，
///      测试里才能塞假实现。
///   3. 对外暴露 `private(set)`，状态只能由 Model 自己的方法改。
///
/// **读吞错、写抛错** —— 这条规矩决定错误显示在哪里:
///   - `load()` 把错误收进 `error` 属性，界面就地显示错误态。整个界面本来
///     就没内容可看，再弹个 alert 只是让用户多点一次「好」。
///   - `create` / `delete` 把错误**抛出去**，由调用方决定怎么呈现（壳里是
///     全局 alert）。写操作是用户主动发起的，失败必须打断他，否则他会以为成了。
@MainActor
@Observable
public final class HomeModel {
    public private(set) var items: [Item] = []
    public private(set) var isLoading = false
    public private(set) var error: AppError?

    private let repository: any ItemRepository
    private let now: @Sendable () -> Date

    public init(
        repository: any ItemRepository,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.now = now
    }

    public func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            items = try await repository.fetchAll()
            Log.data.debug("HomeModel 载入 \(self.items.count, privacy: .public) 条")
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
    }

    /// 新建一条备忘。返回真正落库的那条，方便调用方拿去写状态栏文案。
    ///
    /// 正文可以不给：一行标题就是一条完整的备忘。
    @discardableResult
    public func create(title rawTitle: String, content rawContent: String = "") async throws -> Item {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        // 界面上「新建」按钮在标题为空时是灰的，这里是第二道闸 ——
        // 菜单 ⌘N、脚本、以后的深链接都可能绕过那个按钮。
        guard !title.isEmpty else { throw AppError.invalidInput("标题不能为空。") }

        // 正文只切**两头**的空白。中间的空行是用户自己排的段落，
        // 顺手规整掉的话，一条分了三段写的备忘会被压成一坨。
        let content = rawContent.trimmingCharacters(in: .whitespacesAndNewlines)

        let item = Item(title: title, content: content, createdAt: now())
        try await repository.insert(item)
        try await reload()
        return item
    }

    /// 删除若干条。`ids` 为空是合法的空操作（用户没选中任何行就按了 ⌫）。
    public func delete(ids: Set<Item.ID>) async throws {
        guard !ids.isEmpty else { return }
        for id in ids {
            try await repository.delete(id: id)
        }
        try await reload()
    }

    /// 写完之后重新问仓库要一遍，而不是在本地数组上增删。
    /// 仓库才是真相 —— 它可能改写了排序、补了默认值、或者根本没存进去。
    private func reload() async throws {
        items = try await repository.fetchAll()
        error = nil
    }
}
