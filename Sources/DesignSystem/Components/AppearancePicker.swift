import AppCore
import SwiftUI

/// 外观切换控件。侧边栏底栏和设置窗口用的是**同一个**组件 ——
/// 同一功能在两处长得不一样，必有一处是错的。
///
/// 用原生分段 `Picker` 而不是自绘控件：hover / 焦点环 / 键盘方向键 /
/// VoiceOver 单选组角色 / 系统「减弱动态效果」下的过渡降级，全部白送。
/// 自绘一个带滑块动画的版本看着更"精致"，但上面每一项都要重做，且大概率漏。
///
/// 状态存在 UserDefaults，`@AppStorage` 保证多处实例自动同步 ——
/// 在设置里改，侧边栏的分段会跟着动，反之亦然。
public struct AppearancePicker: View {
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .system

    public init() {}

    public var body: some View {
        Picker("外观", selection: $appearance) {
            ForEach(Appearance.allCases) { option in
                // .iconOnly 只藏视觉文字，辅助技术读到的仍是 title，
                // 所以图标按钮不会变成 VoiceOver 里的无名控件。
                Label(option.title, systemImage: option.systemImage)
                    .labelStyle(.iconOnly)
                    .tag(option)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .help("外观：跟随系统 / 浅色 / 深色")
    }
}

// Preview 需要 Xcode 的 PreviewsMacros 插件，纯 Command Line Tools 编不过。
// ENABLE_PREVIEWS 只由 Xcode 工程（project.yml）定义，`swift build` 下自动跳过。
#if ENABLE_PREVIEWS
#Preview {
    VStack(spacing: Theme.Spacing.lg) {
        AppearancePicker()
        AppearancePicker().controlSize(.small)
    }
    .padding(Theme.Spacing.xl)
}
#endif
