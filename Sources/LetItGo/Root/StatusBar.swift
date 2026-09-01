import AppCore
import DesignSystem
import SwiftUI

/// 底部状态栏。任何界面写 `appState.statusMessage = "…"` 就能在这里显示。
///
/// 刻意做得很安静：状态栏是余光扫的东西，不是要读的东西。
/// 有话说时文字提一档亮度，没话说时整条退到三级灰。
struct StatusBar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(appState.statusMessage ?? "就绪")
                .font(Theme.Typo.caption)
                .foregroundStyle(
                    appState.statusMessage == nil ? Theme.Ink.tertiary : Theme.Ink.secondary
                )
                .lineLimit(1)

            Spacer(minLength: Theme.Spacing.sm)

            Text(appState.selection?.title ?? "—")
                .font(Theme.Typo.mono)
                .foregroundStyle(Theme.Ink.tertiary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: Theme.Size.statusBarHeight)
        // 内容从状态栏底下滚过去，所以这一条要真模糊。
        .glassBackground(.frosted)
        .hairline(.top)
    }
}
