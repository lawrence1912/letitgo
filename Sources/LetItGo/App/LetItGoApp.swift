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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(\.dependencies, dependencies)
                .frame(
                    minWidth: Theme.Size.sidebarMinWidth + Theme.Size.detailMinWidth,
                    minHeight: Theme.Size.windowMinHeight
                )
                // initial: true —— 启动时立刻应用上次的选择，不等用户去动它
                .onChange(of: appearance, initial: true) { _, newValue in
                    AppearanceController.apply(newValue)
                }
        }
        .defaultSize(width: 980, height: 640)
        .commands { AppCommands(appState: appState) }

        // ⌘, 打开的设置窗口
        Settings {
            SettingsView()
                .environment(\.dependencies, dependencies)
        }
    }
}
