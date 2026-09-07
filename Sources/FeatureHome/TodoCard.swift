import AppCore
import DesignSystem
import SwiftUI

/// 紧凑待办卡：勾选、文本与时间、删除并排；长文本可自然增高。
/// 卡片选择、勾选、删除保持独立按钮，拖放另有勾选按钮作为替代操作。
struct TodoCard: View {
    let item: Item
    let isSelected: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void
    let onDelete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false
    @FocusState private var focusedControl: Control?

    private enum Control: Hashable {
        case selection, completion, deletion
    }

    /// 删除按钮的边长。这块位置**一直占着**，按钮只是在里面显隐 ——
    /// 不占的话，鼠标划过时左边的时间会被挤着往左跳一下。
    private static let trailingSlot = Theme.Size.minimumHitTarget

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
    }

    /// 卡上那行时间：没做完的显示写下的时间，做完的显示**打勾的时间**。
    /// 一张卡挪到「已完成」那一列之后，「什么时候写的」已经不重要了。
    private var stamp: Date {
        item.isDone ? (item.completedAt ?? item.createdAt) : item.createdAt
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            checkbox
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                text
                footer
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(Theme.Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        // 选择按钮铺满卡片，勾选和删除保持为独立按钮，避免嵌套交互控件。
        .background {
            Button(action: onSelect) {
                shape.fill(.clear)
                    .contentShape(shape)
            }
            .buttonStyle(.plain)
            .focused($focusedControl, equals: .selection)
            .accessibilityLabel("选择待办：\(item.text)")
            .accessibilityHint("按下选中，Command 点按可多选；选中后可用 Command 删除键删除。")
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        }
        .background { SelectionSurface(isSelected: isSelected, radius: Theme.Radius.md) }
        .referenceGlassPanel(
            accent: Theme.Brand.accent,
            radius: Theme.Radius.md,
            isHovered: isHovering,
            isFocused: focusedControl == .selection,
            textured: true,
            textureKey: item.id.uuidString
        )
        .onHover { isHovering = $0 }
    }

    // MARK: - 勾选框

    /// 这张卡真正的操作。18pt 的方框外面裹一圈 padding，靶子有 44pt ——
    /// 方框画多大是视觉的事，点得中点不中是另一回事。
    ///
    /// 完成态走**绿**而不是强调色：强调色在这个界面里已经是「选中 / 落点」的意思了，
    /// 一个勾掉的东西不该和「当前选中的那张」长得一样。
    private var checkbox: some View {
        Button(action: onToggle) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(item.isDone ? Theme.Brand.successSoft : .clear)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(
                        item.isDone ? Theme.Brand.successSoftBorder : Theme.Line.strong,
                        lineWidth: 1.2
                    )
                if item.isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.Brand.success)
                }
            }
            .frame(width: 18, height: 18)
            .frame(width: Theme.Size.minimumHitTarget, height: Theme.Size.minimumHitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(CardButtonStyle())
        .focused($focusedControl, equals: .completion)
        .accessibilityLabel(item.text)
        .accessibilityValue(item.isDone ? "已完成" : "没做完")
        .accessibilityHint("按下切换完成")
    }

    // MARK: - 文本

    /// 做完的那张变灰加删除线，不删掉也不折叠 —— 划掉的东西留在右边那列，
    /// 「今天干了什么」和「还剩什么」是同一块板上的两件事。
    ///
    /// 不加 `.fixedSize(horizontal:vertical:)`、后面也不放 `Spacer`：
    /// 详情区里这两样都会把窗口撑破（DESIGN.md 坑 1）。父级给了宽度，
    /// `Text` 自己就会换行。
    private var text: some View {
        Text(item.text)
            .font(Theme.Typo.body)
            .foregroundStyle(item.isDone ? Theme.Ink.tertiary : Theme.Ink.primary)
            // 删除线比字**深一档**（secondary 而不是 tertiary）：字变灰是「这条不重要了」，
            // 线是「这条划掉了」—— 线和字同色的话，在近白的底上它细得几乎看不见。
            .strikethrough(item.isDone, color: Theme.Ink.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            // 勾选框已经把这张卡的字念过一遍了，这里再念一次就是念两遍。
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    /// 时间放在正文下面，不再独占一行操作区。
    private var footer: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: item.isDone ? "checkmark.circle" : "clock")
                .font(.system(size: 10, weight: .medium))
                .accessibilityHidden(true)
                .allowsHitTesting(false)

            Text(TodoDate.label(for: stamp))
                .font(Theme.Typo.numeric)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .allowsHitTesting(false)

        }
        .foregroundStyle(Theme.Ink.tertiary)
    }

    private var trailing: some View {
        // 底下垫一块透明的同尺寸色块，位置才真的占得住：`.frame()` 挂在
        // 空的 `Group`（也就是 `EmptyView`）上是**不占地方**的，
        // 于是鼠标一划过，左边那行时间就会被挤着往左跳一下。
        ZStack {
            Color.clear.allowsHitTesting(false)
            if isHovering || isSelected || focusedControl != nil {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.icon(size: 26, tone: .danger))
                .focused($focusedControl, equals: .deletion)
                .help("删除这一条")
                .accessibilityLabel("删除")
            }
        }
        .frame(width: Self.trailingSlot, height: Self.trailingSlot)
    }
}
