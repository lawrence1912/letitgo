import AppCore
import DesignSystem
import SwiftUI

/// 窗口骨架：左侧栏 + 详情区 + 底部状态栏，外加全局错误 alert。
struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            SidebarView()
        } detail: {
            DetailView()
                // 状态栏**浮在**内容上方，内容从它底下滚过去 —— 这是它那层真模糊
                // 的前提：底下得真的有东西在动。`safeAreaInset` 同时把滚动视图的
                // 内容内边距补上，所以最后一行不会被压在状态栏底下。
                .safeAreaInset(edge: .bottom, spacing: 0) { StatusBar() }
                .frame(minWidth: Theme.Size.detailMinWidth)
        }
        // 边栏和详情区都自己画氛围底，不留给系统的窗口底色 ——
        // 否则拖窗口边缘时会闪出一条系统灰。这一层是兜底。
        .ambientBackdrop()
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
