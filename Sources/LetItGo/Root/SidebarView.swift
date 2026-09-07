import AppCore
import DesignSystem
import SwiftUI

/// 参考图的独立玻璃侧栏，选中外观由应用绘制；分区和快捷键仍由 AppState 管理。
struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @FocusedValue(\.newItemAction) private var newItemAction
    @FocusState private var focusedItem: SidebarItem?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(Theme.Brand.info)
                Text("LetItGo")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Ink.primary)
                Spacer(minLength: 0)
            }
            .padding(Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.xs)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        ForEach(SidebarGroup.allCases) { group in
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(group.title)
                                    .font(Theme.Typo.caption)
                                    .foregroundStyle(Theme.Ink.tertiary)
                                    .padding(.horizontal, Theme.Spacing.lg)
                                ForEach(group.items) { item in
                                    Button { appState.selection = item } label: {
                                        GlassNavigationRow(
                                            title: item.title,
                                            systemImage: item.systemImage,
                                            isSelected: appState.selection == item,
                                            isFocused: focusedItem == item
                                        )
                                    }
                                    .buttonStyle(CardButtonStyle())
                                    .focused($focusedItem, equals: item)
                                    .accessibilityLabel(item.title)
                                    .accessibilityHint(item.hint)
                                    .accessibilityAddTraits(appState.selection == item ? [.isSelected] : [])
                                    .id(item)
                                }
                            }
                        }
                    }
                    .padding(.vertical, Theme.Spacing.sm)
                }
                .onChange(of: appState.selection) { _, selection in
                    if let selection { proxy.scrollTo(selection) }
                }
            }
            .onKeyPress(.upArrow) { moveSelection(by: -1); return .handled }
            .onKeyPress(.downArrow) { moveSelection(by: 1); return .handled }

            footer
        }
        .referenceGlassPanel(accent: Theme.Brand.info, radius: Theme.Radius.lg)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.md)
        .ambientBackdrop(showsPlanet: true)
        .navigationSplitViewColumnWidth(
            min: Theme.Size.sidebarMinWidth,
            ideal: Theme.Size.sidebarIdealWidth
        )
        .transaction { $0.animation = nil }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("边栏")
    }

    private func moveSelection(by offset: Int) {
        let items = SidebarGroup.allCases.flatMap(\.items)
        guard !items.isEmpty else { return }
        let current = focusedItem ?? appState.selection
        let index = current.flatMap { items.firstIndex(of: $0) } ?? (offset > 0 ? -1 : items.count)
        let next = items[min(max(index + offset, 0), items.count - 1)]
        focusedItem = next
        appState.selection = next
    }

    private var footer: some View {
        HStack(spacing: 0) {
            Button { newItemAction?() } label: { Image(systemName: "plus") }
                .buttonStyle(.icon)
                .disabled(newItemAction == nil)
                .accessibilityLabel(newItemAction?.title ?? "新建")
                .help("\(newItemAction?.title ?? "新建")（⌘N）")
            Spacer(minLength: 0)
            AppearancePicker()
        }
        .padding(.horizontal, Theme.Spacing.xs)
        .padding(.vertical, Theme.Spacing.sm)
        .hairline(.top)
    }
}
