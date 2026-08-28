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
            VStack(spacing: 0) {
                DetailView()
                Divider()
                StatusBar()
            }
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
