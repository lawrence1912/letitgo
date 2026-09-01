import AppCore
import DesignSystem
import FeatureHome
import FeatureToolbox
import SwiftUI

/// 路由层：把侧边栏的选中项映射到具体的功能模块，并给每个分区戴上同一顶标题栏。
///
/// switch 是穷尽的 —— 给 `SidebarItem` 加 case 时编译器会在这里报错，
/// 提醒你把新界面接上，不会出现「加了菜单但没有页面」的情况。
struct DetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies

    /// 当前界面登记的主操作（`HomeView` 用 `.focusedSceneValue` 登记）。
    /// 没人登记就不显示 —— 在「概览」上摆一个永远灰着的「新建」什么也没教给用户。
    @FocusedValue(\.newItemAction) private var newItemAction

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // 页头浮在内容上方（不是叠在它前面的一格），内容从它底下滚过去。
            // 换成玻璃之后这件事有了意义：页头那层模糊终于有东西可模糊。
            .safeAreaInset(edge: .top, spacing: 0) { header }
            // 玻璃薄膜在上、氛围底在下 —— `.background` 每加一层都往后垫。
            .glassBackground(.content)
            .ambientBackdrop()
            // 窗口标题栏是隐藏的，但这个值仍然是窗口在「窗口」菜单、
            // Mission Control 和辅助功能里的名字，不能省。
            .navigationTitle(appState.selection?.title ?? "LetItGo")
    }

    private var header: some View {
        PageHeader(
            appState.selection?.title ?? "LetItGo",
            subtitle: appState.selection?.subtitle
        ) {
            if let newItemAction {
                Button {
                    newItemAction()
                } label: {
                    Label(newItemAction.title, systemImage: "plus")
                }
                // 次要样式，不是主按钮：空态里那个大按钮才是主操作。
                // 一屏只留一个响亮的按钮，两个一样响的等于没有主次。
                .buttonStyle(.secondaryAction)
                .help("\(newItemAction.title)（⌘N）")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch appState.selection {
        case .overview:
            OverviewView()

        case .items:
            // 唯一一条接通了的竖切面：View → Model → Repository → 磁盘
            HomeView(repository: dependencies.items, now: dependencies.now)

        case .activity:
            EmptyStateView(
                systemImage: "clock.arrow.circlepath",
                title: "活动",
                message: "这里放操作历史 / 时间线。功能还没接。"
            )

        // 三个小工具。它们不碰依赖 —— 全是纯函数，没有 I/O，
        // 所以这里不用递任何东西进去。
        case .codec:
            CodecView()

        case .timestamp:
            TimestampView()

        case .hash:
            HashView()

        case .random:
            RandomStringView()

        case .json:
            JSONView()

        case .jwt:
            JWTView()

        case .rsa:
            RSAView()

        case nil:
            EmptyStateView(
                systemImage: "sidebar.left",
                title: "从左边选一个分区",
                message: nil
            )
        }
    }
}
