import AppCore
import SwiftUI

/// 外观切换控件。侧边栏底栏和设置窗口用的是**同一个**组件 ——
/// 同一功能在两处长得不一样，必有一处是错的。
///
/// 分段控件是自绘的：系统的 `.segmented` Picker 是整套界面里最像
/// 「原生控件贴图」的一块，换掉它对观感的收益最大。代价是四件事要自己补，
/// 都补了：
///
///   - **键盘**：三个都是真 `Button`，Tab 能到、⏎ / 空格能按。
///   - **VoiceOver**：每个报 `.isSelected`，整体是一个容器 ——
///     念出来是「浅色，已选中，按钮」，和单选组的体验一致。
///   - **悬停**：未选中项悬停出底色。
///   - **减弱动态**：滑块位移走 `matchedGeometryEffect`，
///     减弱动态时动画为 nil，直接跳过去。
///
/// 状态存在 UserDefaults，`@AppStorage` 保证多处实例自动同步 ——
/// 在设置里改，侧边栏的分段会跟着动，反之亦然。
public struct AppearancePicker: View {
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .system
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var pill

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Appearance.allCases) { option in
                Segment(
                    option: option,
                    isSelected: appearance == option,
                    namespace: pill
                ) {
                    appearance = option
                }
            }
        }
        .padding(2)
        .panel(.well, radius: Theme.Radius.pill)
        .animation(Theme.Motion.spring(reduceMotion: reduceMotion), value: appearance)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("外观")
        .help("外观：跟随系统 / 浅色 / 深色")
    }

    private struct Segment: View {
        let option: Appearance
        let isSelected: Bool
        let namespace: Namespace.ID
        let action: () -> Void

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var isHovering = false

        var body: some View {
            Button(action: action) {
                Image(systemName: option.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.Brand.onAccent : Theme.Ink.secondary)
                    .frame(width: 26, height: 20)
                    .background {
                        if isSelected {
                            // 一个滑块在三个位置之间移动，而不是三个各自淡入淡出 ——
                            // 前者看得出「同一个东西挪过去了」。
                            Capsule(style: .continuous)
                                .fill(Theme.Brand.accentFill)
                                .matchedGeometryEffect(id: "selection", in: namespace)
                        } else if isHovering {
                            Capsule(style: .continuous).fill(Theme.Glass.hover)
                        }
                    }
                    .contentShape(Capsule(style: .continuous))
                    .contentShape(.focusEffect, Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
            .animation(Theme.Motion.fast(reduceMotion: reduceMotion), value: isHovering)
            // 纯图标按钮必须显式给名字，否则 VoiceOver 里它没有名称。
            .accessibilityLabel(option.title)
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            .help(option.title)
        }
    }
}

// Preview 需要 Xcode 的 PreviewsMacros 插件，纯 Command Line Tools 编不过。
// ENABLE_PREVIEWS 只由 Xcode 工程（project.yml）定义，`swift build` 下自动跳过。
#if ENABLE_PREVIEWS
#Preview {
    AppearancePicker().padding(Theme.Spacing.xl)
}
#endif
