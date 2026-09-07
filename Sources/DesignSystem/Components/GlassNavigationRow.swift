import SwiftUI

/// 菜单项保持固定位置，选中只更新绘制，不让两层材质交叉淡化。
public struct GlassNavigationRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let isFocused: Bool
    @State private var isHovered = false

    public init(title: String, systemImage: String, isSelected: Bool, isFocused: Bool = false) {
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.isFocused = isFocused
    }

    public var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .regular))
                .frame(width: 22)
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .medium : .regular))
            Spacer(minLength: 0)
        }
        .foregroundStyle(isSelected ? Theme.Ink.primary : Theme.Ink.secondary)
        .padding(.horizontal, Theme.Spacing.lg)
        .frame(maxWidth: .infinity, minHeight: Theme.Size.minimumHitTarget)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .fill(Theme.Brand.info.opacity(0.06))
                    .referenceGlassPanel(accent: Theme.Brand.info, radius: Theme.Radius.control,
                                         isHovered: isHovered)
            }
            if isHovered && !isSelected {
                RoundedRectangle(cornerRadius: Theme.Radius.control).fill(Theme.Fill.hover)
            }
        }
        .overlay(alignment: .leading) {
            if isSelected {
                Capsule().fill(Theme.Brand.accent)
                    .frame(width: 2)
                    .padding(.vertical, 7)
                    .shadow(color: Theme.Brand.info.opacity(0.75), radius: 4)
            }
        }
        .overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .strokeBorder(Theme.Brand.focusRing, lineWidth: 1.5)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .transaction { $0.animation = nil }
    }
}
