import AppCore
import AppKit

/// SwiftUI 生命周期覆盖不到的地方（Dock 菜单、URL scheme、推送注册、
/// 退出前收尾…）在这里挂钩子。现在只有日志，方法体留空等着填。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.info("启动完成")
    }

    func applicationWillTerminate(_ notification: Notification) {
        Log.app.info("即将退出")
    }

    /// 关掉最后一个窗口就退出。若做成常驻型应用，这里返回 false。
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
