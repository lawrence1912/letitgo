import AppCore
import DesignSystem
import SwiftUI

/// ⌘, 打开的设置窗口。
///
/// 分页用 `TabView` —— 设置窗口的顶部标签是 macOS 少数几个「换掉就是错」的
/// 惯例之一，用户按 ⌘, 就是来找它的。里面的内容换成了自己的行样式：
/// `Form(.grouped)` 那套圆角分组在这套色阶里是异物，而且行高控制不了。
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("通用", systemImage: "gearshape") }

            AdvancedSettingsView()
                .tabItem { Label("高级", systemImage: "slider.horizontal.3") }
        }
        .frame(width: 480, height: 280)
    }
}

private struct GeneralSettingsView: View {
    @AppStorage("restoreLastSection") private var restoreLastSection = true

    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(
                title: "启动时回到上次的分区",
                detail: "关掉的话每次都从「概览」开始。"
            ) {
                Toggle("", isOn: $restoreLastSection)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    // 开关继续用系统的（拖动手感、VoiceOver 角色都白送），
                    // 只把打开态的颜色换成品牌色 —— `.tint` 不改行为。
                    .tint(Theme.Brand.accentFill)
                    .accessibilityLabel("启动时回到上次的分区")
            }

            Hairline()

            SettingsRow(
                title: "主题",
                detail: "换整套色板。和「外观」正交 —— 浅色 / 深色的选择不受影响。"
            ) {
                ThemePicker()
            }

            Hairline()

            SettingsRow(
                title: "外观",
                detail: "和侧边栏底部是同一个控件、同一份状态。"
            ) {
                AppearancePicker()
            }
        }
        .panel()
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .glassBackground(.content)
        .ambientBackdrop()
    }
}

/// 设置里的一行：左边说明，右边控件。所有分页共用，行高一致。
private struct SettingsRow<Control: View>: View {
    let title: String
    let detail: String?
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Theme.Typo.body)
                    .foregroundStyle(Theme.Ink.primary)
                if let detail {
                    Text(detail)
                        .font(Theme.Typo.caption)
                        .foregroundStyle(Theme.Ink.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            control
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
    }
}

private struct AdvancedSettingsView: View {
    var body: some View {
        EmptyStateView(
            systemImage: "slider.horizontal.3",
            title: "暂无高级选项",
            message: "需要时在这里加。"
        )
        .glassBackground(.content)
        .ambientBackdrop()
    }
}

// Preview 需要 Xcode 的 PreviewsMacros 插件，纯 Command Line Tools 编不过。
// ENABLE_PREVIEWS 只由 Xcode 工程（project.yml）定义，`swift build` 下自动跳过。
#if ENABLE_PREVIEWS
#Preview {
    SettingsView()
}
#endif
