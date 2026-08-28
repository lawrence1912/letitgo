import AppCore
import AppKit

/// 把 `Appearance` 落到 `NSApplication` 上。
///
/// 为什么不是 SwiftUI 的 `.preferredColorScheme`：那个只作用于 SwiftUI 视图树，
/// 标题栏、菜单栏、右键菜单这些 AppKit 绘制的部分不会跟着变，会出现半深半浅。
/// 设 `NSApp.appearance` 是 macOS 上唯一能一次盖全的做法。
///
/// 置 `nil` 即恢复跟随系统 —— 系统在浅深之间切换时应用会自动跟上。
@MainActor
enum AppearanceController {
    static func apply(_ appearance: Appearance) {
        NSApplication.shared.appearance = switch appearance {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
        Log.ui.debug("外观切换为 \(appearance.rawValue, privacy: .public)")
    }
}
