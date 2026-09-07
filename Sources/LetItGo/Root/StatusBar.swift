import AppCore
import DesignSystem
import SwiftUI

/// 底部状态栏。任何界面写 `appState.statusMessage = "…"` 就能在这里显示。
///
/// 刻意做得很安静：状态栏是余光扫的东西，不是要读的东西。
/// 有话说时文字提一档亮度，没话说时整条退到三级灰。
///
/// **右边那个分区名删掉了。** 标题栏回来之后它成了第三处重复 ——
/// 窗口标题写着「随机串」，侧边栏高亮着「随机串」，状态栏右下角再写一遍
/// 「随机串」。同一件事在一屏上说三遍，第三遍不是强调，是噪音。
///
/// 它挂在 `safeAreaBar` 上（见 `RootView`），所以玻璃、边缘渐隐、
/// 内容从底下滚过去这三件事都是系统给的 —— 这里只管排字。
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

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(maxWidth: .infinity)
        .frame(height: Theme.Size.statusBarHeight)
        // 一条通栏的玻璃。`safeAreaBar` 只负责把它钉在下沿、把滚动内容的
        // 内边距补上；**背景要自己给** —— 不给的话，滚上来的正文会直接从
        // 状态文字后面穿过去。
        .background(Theme.Surface.well)
        .hairline(.top)
    }
}
