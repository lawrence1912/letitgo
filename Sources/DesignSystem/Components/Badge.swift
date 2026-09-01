import AppCore
import SwiftUI

/// 状态徽章：胶囊底 + 图标 + 文字。
///
/// **形状 + 文字 + 颜色三重编码**，任缺其一都还读得出来 ——
/// 色觉障碍、增强对比度、灰度截图下都要能用，所以图标和文字都不是可选的。
///
/// 用它代替「一句带颜色的文字」：状态是离散值，离散值配离散的容器，
/// 扫一列时眼睛找的是色块的位置，不是句子的开头。
public struct Badge: View {

    public enum Size: Sendable {
        case compact
        case regular

        var font: Font {
            switch self {
            case .compact: Theme.Typo.caption.weight(.medium)
            case .regular: Theme.Typo.label
            }
        }

        var height: CGFloat {
            switch self {
            case .compact: 18
            case .regular: 22
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .compact: 6
            case .regular: 9
            }
        }
    }

    private let tone: Tone
    private let systemImage: String?
    private let text: String
    private let size: Size

    public init(
        _ text: String,
        tone: Tone = .neutral,
        systemImage: String? = nil,
        size: Size = .regular
    ) {
        self.text = text
        self.tone = tone
        self.systemImage = systemImage
        self.size = size
    }

    public var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(size.font.weight(.semibold))
                    .accessibilityHidden(true)
            }
            Text(text)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(size.font)
        .foregroundStyle(tone.tint)
        .padding(.horizontal, size.horizontalPadding)
        .frame(height: size.height)
        .softFill(tone, radius: Theme.Radius.pill)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tone.spokenPrefix.map { "\($0)：\(text)" } ?? text)
    }
}

/// 图标底板：圆角方块 + 浅底 + 同色图标。
///
/// 空态、导航项、列表行的前导位用它，而不是裸放一个 SF Symbol ——
/// 裸图标在一列文字旁边没有重量，撑不起「这一块是什么」。
public struct IconTile: View {
    private let systemImage: String
    private let size: CGFloat
    private let foreground: Color
    private let fill: Color
    private let border: Color

    /// 语义色调。空态、提示、状态用它 —— 颜色说的是「这是成功 / 失败」。
    public init(_ systemImage: String, tone: Tone = .neutral, size: CGFloat = 28) {
        self.systemImage = systemImage
        self.size = size
        self.foreground = tone.tint
        self.fill = tone.soft
        self.border = tone.softBorder
    }

    /// 辨识色。分区入口、侧边栏用它 —— 颜色说的是「这是哪一个」。
    /// 两套刻意分开：一枚红色的图标底板不该让人以为那个分区出错了。
    public init(_ systemImage: String, tint: IconTint, size: CGFloat = 28) {
        self.systemImage = systemImage
        self.size = size
        self.foreground = tint.tint
        self.fill = tint.soft
        self.border = tint.softBorder
    }

    public var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.44, weight: .medium))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .softFill(fill: fill, border: border, radius: size * 0.3)
            .accessibilityHidden(true)
    }
}

/// 状态圆点。没有原生等价物，也不接受交互 —— 它永远和旁边的文字一起出现，
/// 不单独承担信息。
public struct StatusDot: View {
    private let tone: Tone
    private let isPulsing: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false

    public init(tone: Tone, isPulsing: Bool = false) {
        self.tone = tone
        self.isPulsing = isPulsing
    }

    public var body: some View {
        Circle()
            .fill(tone.tint)
            .frame(width: 7, height: 7)
            // 外圈光晕：深色外观下一个 7pt 的实心点很容易被背景吃掉。
            .overlay(Circle().stroke(tone.tint.opacity(0.25), lineWidth: 3))
            .opacity(dimmed ? 0.4 : 1)
            .animation(
                isPulsing && !reduceMotion
                    ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                    : nil,
                value: dimmed
            )
            .onAppear { if isPulsing && !reduceMotion { dimmed = true } }
            .accessibilityHidden(true)
    }
}
