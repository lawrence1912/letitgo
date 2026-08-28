import AppCore
import DesignSystem
import FeatureHome
import SwiftUI

/// 路由层：把侧边栏的选中项映射到具体的功能模块。
///
/// switch 是穷尽的 —— 给 `SidebarItem` 加 case 时编译器会在这里报错，
/// 提醒你把新界面接上，不会出现「加了菜单但没有页面」的情况。
struct DetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies

    var body: some View {
        Group {
            switch appState.selection {
            case .overview:
                EmptyStateView(
                    systemImage: "square.grid.2x2",
                    title: "概览",
                    message: "这里放仪表盘 / 汇总信息。功能还没接。"
                )

            case .items:
                // 唯一一条接通了的竖切面：View → Model → Repository
                HomeView(repository: dependencies.items)

            case .activity:
                EmptyStateView(
                    systemImage: "clock.arrow.circlepath",
                    title: "活动",
                    message: "这里放操作历史 / 时间线。功能还没接。"
                )

            case nil:
                EmptyStateView(
                    systemImage: "sidebar.left",
                    title: "从左边选一个分区",
                    message: nil
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.background)
        .navigationTitle(appState.selection?.title ?? "LetItGo")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Log.ui.debug("工具栏：主操作（未实现）")
                } label: {
                    Label("操作", systemImage: "plus")
                }
            }
        }
    }
}
