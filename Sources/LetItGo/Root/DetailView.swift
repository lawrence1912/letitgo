import AppCore
import DesignSystem
import FeatureHome
import FeatureToolbox
import SwiftUI

/// 路由层：把侧边栏的选中项映射到具体的功能模块，并把当前分区的主操作
/// 挂到窗口工具栏上。
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
            .transition(.identity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // 氛围场垫在最底下。工具栏那层玻璃折射的就是它 ——
            // 内容默认从工具栏底下穿过去（macOS 26 的 chrome 是浮在内容上的），
            // 所以滚动时能看见字从玻璃后面走过。
            .ambientBackdrop(showsPlanet: true)
            // 窗口标题栏回来了，分区标题就还给它。
            //
            // 上一版是自绘的 `PageHeader`：无标题栏窗口 + 详情区顶部一条
            // 52pt 高的自画标题栏。那套的理由是「系统标题栏放不下
            // 分区标题 + 这个分区的主操作那一行」—— 在 macOS 26 上不成立了：
            // 工具栏本身是 Liquid Glass，能装下标题和操作，还自带
            // 滚动边缘渐隐、窗口拖动、全屏按钮和自定义能力。
            //
            // 顺带删掉的还有那个 `trafficLightInset` —— 红绿灯回到了标题栏里，
            // 不再需要侧边栏顶部给它硬留 28pt。
            .navigationTitle(appState.selection?.title ?? "LetItGo")
            .toolbar {
                if let newItemAction {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            newItemAction()
                        } label: {
                            Label(newItemAction.title, systemImage: "plus")
                        }
                        .help("\(newItemAction.title)（⌘N）")
                    }
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
