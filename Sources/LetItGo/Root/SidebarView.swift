import AppCore
import DesignSystem
import SwiftUI

/// 侧边栏。选中项直接绑到 `AppState.selection`，
/// 所以菜单命令、深链接改这个值时侧边栏会自动跟着高亮。
struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        List(selection: $appState.selection) {
            Section("分区") {
                ForEach(SidebarItem.allCases) { item in
                    Label(item.title, systemImage: item.systemImage)
                        .tag(item)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(
            min: Theme.Size.sidebarMinWidth,
            ideal: Theme.Size.sidebarIdealWidth
        )
        .safeAreaInset(edge: .bottom) {
            // 底栏分工：左边是内容操作，右边是应用级 chrome（外观属于后者，
            // 所以不放工具栏 —— 工具栏在 macOS 上是内容操作的地盘）。
            VStack(spacing: 0) {
                Divider()

                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        Log.ui.debug("侧边栏：新建（未实现）")
                    } label: {
                        // 边栏底部的 "+" 在 macOS 上是通用词汇（Finder / 邮件 / Xcode），
                        // 收成纯图标换密度；辅助技术读到的仍是 "新建条目"。
                        Label("新建条目", systemImage: "plus")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .help("新建条目")

                    Spacer(minLength: Theme.Spacing.sm)

                    AppearancePicker()
                }
                .controlSize(.small)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
            }
            // 不是装饰性毛玻璃：safeAreaInset 只预留空间、不挡内容，
            // 列表回弹过冲时行会从按钮底下滑过去。.bar 是 SwiftUI 给
            // 工具条/底栏的语义材质，能正确叠在边栏的半透明背景上。
            .background(.bar)
        }
    }
}
