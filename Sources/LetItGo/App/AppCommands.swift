import AppCore
import SwiftUI

/// 菜单栏定制。`CommandGroup` 的 replacing / after / before 决定
/// 是替换系统默认项还是插在它旁边。
struct AppCommands: Commands {
    let appState: AppState

    /// 当前界面登记的动作。没有界面登记时是 nil —— 于是「新建备忘」
    /// 在概览 / 活动分区自动变灰，「删除」在没选中东西时自动变灰，
    /// 这里不需要写任何判断分区、判断选中的代码。
    @FocusedValue(\.newItemAction) private var newItemAction
    @FocusedValue(\.deleteSelectionAction) private var deleteSelectionAction

    var body: some Commands {
        // 替换「文件 > 新建」
        CommandGroup(replacing: .newItem) {
            // 文案由登记方给：备忘分区显示「新建备忘」，别的分区自己说自己的。
            // 没人登记时给个中性的回落文案，反正那时它是灰的。
            Button(newItemAction?.title ?? "新建") { newItemAction?() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(newItemAction == nil)
        }

        // 删除也放「文件」菜单，紧挨着新建。
        //
        // 为什么不放「编辑」菜单：系统标准的编辑菜单里已经有一项「删除」
        // （它发 `delete:` 给响应链，没人接就一直是灰的），再加一项会出现
        // 两个同名的「删除」，用户没法分辨该点哪个。
        //
        // 快捷键用 ⌘⌫ 而不是裸 ⌫：菜单快捷键的优先级高于文本编辑，
        // 裸 ⌫ 会把全应用所有输入框的退格键抢走。⌘⌫ 也正是 Finder /
        // 备忘录里「删掉选中的东西」的通用手势。
        CommandGroup(after: .newItem) {
            Divider()
            Button(deleteSelectionAction?.title ?? "删除") { deleteSelectionAction?() }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(deleteSelectionAction == nil)
        }

        // 在「显示」菜单的侧边栏项后面插入分区跳转
        CommandGroup(after: .sidebar) {
            Divider()
            // 编号来自 `SidebarItem.shortcutNumber` —— 概览的卡片上显示的是
            // 同一个值，两边不会对不上。第 10 个分区开始没有快捷键：
            // 编号只有一位，`Character("10")` 会在运行时崩。
            ForEach(SidebarItem.allCases) { item in
                if let number = item.shortcutNumber {
                    Button(item.title) { appState.selection = item }
                        .keyboardShortcut(KeyEquivalent(Character("\(number)")), modifiers: .command)
                } else {
                    Button(item.title) { appState.selection = item }
                }
            }
        }

        CommandGroup(replacing: .help) {
            Button("LetItGo 帮助") {
                Log.ui.debug("菜单：帮助（未实现）")
            }
        }
    }
}
