import AppCore
import DesignSystem
import SwiftUI

/// 概览 = 各个分区的快速入口。
///
/// 这里以前是块留白。留白本身没问题（它证明壳能装下更多东西），但侧边栏长到
/// 八项之后，「打开应用第一眼看到的那一页」就该干点事：把能用的分区摊开，
/// 每张卡片带着它那句说明和键盘编号 —— 说明是让人知道该点哪个，
/// 编号是让人下次不用点。
///
/// 两条规矩：
///
/// - **不列留白分区。** 一张点进去只有「功能还没接」的卡片不是入口，是死路。
///   哪些是留白由 `SidebarItem.isPlaceholder` 说了算，加分区时编译器会逼你表态。
/// - **分组和侧边栏一致。** 同一批东西在两个地方分成不同的组，用户得学两遍。
///
/// 路由住在壳里，所以这个视图也在壳里 —— 功能模块不认识 `AppState.selection`，
/// 也不该认识。
struct OverviewView: View {
    @Environment(AppState.self) private var appState

    private let columns = [
        GridItem(.adaptive(minimum: 190), spacing: Theme.Spacing.md)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                ForEach(SidebarGroup.allCases) { group in
                    let items = group.items.filter(SidebarItem.quickLaunch.contains)
                    if !items.isEmpty {
                        section(group, items)
                    }
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
    }

    private func section(_ group: SidebarGroup, _ items: [SidebarItem]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(group.title)
                .font(Theme.Typo.headline)
                .foregroundStyle(Theme.Ink.secondary)

            LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                ForEach(items) { item in
                    NavigationCard(
                        systemImage: item.systemImage,
                        tint: item.tint,
                        title: item.title,
                        subtitle: item.subtitle,
                        hint: item.shortcutNumber.map { "⌘\($0)" }
                    ) {
                        appState.selection = item
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(group.title)
    }
}
