import AppCore
import DesignSystem
import SwiftUI

/// 板上的一列：一个标题、一个计数、一摞卡片，外加一块**能接住卡片**的地方。
///
/// **为什么两列，不是一列加删除线。** 「还剩什么」和「已经干了什么」是两个问题，
/// 混在一列里，眼睛每次都要先把划掉的那些跳过去。分成两列之后，
/// 左边那列的长度**本身**就是答案，一眼就知道今天还剩多少。
///
/// 这一列整个都是落点，不只是卡片之间的缝：拖着卡在列里任何位置松手都算数 ——
/// 让人瞄准一条 2pt 宽的缝隙是刁难，不是交互。列的底和卡片是**同一种玻璃**，
/// 列的边缘保持安静，卡片通过更清楚的轮廓和悬停反馈区分。
///
/// 拖进来的时候整列亮一圈自己的色调：左列青、右列绿 —— 落点反馈得说清楚
/// **松手会发生什么**，而不只是「这里能放」。
struct TodoColumn<Card: View>: View {
    let title: String
    let systemImage: String
    /// 这一列的色调：待办 `.accent`，已完成 `.success`。计数徽章、落点高亮共用它。
    let tone: Tone
    let items: [Item]
    /// 空列上那句话。它同时也是**拖放这件事唯一的说明书** ——
    /// 界面上没有别的地方会告诉用户卡片可以拖。
    let emptyHint: String
    /// 收到一批拖进来的负载（待办的 id 字符串）。返回 false = 这一放不算数，
    /// 卡片会弹回原位。
    let onDrop: ([String]) -> Bool
    @ViewBuilder let card: (Item) -> Card

    @State private var isTargeted = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            stack
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .referenceGlassPanel(
            accent: isTargeted ? tone.tint : Theme.Brand.info.opacity(0.45),
            radius: Theme.Radius.lg
        )
        .overlay {
            if isTargeted {
                shape.strokeBorder(tone.tint, lineWidth: 1.5)
            }
        }
        .dropDestination(for: String.self) { payloads, _ in
            onDrop(payloads)
        } isTargeted: { isTargeted = $0 }
        // 列名 + 件数念成一句，VoiceOver 才知道自己走到哪一列了。
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title)，\(items.count) 件")
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tone.tint)
                .accessibilityHidden(true)

            Text(title)
                .font(Theme.Typo.headline)
                .foregroundStyle(Theme.Ink.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 数字用徽章不用一句「共 3 件」：扫两列时眼睛找的是色块的位置，
            // 不是句子的开头。
            Badge("\(items.count)", tone: tone, size: .compact)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        // 表头和卡片之间来一道发丝线：这一列是「一块板」，不是漂着的一摞卡。
        .hairline(.bottom)
    }

    private var stack: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.sm) {
                if items.isEmpty {
                    placeholder
                } else {
                    ForEach(items) { card($0) }
                }
            }
            .padding(Theme.Spacing.md)
        }
        // 内容要从页头和状态栏的玻璃底下滚过去，中间垫一层不透明的底
        // 就什么都模糊不到了。
        .scrollContentBackground(.hidden)
    }

    /// 空列不留白：一块什么都没有的空白看着像还没渲染完，
    /// 一圈虚线加一句话才是「这儿能放东西」。
    private var placeholder: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
            .strokeBorder(
                isTargeted ? tone.tint : Theme.Line.hairline,
                style: StrokeStyle(lineWidth: 1, dash: [5, 4])
            )
            .frame(height: 76)
            .overlay {
                Text(emptyHint)
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Ink.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.md)
            }
    }
}
