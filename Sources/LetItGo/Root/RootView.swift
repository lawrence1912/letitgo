import AppCore
import DesignSystem
import SwiftUI

/// 窗口骨架：左侧栏 + 详情区 + 底部状态栏，外加全局错误 alert。
struct RootView: View {
    @Environment(AppState.self) private var appState

    /// 「启动时回到上次的分区」。设置里那个开关。
    @AppStorage("restoreLastSection") private var restoreLastSection = true
    /// 上次停在哪个分区。存 `rawValue`，认不出来就当没存过。
    @AppStorage("lastSection") private var lastSection = ""

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            SidebarView()
        } detail: {
            DetailView()
                // `safeAreaBar` 而不是 `safeAreaInset`：前者是 macOS 26 专门给
                // 「贴边的一条 chrome」准备的，玻璃、边缘渐隐、内容从底下滚过去
                // 全是系统的。上一版是 `safeAreaInset` 里塞一块自画的模糊层。
                .safeAreaBar(edge: .bottom) { StatusBar() }
                .frame(minWidth: Theme.Size.detailMinWidth)
        }
        // 分区切换不淡化整页，防止玻璃面板同时重叠、闪烁。
        .transaction(value: appState.selection) {
            $0.animation = nil
            $0.disablesAnimations = true
        }
        // **整扇窗口的 accent。**
        //
        // 系统控件（边栏选中、分段控件的滑块、聚焦环、勾选框）默认跟着
        // 「系统设置 → 外观 → 强调色」走，也就是那个蓝。上一版为了躲开它，
        // 把边栏和分段控件全部自绘了一遍。
        //
        // 其实一行就够：`.tint()` 沿环境往下传，所有系统控件都认它。
        // 这也是这套主题能真的换掉整个界面的原因 —— 六套色板换的不只是
        // 自己画的那些东西，连系统控件都跟着换。
        .tint(Theme.Brand.accentFill)
        // 边栏和详情区都自己画氛围底，不留给系统的窗口底色 ——
        // 否则拖窗口边缘时会闪出一条系统灰。这一层是兜底。
        .ambientBackdrop(showsPlanet: true)
        // 整扇窗口标成一个**氛围场**。侧边栏和详情区各画一份氛围底，
        // 两份都按这个场的尺寸摆星球 —— 没有它，两边只知道自己那一列有多宽，
        // 星球就会各摆各的，接缝处对不上。一扇窗口只装这一次。
        .ambientField()
        // 分区的记忆是**自己存的**，不是 AppKit 的状态恢复。
        //
        // 系统那条路已经关掉了（见 `LetItGoApp` 的 `.restorationBehavior`）——
        // 它存的是列表的**行号**，分组一变就对不上，而且会绕过 `AppState` 改值。
        // 这里存的是分区的 `rawValue`：删一个分区，认不出来就退回默认，
        // 不会跳到隔壁那一个。
        .task {
            guard restoreLastSection, let item = SidebarItem(rawValue: lastSection) else { return }
            appState.selection = item
        }
        .onChange(of: appState.selection) { _, newValue in
            lastSection = newValue?.rawValue ?? ""
        }
        .alert(
            "出错了",
            isPresented: Binding(
                get: { appState.presentedError != nil },
                set: { if !$0 { appState.presentedError = nil } }
            ),
            presenting: appState.presentedError
        ) { _ in
            Button("好", role: .cancel) {}
        } message: { error in
            Text(error.errorDescription ?? "")
        }
    }
}
