import SwiftUI

/// 应用自己的按钮语汇。
///
/// ## 为什么自绘按钮，但不自绘别的控件
///
/// 按钮是 SwiftUI 里唯一一个**能在不丢任何东西的前提下换皮**的控件：
/// `ButtonStyle` 只接管绘制，点击、键盘 ⏎ / 空格、Tab 焦点、辅助功能角色、
/// `.disabled()` 传播、`.keyboardShortcut` 全部照旧。所以这里换掉了。
///
/// 输入框、下拉、复选框、滚动条**没有**这个待遇 —— 自绘要连交互一起重做，
/// 大概率漏掉键盘或 VoiceOver。那些一律继续用系统的。
///
/// ## 四态都在
///
/// 默认 / 悬停 / 按下 / 禁用，一个不缺。焦点环用 `.contentShape(.focusEffect,)`
/// 交给系统画，这样它会跟着圆角走，而不是套一个直角框。
public struct ActionButtonStyle: ButtonStyle {

    public enum Kind: Sendable {
        /// 主操作。实心强调色，一屏最多一个。
        case primary
        /// 次要操作。有边框的表面色。
        case secondary
        /// 弱操作。透明，悬停才出底色。
        case ghost
        /// 破坏性操作。
        case destructive
    }

    public enum Size: Sendable {
        case compact
        case regular
        case large

        var height: CGFloat {
            switch self {
            case .compact: 22
            case .regular: 28
            case .large: 34
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .compact: 9
            case .regular: 12
            case .large: 18
            }
        }

        var font: Font {
            switch self {
            case .compact: Theme.Typo.caption.weight(.medium)
            case .regular: Theme.Typo.label
            case .large: Font.system(size: 13, weight: .semibold)
            }
        }
    }

    private let kind: Kind
    private let size: Size

    public init(_ kind: Kind, size: Size = .regular) {
        self.kind = kind
        self.size = size
    }

    public func makeBody(configuration: Configuration) -> some View {
        StyleBody(kind: kind, size: size, configuration: configuration)
    }

    /// `ButtonStyle.makeBody` 不是 View，拿不到 `@State` / `@Environment`，
    /// 所以悬停和禁用态得放进这个内层视图里读。
    private struct StyleBody: View {
        let kind: Kind
        let size: Size
        let configuration: Configuration

        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var isHovering = false

        private var shape: RoundedRectangle {
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
        }

        var body: some View {
            configuration.label
                .font(size.font)
                .foregroundStyle(foreground)
                .padding(.horizontal, size.horizontalPadding)
                .frame(height: size.height)
                .background(
                    shape
                        .fill(background)
                        // 悬停 / 按下靠明度偏移，不靠降透明度：实心强调色
                        // 一降透明度就被底下的表面色冲淡，看着像禁用了。
                        // 玻璃档的几种本来就是半透明的，明度偏移对它们不生效，
                        // 它们靠换薄膜（panel → hover）表达状态。
                        .brightness(brightnessShift)
                )
                // 描边 + 左上高光一起画。透明档（ghost）平时两样都不画 ——
                // 一个没底色的按钮顶着一圈亮边，看着像画错了。
                .glassRim(shape, rim: border, highlight: highlight)
                // 按下时缩一点。位移是动效，减弱动态时只留颜色变化。
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
                .contentShape(shape)
                // 让系统的键盘焦点环跟着圆角走，而不是套一个直角框。
                .contentShape(.focusEffect, shape)
                .onHover { isHovering = $0 }
                .animation(Theme.Motion.fast(reduceMotion: reduceMotion), value: isHovering)
                .animation(Theme.Motion.fast(reduceMotion: reduceMotion), value: configuration.isPressed)
        }

        /// 禁用态统一降到 35% 不透明 —— 比给每种按钮单独配一套灰色可靠：
        /// 无论底下是什么表面，禁用的东西都明显退后一层，但仍然读得出来。
        private var dimmed: Double { isEnabled ? 1 : 0.35 }

        private var foreground: Color {
            let base: Color = switch kind {
            case .primary: Theme.Brand.onAccent
            case .secondary: Theme.Ink.primary
            case .ghost: Theme.Ink.secondary
            case .destructive: Theme.Brand.danger
            }
            return base.opacity(dimmed)
        }

