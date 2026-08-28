import AppCore
import SwiftUI

/// 菜单栏定制。`CommandGroup` 的 replacing / after / before 决定
/// 是替换系统默认项还是插在它旁边。
struct AppCommands: Commands {
    let appState: AppState

    var body: some Commands {
        // 替换「文件 > 新建」
        CommandGroup(replacing: .newItem) {
            Button("新建条目") {
                Log.ui.debug("菜单：新建条目（未实现）")
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        // 在「显示」菜单的侧边栏项后面插入分区跳转
        CommandGroup(after: .sidebar) {
            Divider()
            ForEach(Array(SidebarItem.allCases.enumerated()), id: \.element) { index, item in
                Button(item.title) { appState.selection = item }
                    .keyboardShortcut(
                        KeyEquivalent(Character("\(index + 1)")),
                        modifiers: .command
                    )
            }
        }

        CommandGroup(replacing: .help) {
            Button("LetItGo 帮助") {
                Log.ui.debug("菜单：帮助（未实现）")
            }
        }
    }
}
