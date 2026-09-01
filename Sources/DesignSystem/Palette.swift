import AppCore
import AppKit
import SwiftUI

// MARK: - 槽位

/// 色板里的一个位置。
///
/// **视图层永远不写这个枚举** —— 它写 `Theme.Ink.primary` / `Theme.Glass.rim`。
/// 这里是那些名字底下的槽位：每套主题给每个槽位填一条 `Ramp`（四种外观各一组值）。
///
/// 加主题时这个枚举是**合同**：`Palette` 里的 switch 是穷尽的，
/// 漏填一个槽位编译不过 —— 不会出现「换了主题某处还是上一套颜色」。
enum ColorToken: String, CaseIterable, Sendable {

    // 表面。这几个是「减弱透明度」时的实心替身，
    // 日常绘制走下面的 glass* 薄膜。
    case canvas, content, raised, sunken, hover, border, borderStrong, shadow

    // 文字
    case ink, inkSecondary, inkTertiary

    // 品牌
    case accent, accentFill, accentSoft, accentSoftBorder, onAccent
    case info, infoSoft, infoSoftBorder
    case success, successSoft, successSoftBorder
    case danger, dangerSoft, dangerSoftBorder

    // 玻璃
    case backdrop
    /// 氛围底上左上那团光晕。
    case auraLead
    /// 右下那团。和 `auraLead` 是**邻近色**，不是补色 —— 见 DESIGN.md。
    case auraTrail
    case glassChrome, glassContent, glassPanel, glassWell, glassFloating, glassHover
    case glassRim, glassRimStrong, glassHighlight, glassShadow, glassShadowFloating
}

extension ColorToken {

    /// 动态色：**绘制时**才去查「当前是哪套主题」和「当前是哪种外观」。
    ///
    /// 这是换主题不用重建颜色对象的原因 —— `NSColor(name:dynamicProvider:)`
    /// 的闭包捕获的是**槽位**，不是色值。所以 `Theme.Ink.primary` 可以继续是个
    /// `static let`，换主题之后它自己就变了。
    ///
    /// （但已经画出来的像素不会自己重画 —— 那需要重建视图树，
    /// 见 `LetItGoApp` 里的 `.id(theme)`。）
    var color: Color { Color(nsColor: nsColor) }

    var nsColor: NSColor {
        NSColor(name: nil) { appearance in
            PaletteStore.current.ramp(for: self).nsColor(for: appearance)
        }
    }
}

// MARK: - 色板

/// 一套完整的色板。每个槽位一条 `Ramp`。
struct Palette: Sendable {
    let theme: AppTheme
    private let lookup: @Sendable (ColorToken) -> Ramp
    /// 彩色图标的色相表。只给角度 —— 亮度和饱和度是所有主题共用的一套，
    /// 见 `IconTints.swift`。
    private let hues: @Sendable (IconTint) -> Double

    init(
        _ theme: AppTheme,
        hues: @escaping @Sendable (IconTint) -> Double,
        lookup: @escaping @Sendable (ColorToken) -> Ramp
    ) {
        self.theme = theme
        self.hues = hues
        self.lookup = lookup
    }

    func ramp(for token: ColorToken) -> Ramp { lookup(token) }

    func iconHue(_ tint: IconTint) -> Double { hues(tint) }

    static func of(_ theme: AppTheme) -> Palette {
        switch theme {
        case .morandi: .morandi
        case .mist: .mist
        case .plain: .plain
        }
    }
}

// MARK: - 当前色板

/// 当前生效的色板。
///
/// **没有缓存，也没有可变全局状态** —— 每次取色都重新读一遍 UserDefaults。
/// 这样做的理由不是省事，是省掉一整类 bug：只要有缓存，就会有「缓存什么时候刷新」
/// 和「刷新和重绘谁先谁后」的问题 —— 而这两个问题的表现形式是「换了主题，
/// 有一半界面还是旧颜色」，看着像 SwiftUI 的锅，其实是自己写的竞态。
///
/// 代价是每次解析颜色多一次 UserDefaults 读（内存里的字典查找，几百纳秒）。
/// 一帧里颜色解析是几百次量级，量得出来但看不出来。
enum PaletteStore {
    static var current: Palette {
        let raw = UserDefaults.standard.string(forKey: AppTheme.storageKey) ?? ""
        return .of(AppTheme(rawValue: raw) ?? .morandi)
    }
}
