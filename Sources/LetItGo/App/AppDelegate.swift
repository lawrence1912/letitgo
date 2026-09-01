import AppCore
import AppKit

/// SwiftUI 生命周期覆盖不到的地方（Dock 菜单、URL scheme、推送注册、
/// 退出前收尾…）在这里挂钩子。现在只有日志，方法体留空等着填。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// 在任何文本控件建出来之前，把系统的「智能替换」全部关掉。
    ///
    /// macOS 的 `NSTextView` / `NSTextField` 默认开着智能引号替换：
    /// **你打一个 `"`，它给你一个 `“` 或 `”`**。在写文章的应用里这是贴心，
    /// 在一个装着 JSON、JWT、PEM、正则的工具箱里这是灾难 ——
    /// 打出来的 JSON 解析不了，而且肉眼几乎看不出哪里不对。
    ///
    /// 破折号替换（`--` → `—`）、文本替换、自动纠错同理，一起关。
    /// 这几个键写在**本应用自己的域**里，优先级高于系统全局设置，
    /// 也不会影响别的应用。
    func applicationWillFinishLaunching(_ notification: Notification) {
        for key in [
            "NSAutomaticQuoteSubstitutionEnabled",
            "NSAutomaticDashSubstitutionEnabled",
            "NSAutomaticTextReplacementEnabled",
            "NSAutomaticSpellingCorrectionEnabled",
            "NSAutomaticPeriodSubstitutionEnabled",
            "NSAutomaticCapitalizationEnabled",
        ] {
            UserDefaults.standard.set(false, forKey: key)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.info("启动完成")
        clearInitialFocusRing()
    }

    /// 开了「全键盘控制」的机器上，窗口一打开 AppKit 就会把第一响应者给到
    /// 键视图循环里的第一个控件 —— 于是侧边栏的第一项顶着一圈焦点环出现，
    /// 而当前分区可能是另一项，看着像两个高亮在打架。
    ///
    /// 这里在窗口建好之后把第一响应者清掉：**焦点环只在用户按了 Tab 之后才出现**。
    /// 键盘可达性一点没丢 —— Tab 照样从头开始走。
    private func clearInitialFocusRing() {
        DispatchQueue.main.async {
            for window in NSApp.windows {
                window.makeFirstResponder(nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Log.app.info("即将退出")
    }

    /// 关掉最后一个窗口就退出。若做成常驻型应用，这里返回 false。
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
