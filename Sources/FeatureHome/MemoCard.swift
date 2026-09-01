import AppCore
import DesignSystem
import SwiftUI

/// 一条备忘的卡片：标题、正文、写下的时间。
///
/// **为什么是卡片，不是一行。** 备忘的正文天生是多行的，一行的列表只能显示
/// 它的前二十个字 —— 那样的列表用来「找到某一条」还行，用来「读」是不行的。
/// 卡片给正文三行的位置，一屏就能真的读到内容，而不是读到一列标题。
///
/// **高度是钉死的**：标题两行、正文三行，都用 `reservesSpace` 占住。
/// 网格里同一行卡片的高度由最高的那张决定，长短不一会排出一排锯齿。
/// 注意这件事不能改用 `.fixedSize(horizontal:vertical:)` 做 ——
/// 在详情区里它会把整个窗口撑破（DESIGN.md 坑 1）。
///
/// 整张卡是一个 `Button`：Tab 能到、⏎ / 空格能按、辅助功能角色是「按钮」，
/// 而且靶子有整张卡那么大。单击选中，双击打开来读全文。
struct MemoCard: View {
    let item: Item
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    /// 正文预览的行数。三行是「读得到一段话」和「一屏排得下两行卡片」之间的位置 ——
    /// 再多一行，短备忘的卡片下半截就全是空的。
    private static let previewLines = 3

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
    }

    /// 选中和悬停是两件事，所以描边分两档：选中用强调色（和侧边栏当前分区
    /// 同一套语汇），悬停只把中性描边提亮一档 —— 强调色的名额不发给
    /// 「鼠标正好路过这儿」。
    private var rim: Color? {
        if isSelected { return Theme.Brand.accentSoftBorder }
        return isHovering ? Theme.Glass.rimStrong : nil
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(item.title)
                    .font(Theme.Typo.headline)
                    .foregroundStyle(Theme.Ink.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2, reservesSpace: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                preview
                footer
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            // 选中的浅底垫在内容和玻璃之间：`.panel` 会再往后垫一层薄膜，
            // 所以这一层是透过玻璃看到的色，不是盖在文字上的色。
            .background { if isSelected { shape.fill(Theme.Brand.accentSoft) } }
            .panel(rim: rim, elevated: isSelected || isHovering)
            .contentShape(shape)
            .contentShape(.focusEffect, shape)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        // 双击打开全文。用 `simultaneousGesture` 叠上去，而不是把单击换掉 ——
        // 单击选中必须留着，⌘⌫ 删的就是选中的那几条。
        .simultaneousGesture(TapGesture(count: 2).onEnded { onOpen() })
        .animation(Theme.Motion.fast(reduceMotion: reduceMotion), value: isHovering)
        .accessibilityLabel(spokenLabel)
        .accessibilityHint("双击查看全文")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// 正文预览。空正文显示一句灰字而不是留白 ——
    /// 一块什么都没有的空白看着像还没渲染完，一句「没有正文」才是信息。
    @ViewBuilder
    private var preview: some View {
        Text(item.content.isEmpty ? "没有正文" : item.content)
            .font(Theme.Typo.body)
            .foregroundStyle(item.content.isEmpty ? Theme.Ink.tertiary : Theme.Ink.secondary)
            .multilineTextAlignment(.leading)
            .lineLimit(Self.previewLines, reservesSpace: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 页脚：时间在左，双击提示在右（只在悬停时出现）。
    ///
    /// 提示对辅助技术隐藏 —— 同一件事已经由 `accessibilityHint` 说过一遍了。
    private var footer: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "clock")
                .font(.system(size: 10, weight: .medium))
                .accessibilityHidden(true)

            Text(MemoDate.label(for: item.createdAt))
                .font(Theme.Typo.numeric)
                .lineLimit(1)

            Spacer(minLength: Theme.Spacing.sm)

            if isHovering {
                Text("双击查看")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Ink.tertiary)
                    .lineLimit(1)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(Theme.Ink.secondary)
        // 页脚离正文比正文离标题远一点：时间是这条备忘的**元信息**，
        // 不是正文的最后一行，间距得说出这件事。
        .padding(.top, Theme.Spacing.xs)
    }

    /// VoiceOver 念的是**完整**正文，不是被截断的三行 ——
    /// 截断是版面的事，不是内容的事。
    private var spokenLabel: String {
        let time = MemoDate.label(for: item.createdAt)
        return item.content.isEmpty
            ? "\(item.title)，\(time)，没有正文"
            : "\(item.title)，\(time)，\(item.content)"
    }
}
