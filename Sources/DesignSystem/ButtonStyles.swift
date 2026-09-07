import SwiftUI

/// 固定蓝色与明暗表面，立体感来自顶面、下沿和投影；状态变化不淡入淡出。
/// ButtonStyle 保留原生点击、键盘焦点和辅助功能语义。
public struct ActionButtonStyle: ButtonStyle {

    public enum Kind: Sendable {
        case primary
        case secondary
        case ghost
        case destructive
    }

    /// 三档尺寸。**高度和左右留白一起放大，字只跟半档** ——
    /// 按钮的体面来自留白，不是字号。只放大字号得到的是「一个字很大的小按钮」。
    ///
    /// 三档都是胶囊，而这不只是风格：顶面那道亮带是按「顶面是弯的」画的，
    /// 它比本体窄一圈、缩进量跟着高度走。这在方角上会露馅 ——
    /// 一条比本体窄的亮带浮在方块顶上，读成的是「贴了张纸」。
    /// **胶囊是这层材质成立的前提。**
    public enum Size: Sendable {
        case compact
        case regular
        case large

        var height: CGFloat {
            switch self {
            case .compact: 26
            case .regular: 34
            case .large: 42
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .compact: 14
            case .regular: 20
            case .large: 26
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .compact: 12
            case .regular: 13
            case .large: 14
            }
        }

        var font: Font {
            switch self {
            case .compact: Theme.Typo.label
            case .regular: Font.system(size: fontSize, weight: .medium)
            case .large: Font.system(size: fontSize, weight: .semibold)
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

    /// `ButtonStyle.makeBody` 不是 View，拿不到 `@Environment`，
    /// 所以禁用态放进这个内层视图里读。
    private struct StyleBody: View {
        let kind: Kind
        let size: Size
        let configuration: Configuration

        @State private var isHovering = false
        @Environment(\.isEnabled) private var isEnabled
        private var shape: Capsule { Capsule(style: .continuous) }

        var body: some View {
            configuration.label
                .font(size.font)
                .foregroundStyle(foreground)
                .padding(.horizontal, size.horizontalPadding)
                .frame(height: size.height)
                .raisedControl(in: shape, emphasized: kind == .primary, pressed: configuration.isPressed, hovered: isHovering && isEnabled)
                .opacity(isEnabled ? 1 : 0.35)
                .contentShape(.focusEffect, shape)
                .frame(minWidth: Theme.Size.minimumHitTarget, minHeight: Theme.Size.minimumHitTarget)
                .contentShape(Rectangle())
                .onHover { isHovering = $0 }
        }

        private var foreground: Color {
            switch kind {
            case .primary: ControlLighting.foreground(emphasized: true)
            case .secondary: Theme.Ink.primary
            case .ghost: Theme.Ink.secondary
            case .destructive: Theme.Brand.danger
            }
        }
    }
}

/// 纯图标按钮：一颗**圆**的玻璃。工具条、行内操作用它。
///
/// 正方形的东西配胶囊圆角就是个圆 —— 图标按钮和文字按钮是同一族，
/// 文字按钮成了胶囊，它就该是圆的。
///
/// 图标按钮**必须**带 `.help()` 或 `.accessibilityLabel()` ——
/// 否则 VoiceOver 里它是一个无名的「按钮」。
public struct IconButtonStyle: ButtonStyle {

    private let size: CGFloat
    private let tone: Tone

    public init(size: CGFloat = 30, tone: Tone = .neutral) {
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

        @State private var isHovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: size * 0.44, weight: .medium))
                .foregroundStyle(tone.tint)
                .frame(width: size, height: size)
                .raisedControl(in: Circle(), pressed: configuration.isPressed, hovered: isHovering && isEnabled)
                .opacity(isEnabled ? 1 : 0.35)
                .contentShape(.focusEffect, Circle())
                .frame(minWidth: Theme.Size.minimumHitTarget, minHeight: Theme.Size.minimumHitTarget)
                .contentShape(Rectangle())
                .onHover { isHovering = $0 }
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
    public static func icon(size: CGFloat = 30, tone: Tone = .neutral) -> IconButtonStyle {
        IconButtonStyle(size: size, tone: tone)
    }
}

/// 卡片按下时直接下沉，不改变透明度。
public struct CardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed && !reduceMotion ? 2 : 0)
            .transaction { $0.animation = nil }
    }
}
