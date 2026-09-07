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
        // 设置窗口是独立 Scene，环境不跟主窗口共享 —— accent 要再递一次，
        // 否则这里的开关和分段控件会退回系统蓝（见 `RootView` 那条注释）。
        .tint(Theme.Brand.accentFill)
        // 宽度不再被主题选择器顶着走：它从「六套摆一行的分段控件」换成了
        // 会自己换行的卡片网格（见 `ThemePicker`），加主题不再需要加宽窗口。
        .frame(width: 560, height: 360)
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
                    .accessibilityLabel("启动时回到上次的分区")
            }

            Hairline()

            // 主题这行控件另起一行：六套主题的分段控件有 460 宽，
            // 和说明文字挤在同一行的话，被压掉的一定是左边那段说明
            // （`ThemePicker` 自己 `fixedSize` 了，它不让步）。
            SettingsRow(
                title: "主题",
                detail: "换整套色板。和「外观」正交 —— 浅色 / 深色的选择不受影响。",
                stacked: true
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
        .glassPanel()
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ambientBackdrop()
    }
}

/// 设置里的一行：左边说明，右边控件。所有分页共用，行高一致。
///
/// `stacked` 是给**放不下的控件**用的：控件挪到说明底下另起一行，
/// 左对齐。判断标准很简单 —— 控件本身超过半行宽就摞起来，
/// 挤在一行里的结果只会是说明文字被截断。
private struct SettingsRow<Control: View>: View {
    let title: String
    let detail: String?
    var stacked: Bool = false
    @ViewBuilder let control: Control

    var body: some View {
        Group {
            if stacked {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    caption
                    control
                }
            } else {
                HStack(alignment: .center, spacing: Theme.Spacing.md) {
                    caption
                    control
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
    }

    private var caption: some View {
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
    }
}

private struct AdvancedSettingsView: View {
    var body: some View {
        EmptyStateView(
            systemImage: "slider.horizontal.3",
            title: "暂无高级选项",
            message: "需要时在这里加。"
        )
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
