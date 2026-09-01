import SwiftUI

/// 「当前界面能做的一件事」——由界面自己登记，由**界面之外**的入口触发。
///
/// 为什么需要这层间接：`新建备忘` 在三个地方能触发（侧边栏底部的 `+`、
/// 工具栏的 `+`、菜单 ⌘N），但这三个入口都不在 `HomeView` 里，拿不到它的
/// Model 和 sheet 状态。往 `AppState` 里塞一个「请求新建」的计数器能凑效，
/// 但那是把一次性事件伪装成状态，还得手动清零。
///
/// macOS 的正解是 focused value：界面用 `.focusedSceneValue` 登记自己能做什么，
/// 菜单和工具栏用 `@FocusedValue` 读。白送的好处是**没人登记时值为 nil**，
/// 于是入口自动变灰 —— 不需要任何 if 判断分区、判断有没有选中。
@MainActor
public struct SceneAction: Equatable {
    /// 菜单项要显示的文案。不同界面的「主操作」叫法不一样
    /// （备忘分区是「新建备忘」，别的分区可以是「添加文件」之类），
    /// 由登记方给出，菜单照着显示 —— 壳里不需要知道有哪些分区。
    public let title: String

    private let handler: () -> Void

    public init(_ title: String, _ handler: @escaping () -> Void) {
        self.title = title
        self.handler = handler
    }

    /// 让调用方能直接写 `action()`。
    public func callAsFunction() {
        handler()
    }

    /// **必须 `Equatable`，而且必须按 title 比较，不能按闭包比较。**
    ///
    /// 视图的 body 每求值一次就会造一个新闭包。如果 SwiftUI 没法判断
    /// 「这还是同一个动作」，它会认为焦点值每帧都在变，于是
    /// `invalidateProperties` → `NSHostingView.setNeedsUpdate()` →
    /// 约束更新 → 重新求值 body → 又一个新闭包，无限循环。AppKit 撑不住会抛：
    ///
    ///     The window has been marked as needing another Update Constraints in
    ///     Window pass, but it has already had more Update Constraints in Window
    ///     passes than there are views in the window.
    ///
    /// 循环开始前 SwiftUI 会先在控制台留一句
    /// `[Invalid Configuration] FocusedValue update tried to update multiple
    /// times per frame.` —— 看到那句就是这里出了问题。
    ///
    /// 按 title 比较是安全的：闭包捕获的是视图值，而视图里的状态都在
    /// `@State` 盒子里，所以「旧」闭包读到的仍然是当前状态，不会读到快照。
    /// 反过来说，**不要在 handler 里捕获局部快照**，要读 `@State` / model。
    nonisolated public static func == (lhs: SceneAction, rhs: SceneAction) -> Bool {
        lhs.title == rhs.title
    }
}

private struct NewItemActionKey: FocusedValueKey {
    typealias Value = SceneAction
}

private struct DeleteSelectionActionKey: FocusedValueKey {
    typealias Value = SceneAction
}

extension FocusedValues {
    /// 「新建」。登记方：当前详情界面。读取方：侧边栏 `+`、工具栏 `+`、⌘N。
    ///
    /// 登记：`.focusedSceneValue(\.newItemAction, SceneAction { … })`
    /// 读取：`@FocusedValue(\.newItemAction) private var newItemAction`
    public var newItemAction: SceneAction? {
        get { self[NewItemActionKey.self] }
        set { self[NewItemActionKey.self] = newValue }
    }

    /// 「删除选中项」。读取方：编辑菜单的 ⌘⌫。
    ///
    /// 界面在**没有选中任何东西时登记 nil**，菜单项就自动变灰 ——
    /// 比在菜单里反查「现在选中了几条」干净得多。
    ///
    /// 为什么删除也要走菜单命令，而不是给列表加 `.onDeleteCommand`：
    /// 那个修饰符只在列表处于响应链里才触发，而 `NavigationSplitView` 的详情区
    /// 里的 `List` 拿不到键盘焦点（实测点了行也是 `focused=false`），
    /// 于是 ⌫ 静默无反应。菜单命令不依赖焦点，还顺带白送了菜单里的可发现性。
    public var deleteSelectionAction: SceneAction? {
        get { self[DeleteSelectionActionKey.self] }
        set { self[DeleteSelectionActionKey.self] = newValue }
    }
}
