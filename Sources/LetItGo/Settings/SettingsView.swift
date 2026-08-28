import AppCore
import DesignSystem
import SwiftUI

/// ⌘, 打开的设置窗口。macOS 惯例是用 TabView 分页。
/// 偏好项用 `@AppStorage` 存 UserDefaults —— 下面那个开关是接线示范，
/// 它真的会持久化，只是还没有任何地方读它。
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("通用", systemImage: "gearshape") }

            AdvancedSettingsView()
                .tabItem { Label("高级", systemImage: "slider.horizontal.3") }
        }
        .frame(width: 460, height: 260)
    }
}

private struct GeneralSettingsView: View {
    @AppStorage("restoreLastSection") private var restoreLastSection = true

    var body: some View {
        Form {
            Toggle("启动时回到上次的分区", isOn: $restoreLastSection)
            LabeledContent("外观") {
                // 和侧边栏底栏是同一个组件、同一份 UserDefaults 状态：
                // 在任一处改动，另一处立刻跟着变。
                AppearancePicker()
            }
        }
        .formStyle(.grouped)
        .padding(Theme.Spacing.lg)
    }
}

private struct AdvancedSettingsView: View {
    var body: some View {
        EmptyStateView(
            systemImage: "slider.horizontal.3",
            title: "暂无高级选项",
            message: "需要时在这里加。"
        )
    }
}

// Preview 需要 Xcode 的 PreviewsMacros 插件，纯 Command Line Tools 编不过。
// ENABLE_PREVIEWS 只由 Xcode 工程（project.yml）定义，`swift build` 下自动跳过。
#if ENABLE_PREVIEWS
#Preview {
    SettingsView()
}
#endif
