import AppCore
import DesignSystem
import SwiftUI

/// 应用入口。这里只做三件事：建全局状态、装依赖、拼 Scene。
/// 任何业务逻辑都不该出现在这个文件里。
@main
struct LetItGoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var appState = AppState()
    private let dependencies = AppDependencies.live()

    /// 外观偏好存在 UserDefaults（控件在侧边栏底栏和设置窗口各有一个实例），
    /// 这里是唯一把它落到 NSApp 上的地方。
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .system

    /// 主题（哪一套色板）。和外观是两件正交的事，见 `AppCore/AppTheme.swift`。
    ///
    /// 这里读它只为了一件事：**换主题时给视图树换个身份**（下面的 `.id(theme)`）。
    /// 色值本身不用推 —— `Theme.*` 的每个色都是绘制时才去查当前主题的动态色。
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .morandi

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(\.dependencies, dependencies)
                // 换主题 = 重建视图树。
                //
                // 色值是活的（绘制时才查当前色板），但 SwiftUI 不知道该重绘 ——
                // 视图树里没有任何东西「变了」，它会心安理得地复用上一帧的绘制结果。
                // `.id()` 是唯一可靠的办法：换身份，整棵树重建，颜色重新解析。
                //
                // **代价**：树里的 `@State` 会重置 —— `HomeModel` 重新从磁盘读
                // （看不出来），随机串那页刚生成的十串会换一批（看得出来）。
                // `AppState`（当前分区、状态栏文字）活在这个 `.id` 外面，不受影响。
                // 换主题是设置里的一次性动作，这个代价换的是「不会有一半界面
                // 还是旧颜色」——那种 bug 更难查，也更难看。
                .id(theme)
                .frame(
                    minWidth: Theme.Size.sidebarMinWidth + Theme.Size.detailMinWidth,
                    minHeight: Theme.Size.windowMinHeight
                )
                // initial: true —— 启动时立刻应用上次的选择，不等用户去动它
                .onChange(of: appearance, initial: true) { _, newValue in
                    AppearanceController.apply(newValue)
                }
        }
        .defaultSize(width: 1020, height: 660)
        // 隐藏系统标题栏：红绿灯浮在侧边栏顶部，应用自己拥有整个窗口表面。
        // 标题栏本身还在（只是透明），所以窗口照样能从顶部拖动；
        // 分区标题挪到了详情区自己的 `PageHeader` 里 —— 那里还能放一行说明，
        // 系统标题栏放不下。
        .windowStyle(.hiddenTitleBar)
        .commands { AppCommands(appState: appState) }

        // ⌘, 打开的设置窗口。它是独立 Scene，所以 `.id(theme)` 要各挂一份 ——
        // 主题选择器就在这个窗口里，它自己必须先跟着变。
        Settings {
            SettingsView()
                .environment(\.dependencies, dependencies)
                .id(theme)
        }
    }
}
