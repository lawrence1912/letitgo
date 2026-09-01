import AppCore
import SwiftUI

/// 一张「点进去」的卡片：图标 + 标题 + 一句说明 + 角落里的提示。
///
/// 整张卡是一个按钮 —— 只有图标或只有标题可点的话用户得瞄准，
/// 而卡片本来就是个大靶子。用 `Button` 而不是 `.onTapGesture`：
/// Tab 能到、⏎ / 空格能按、辅助功能角色是「按钮」，这些都是白送的。
///
/// 说明**两行封顶且预留高度**：网格里的卡片高度得一致，
/// 一行的和三行的排在一起会长得参差不齐。这里不能用
/// `.fixedSize(horizontal: false, vertical: true)` —— 见 DESIGN.md 的坑 1。
public struct NavigationCard: View {
    private let systemImage: String
    private let tint: IconTint
    private let title: String
    private let subtitle: String
    private let hint: String?
    private let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    /// - Parameter hint: 角落里的小字，比如键盘快捷键。它是**视觉提示**，
    ///   对辅助技术隐藏 —— 快捷键的正式出处是菜单，念两遍是噪音。
    public init(
        systemImage: String,
        tint: IconTint = .neutral,
        title: String,
        subtitle: String,
        hint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.tint = tint
        self.title = title
        self.subtitle = subtitle
        self.hint = hint
        self.action = action
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    IconTile(systemImage, tint: tint, size: 30)
                    Spacer(minLength: 0)
                    if let hint {
                        Text(hint)
                            .font(Theme.Typo.mono)
                            .foregroundStyle(Theme.Ink.tertiary)
                            .accessibilityHidden(true)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(Theme.Typo.headline)
                        .foregroundStyle(Theme.Ink.primary)

                    Text(subtitle)
                        .font(Theme.Typo.caption)
                        .foregroundStyle(Theme.Ink.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2, reservesSpace: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            // 悬停时描边提一档 + 浮起来一点。颜色一点没变 ——
            // 强调色的名额留给主操作，不给「鼠标正好路过这儿」。
            .panel(rim: isHovering ? Theme.Glass.rimStrong : nil, elevated: isHovering)
            .contentShape(shape)
            .contentShape(.focusEffect, shape)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(Theme.Motion.fast(reduceMotion: reduceMotion), value: isHovering)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}