        /// 玻璃的厚度。实心按钮只给一点点 —— 它不透光，高光太亮会像塑料。
        private var highlight: Double {
            guard isEnabled else { return 0 }
            switch kind {
            case .primary: return 0.35
            case .ghost: return isHovering || configuration.isPressed ? 0.7 : 0
            case .secondary, .destructive: return 0.9
            }
        }

        /// 只对实心按钮生效；描边 / 透明的那几种靠换底色表达状态。
        private var brightnessShift: Double {
            guard kind == .primary, isEnabled else { return 0 }
            return configuration.isPressed ? -0.09 : isHovering ? -0.045 : 0
        }

        private var background: Color {
            switch kind {
            case .primary:
                Theme.Brand.accentFill.opacity(dimmed)
            case .secondary:
                (configuration.isPressed || isHovering ? Theme.Glass.hover : Theme.Glass.panel)
                    .opacity(dimmed)
            case .ghost:
                configuration.isPressed || isHovering
                    ? Theme.Glass.hover.opacity(dimmed)
                    : .clear
            case .destructive:
                (configuration.isPressed || isHovering ? Theme.Brand.dangerSoft : Theme.Glass.panel)
                    .opacity(dimmed)
            }
        }

        private var border: Color {
            switch kind {
            case .primary: .clear
            case .secondary: Theme.Glass.rim.opacity(dimmed)
            case .ghost: .clear
            case .destructive:
                (isHovering ? Theme.Brand.dangerSoftBorder : Theme.Glass.rim).opacity(dimmed)
            }
        }
    }
}

/// 纯图标按钮：正方形，悬停出底色。工具条、行内操作用它。
///
/// 图标按钮**必须**带 `.help()` 或 `.accessibilityLabel()` ——
/// 否则 VoiceOver 里它是一个无名的「按钮」。
public struct IconButtonStyle: ButtonStyle {

    private let size: CGFloat
    private let tone: Tone

    public init(size: CGFloat = 26, tone: Tone = .neutral) {
        self.size = size
        self.tone = tone
    }

    public func makeBody(configuration: Configuration) -> some View {
        StyleBody(size: size, tone: tone, configuration: configuration)
    }

    private struct StyleBody: View {
        let size: CGFloat
        let tone: Tone
        let configuration: Configuration

        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var isHovering = false

        private var shape: RoundedRectangle {
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
        }

        var body: some View {
            configuration.label
                .font(.system(size: size * 0.46, weight: .medium))
                .foregroundStyle(tone.tint.opacity(isEnabled ? 1 : 0.35))
                .frame(width: size, height: size)
                .background(
                    shape.fill(
                        configuration.isPressed || isHovering
                            ? (tone == .neutral ? Theme.Glass.hover : tone.soft)
                            : .clear
                    )
                )
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
                .contentShape(shape)
                .contentShape(.focusEffect, shape)
                .onHover { isHovering = $0 && isEnabled }
                .animation(Theme.Motion.fast(reduceMotion: reduceMotion), value: isHovering)
                .animation(Theme.Motion.fast(reduceMotion: reduceMotion), value: configuration.isPressed)
        }
    }
}

// MARK: - 简写

extension ButtonStyle where Self == ActionButtonStyle {
    /// 主操作。一屏最多一个。
    public static var primaryAction: ActionButtonStyle { ActionButtonStyle(.primary) }
    public static func primaryAction(size: ActionButtonStyle.Size) -> ActionButtonStyle {
        ActionButtonStyle(.primary, size: size)
    }

    /// 次要操作。
    public static var secondaryAction: ActionButtonStyle { ActionButtonStyle(.secondary) }
    public static func secondaryAction(size: ActionButtonStyle.Size) -> ActionButtonStyle {
        ActionButtonStyle(.secondary, size: size)
    }

    /// 弱操作。
    public static var ghostAction: ActionButtonStyle { ActionButtonStyle(.ghost) }
    public static func ghostAction(size: ActionButtonStyle.Size) -> ActionButtonStyle {
        ActionButtonStyle(.ghost, size: size)
    }

    /// 破坏性操作。
    public static var destructiveAction: ActionButtonStyle { ActionButtonStyle(.destructive) }
}

extension ButtonStyle where Self == IconButtonStyle {
    public static var icon: IconButtonStyle { IconButtonStyle() }
    public static func icon(size: CGFloat, tone: Tone = .neutral) -> IconButtonStyle {
        IconButtonStyle(size: size, tone: tone)
    }
}
