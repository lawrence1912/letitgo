import AppCore
import DesignSystem
import SwiftUI

/// 侧边栏。选中项直接绑到 `AppState.selection`，
/// 所以菜单命令、深链接改这个值时侧边栏会自动跟着高亮。
///
/// 不用 `List(selection:)` 了。系统边栏列表的选中态是一整条跟随系统强调色的
/// 蓝色高亮，那是整个界面里最「没人设计过」的一块，而且它的颜色改不了 ——
/// 要改得走资源目录里的 AccentColor，本机没装 Xcode，actool 编不了。
/// （系统蓝在这套莫兰迪色系里尤其扎眼 —— 更没法留着。）
///
/// 换成自绘的导航项后，原生列表白送的东西都自己补上了：
///   - 三个入口（点击 / Tab+⏎ / ⌘1–4）都通，⌘1–4 在 `AppCommands` 里。
///   - VoiceOver 报 `.isSelected`，并用分区说明做 hint。
///   - 悬停、按下、选中三态齐全。
///   - 选中滑块用 `matchedGeometryEffect`，减弱动态时直接跳过去。
///
/// 选中块（陶土）和焦点环（系统蓝）是两件事，会同时出现：前者是「当前在哪个分区」，
/// 后者是「键盘现在停在哪」。开了「全键盘控制」时两者可以落在不同的项上，
/// 这是 macOS 的标准行为，不是 bug。启动时不给任何控件焦点见 `AppDelegate`。
struct SidebarView: View {
    @Environment(AppState.self) private var appState

    /// 和详情区标题栏、⌘N 读的是同一个值 —— 三个入口一份实现。
    @FocusedValue(\.newItemAction) private var newItemAction

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionPill

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            identity
            // 分区列表要能滚：十一项 × 30pt 加上两个组标题，已经超过窗口的
            // 最小高度（460）了 —— 不滚的话最下面几项会被底栏压掉。
            // 标志和底栏留在外面：它们是固定的锚点，跟着滚会让人找不到。
            ScrollView {
                navigation
            }
            .scrollContentBackground(.hidden)
            .frame(maxHeight: .infinity)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // 侧边栏是外壳，比内容区暗一档 —— 这样它自成一块区域，
        // 而不是和详情区糊成同一片灰。玻璃版的「暗一档」是薄膜更薄：
        // 氛围底透上来得更多，所以它自然就比内容区沉。
        //
        // 自己画氛围底不是多余的：不画的话，`NavigationSplitView` 会给这一列
        // 垫上系统的 `.sidebar` 材质，那块材质是**透到桌面**的 ——
        // 壁纸一旦卷进来，这套界面的对比度就没法算了（见 Glass.swift 顶部）。
        .glassBackground(.chrome)
        .ambientBackdrop()
        .navigationSplitViewColumnWidth(
            min: Theme.Size.sidebarMinWidth,
            ideal: Theme.Size.sidebarIdealWidth
        )
    }

    // MARK: - 标志

    private var identity: some View {
        HStack(spacing: Theme.Spacing.sm) {
            BrandMark()
                .fill(Theme.Brand.accent)
                .frame(width: 15, height: 16)

            Text("LetItGo")
                .font(.system(size: 13, weight: .semibold))
                .tracking(Theme.Typo.titleTracking)
                .foregroundStyle(Theme.Ink.primary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.md)
        // 无标题栏窗口的红绿灯浮在这块区域上，给它让位。
        .padding(.top, Theme.Size.trafficLightInset)
        .padding(.bottom, Theme.Spacing.lg)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("LetItGo")
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - 导航

    private var navigation: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            ForEach(SidebarGroup.allCases) { group in
                VStack(spacing: 1) {
                    Text(group.title)
                        .font(Theme.Typo.caption)
                        .foregroundStyle(Theme.Ink.tertiary)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.bottom, Theme.Spacing.xxs)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // 组标题是给眼睛分块用的，VoiceOver 那边由下面的
                        // `.accessibilityLabel` 承担分组语义，念两遍是噪音。
                        .accessibilityHidden(true)

                    ForEach(group.items) { item in
                        NavigationRow(
                            item: item,
                            isSelected: appState.selection == item,
                            namespace: selectionPill
                        ) {
                            appState.selection = item
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(group.title)
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .animation(Theme.Motion.spring(reduceMotion: reduceMotion), value: appState.selection)
        .accessibilityElement(children: .contain)
    }

    private struct NavigationRow: View {
        let item: SidebarItem
        let isSelected: Bool
        let namespace: Namespace.ID
        let action: () -> Void

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var isHovering = false

        private var shape: RoundedRectangle {
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
        }

        var body: some View {
            Button(action: action) {
                HStack(spacing: Theme.Spacing.sm) {
                    // 图标带着分区自己的辨识色，选中与否都不变 ——
                    // 「当前在哪个分区」由那块琥珀滑块和加粗的标题说，
                    // 不需要图标再说第三遍，而颜色一变，按颜色找分区那条路就断了。
                    Image(systemName: item.systemImage)
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 16)
                        .foregroundStyle(item.tint.tint)

                    Text(item.title)
                        .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Theme.Ink.primary : Theme.Ink.secondary)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Theme.Spacing.sm)
                .frame(height: 30)
                .background {
                    if isSelected {
                        // 一块滑块在四个位置之间移动，而不是四块各自淡入淡出 ——
                        // 前者看得出「同一个东西挪过去了」。
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
            .accessibilityLabel(item.title)
            .accessibilityHint(item.subtitle)
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        }
    }

    // MARK: - 底栏
    //
    // 分工：左边是内容操作，右边是应用级 chrome（外观属于后者）。

    private var footer: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                newItemAction?()
            } label: {
                // 边栏底部的 "+" 在 macOS 上是通用词汇（Finder / 邮件 / Xcode），
                // 收成纯图标换密度；辅助技术读到的仍是登记方给的标题。
                Image(systemName: "plus")
            }
            .buttonStyle(.icon)
            .disabled(newItemAction == nil)
            .accessibilityLabel(newItemAction?.title ?? "新建")
            .help("\(newItemAction?.title ?? "新建")（⌘N）")

            Spacer(minLength: Theme.Spacing.sm)

            AppearancePicker()
        }
        .padding(Theme.Spacing.sm)
        .hairline(.top)
    }
}
