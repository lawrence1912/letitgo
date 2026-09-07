import AppCore
import SwiftUI

/// 一张「点进去」的卡片：图标 + 标题 + 角落里的快捷键。
///
/// 整张卡是一个按钮 —— 只有图标或只有标题可点的话用户得瞄准，
/// 而卡片本来就是个大靶子。用 `Button` 而不是 `.onTapGesture`：
/// Tab 能到、⏎ / 空格能按、辅助功能角色是「按钮」，这些都是白送的。
///
/// 卡面上**不写说明**：图标 + 名字已经够认出来是哪个分区了，一行说明
/// 只会把网格撑高、把入口推到折叠线以下。那句说明仍然递进来，
/// 但只念给 VoiceOver —— 屏幕上靠图标色和分组分出来的那条线索，读屏用户没有。
public struct NavigationCard: View {
    private let systemImage: String
    private let tint: IconTint
    private let title: String
    private let shortcut: String?
    private let spokenHint: String
    private let action: () -> Void

    /// - Parameters:
    ///   - shortcut: 角落里的小字，比如键盘快捷键。它是**视觉提示**，
    ///     对辅助技术隐藏 —— 快捷键的正式出处是菜单，念两遍是噪音。
    ///   - spokenHint: 只给 VoiceOver 的一句说明，卡面上不画。
    public init(
        systemImage: String,
        tint: IconTint = .neutral,
        title: String,
        shortcut: String? = nil,
        spokenHint: String,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.tint = tint
        self.title = title
        self.shortcut = shortcut
        self.spokenHint = spokenHint
        self.action = action
    }

    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                IconTile(systemImage, tint: tint, size: 30)
                Text(title)
                    .font(Theme.Typo.headline)
                    .foregroundStyle(Theme.Ink.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let shortcut {
                    Text(shortcut)
                        .font(Theme.Typo.mono)
                        .foregroundStyle(Theme.Ink.tertiary)
                        .padding(.horizontal, Theme.Spacing.xs)
                        .padding(.vertical, Theme.Spacing.xxs)
                        .background(Theme.Surface.well, in: Capsule())
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
            .referenceGlassPanel(
                accent: Theme.Brand.accent,
                radius: Theme.Radius.md,
                isHovered: isHovering,
                isFocused: isFocused,
                textured: true,
                textureKey: systemImage
            )
            .contentShape(shape)
        }
        .buttonStyle(CardButtonStyle())
        .focused($isFocused)
        .onHover { isHovering = $0 }
        .accessibilityLabel(title)
        .accessibilityHint(spokenHint)
    }
}
