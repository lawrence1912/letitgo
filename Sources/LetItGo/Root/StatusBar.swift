import AppCore
import DesignSystem
import SwiftUI

/// 底部状态栏。任何界面写 `appState.statusMessage = "…"` 就能在这里显示。
struct StatusBar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(appState.statusMessage ?? "就绪")
                .font(.caption)
                .foregroundStyle(Theme.Palette.secondaryLabel)

            Spacer()

            Text(appState.selection?.title ?? "—")
                .font(.caption.monospaced())
                .foregroundStyle(Theme.Palette.secondaryLabel)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: Theme.Size.statusBarHeight)
        .background(Theme.Palette.surface)
    }
}
