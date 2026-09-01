import AppCore
import AppKit
import SwiftUI

/// 主题切换控件。和 `AppearancePicker` 是同一套语汇（真 `Button`、`.isSelected`、
/// 悬停态、滑块走 `matchedGeometryEffect`），只有一处刻意不同：
///
/// **选中态用 `accentSoft`（浅色调块）而不是 `accentFill`（实心强调色）。**
/// 两个理由：一是每个选项里带着色卡，压在实心强调色上会糊；
/// 二是「选了哪套主题」是**当前选中**，不是**主操作** —— 和侧边栏的分区选中同级，
/// 就该长得一样。一屏最多一个响亮的按钮，那个名额不给设置里的选择器。
public struct ThemePicker: View {
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .morandi
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var pill

    public init() {}

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(AppTheme.allCases) { option in
                Segment(option: option, isSelected: theme == option, namespace: pill) {
                    theme = option
                }
            }
        }
        .padding(2)
        .panel(.well, radius: Theme.Radius.pill)
        // 不许被压。设置那一行左边是「说明文字 + 弹性宽度」，SwiftUI 会先压这个
        // 控件 —— 第三套主题加进来之后，压出来的结果是「莫…」。
        // 一个标签被截断的分段控件是坏的；该换行的是左边那段说明，不是这里。
        .fixedSize(horizontal: true, vertical: false)
        .animation(Theme.Motion.spring(reduceMotion: reduceMotion), value: theme)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("主题")
    }

    private struct Segment: View {
        let option: AppTheme
        let isSelected: Bool
        let namespace: Namespace.ID
        let action: () -> Void

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var isHovering = false

        private var shape: Capsule { Capsule(style: .continuous) }

        var body: some View {
            Button(action: action) {
                HStack(spacing: Theme.Spacing.xs) {
                    ThemeSwatch(option)
                    Text(option.title)
                        .font(Theme.Typo.caption.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Theme.Ink.primary : Theme.Ink.secondary)
                }
                .padding(.horizontal, Theme.Spacing.sm)
                .frame(height: 22)
                .background {
                    if isSelected {
                        shape
                            .fill(Theme.Brand.accentSoft)
                            .overlay(shape.strokeBorder(Theme.Brand.accentSoftBorder, lineWidth: 1))
                            .matchedGeometryEffect(id: "selection", in: namespace)
                    } else if isHovering {
                        shape.fill(Theme.Glass.hover)
                    }
                }
                .contentShape(shape)
                .contentShape(.focusEffect, shape)
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
            .animation(Theme.Motion.fast(reduceMotion: reduceMotion), value: isHovering)
            .accessibilityLabel(option.title)
            .accessibilityHint(option.subtitle)
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            .help(option.subtitle)
        }
    }
}

/// 一套主题的三点色卡：氛围底 / 主操作 / 信息态。
///
/// 它必须能画**别的**主题的颜色 —— 用户是靠这三个点决定要不要换过去的，
/// 全都按当前主题解析的话，两个选项会长得一模一样。所以这里绕开
/// `Theme.*`（那些查的是「当前」色板），直接问某一套色板要色值。
///
/// 仍然跟着**外观**走：`nsColor(for:)` 在绘制时拿到当前外观，
/// 所以深色模式下的色卡是那套主题的深色版，不是浅色版缩略图。
struct ThemeSwatch: View {
    private let theme: AppTheme

    init(_ theme: AppTheme) {
        self.theme = theme
    }

    private static let tokens: [ColorToken] = [.backdrop, .accentFill, .info]

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(Self.tokens, id: \.self) { token in
                Circle()
                    .fill(color(token))
                    .frame(width: 7, height: 7)
                    .overlay(Circle().strokeBorder(Theme.Glass.rim, lineWidth: 0.5))
            }
        }
        // 三个点是同一件事的三个样本，VoiceOver 念「莫兰迪」就够了，
        // 色卡本身不承担信息。
        .accessibilityHidden(true)
    }

    private func color(_ token: ColorToken) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            Palette.of(theme).ramp(for: token).nsColor(for: appearance)
        })
    }
}
