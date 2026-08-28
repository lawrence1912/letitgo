import Foundation
import Observation

/// 全局 UI 状态：只放「跨界面共享」的东西（当前选中项、状态栏文案…）。
/// 单个界面自己的状态属于那个界面的 Model，不要往这里堆。
///
/// 用 `@Observable` 而不是 `ObservableObject`：视图只会因为真正读到的
/// 属性变化而重绘，不再是整个对象一变全屏刷新。
@MainActor
@Observable
public final class AppState {
    /// 侧边栏当前选中项。`nil` 表示没有选中（详情区显示空态）。
    public var selection: SidebarItem? = .overview

    /// 底部状态栏文案。`nil` 时状态栏显示默认提示。
    public var statusMessage: String?

    /// 顶层错误。置为非 nil 会弹 alert，由 `RootView` 统一处理。
    public var presentedError: AppError?

    public init(selection: SidebarItem? = .overview) {
        self.selection = selection
    }
}
