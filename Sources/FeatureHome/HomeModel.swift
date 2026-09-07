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
///   - `create` / `toggle` / `delete` 把错误**抛出去**，由调用方决定怎么呈现
///     （壳里是全局 alert）。写操作是用户主动发起的，失败必须打断他，
///     否则他会以为成了。
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

    /// 左列：还没做的，最新的排最前 —— 输入框就在列首上方，
    /// 刚打完回车的那条必须出现在它正下方。
    public var pending: [Item] {
        items.filter { !$0.isDone }.reversed()
    }

    /// 右列：做完的，**按打勾的时间**倒序，最近勾掉的排最前。
    ///
    /// 没有 `completedAt` 的（升级前存的）回落到 `createdAt` —— 排得不那么准，
    /// 但不会因为一个 nil 就整列乱掉。
    public var completed: [Item] {
        items
            .filter(\.isDone)
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
    }

    /// 还没做完的件数。待办列表要回答的问题就是这一个，
    /// 所以它是 Model 的属性，不是界面里现算的。
    public var remaining: Int {
        items.filter { !$0.isDone }.count
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

    /// 加一条待办。返回真正落库的那条，方便调用方拿去写状态栏文案。
    @discardableResult
    public func create(text rawText: String) async throws -> Item {
        // 只切**两头**的空白。中间的换行是用户自己排的（粘进来的一段清单），
        // 顺手规整掉的话，一条分了三行写的待办会被压成一坨。
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        // 界面上空输入框按回车是空操作，这里是第二道闸 ——
        // 菜单 ⌘N、脚本、以后的深链接都可能绕过那个判断。
        guard !text.isEmpty else { throw AppError.invalidInput("待办不能为空。") }

        let item = Item(text: text, createdAt: now())
        try await repository.insert(item)
        try await reload()
        return item
    }

    /// 把一条**设成**完成 / 未完成。返回改完之后的那条。
    ///
    /// 拖放要的是这个而不是 `toggle`：一张卡拖到哪一列，它就该是哪一列的状态，
    /// 跟它原来是什么无关。拖回它本来就在的那一列是空操作 ——
    /// **不写盘、不重排**，否则手一抖把卡拿起来又放回去，`completedAt`
    /// 就被刷新了，那一列会当着用户的面重新排一遍。
    @discardableResult
    public func setDone(_ isDone: Bool, id: Item.ID) async throws -> Item {
        // 本地找不到就别去问仓库了：这条已经在别处被删掉，
        // 交给 `update` 的话也是同一个 notFound，但要多跑一趟磁盘。
        guard var item = items.first(where: { $0.id == id }) else {
            throw AppError.notFound
        }
        guard item.isDone != isDone else { return item }

        item.isDone = isDone
        // 取消打勾要把时间**清掉**：留着的话，这条再被勾上之前，
        // 「已完成」那一列的排序里就躺着一个属于上辈子的时间戳。
        item.completedAt = isDone ? now() : nil
        try await repository.update(item)
        try await reload()
        return item
    }

    /// 打勾 / 取消打勾。勾选框走这条 —— 它按的是「反过来」，不是「设成某个值」。
    @discardableResult
    public func toggle(id: Item.ID) async throws -> Item {
        guard let item = items.first(where: { $0.id == id }) else {
            throw AppError.notFound
        }
        return try await setDone(!item.isDone, id: id)
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
