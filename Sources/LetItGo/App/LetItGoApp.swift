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
    /// 更新可观察的色板，让现有视图重绘并保留编辑状态。
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .fallback

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(\.dependencies, dependencies)
                .onChange(of: theme, initial: true) { _, newValue in
                    Theme.apply(newValue)
                }
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
        // **标题栏回来了。** 上一版把它藏了（`.hiddenTitleBar`），
        // 让应用自己拥有整个窗口表面、自己画一条页头。
        //
        // 那是 macOS 26 之前的正确答案：那时的标题栏是一块不透明的灰条，
        // 藏掉它才能让界面连成一片。现在它是 Liquid Glass —— 内容从它底下穿过去，
        // 藏掉反而是把系统白给的东西（滚动边缘渐隐、工具栏自定义、
        // 全屏与窗口分屏的入口）一起扔了。
        // 关掉窗口的自动状态恢复。
        //
        // 换成原生 `List(selection:)` 之后冒出来的一个坑：AppKit 会把列表的
        // **选中行**存进 Saved Application State，下次启动再塞回绑定里 ——
        // 于是 `AppState.selection` 的初始值（概览）在启动后被悄悄改掉，
        // 而且改成什么是不确定的（存的是行号，分组一变就对不上）。
        // 实测同一份构建连开三次，落在三个不同的分区上。
        //
        // 「当前在哪个分区」这件事只能有一个出处，那就是 `AppState` ——
        // 菜单命令、⌘1–9、深链接改的都是它。所以这里把系统那条旁路关掉。
        // 真要做「记住上次的分区」的话，得由我们自己存（设置里那个
        // `restoreLastSection` 开关就是留给它的），而不是让 AppKit 从
        // 一个行号里猜。
        .restorationBehavior(.disabled)
        .commands { AppCommands(appState: appState) }

        // 设置可以独立于主窗口存在，也同步主题变化。
        Settings {
            SettingsView()
                .environment(\.dependencies, dependencies)
                .onChange(of: theme, initial: true) { _, newValue in
                    Theme.apply(newValue)
                }
        }
    }
}
