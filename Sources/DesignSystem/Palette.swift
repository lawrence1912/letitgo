import AppCore
import AppKit
import Observation
import SwiftUI

// MARK: - 槽位

/// 色板里的一个位置。
///
/// **视图层永远不写这个枚举** —— 它写 `Theme.Ink.primary` / `Theme.Line.hairline`。
/// 这里是那些名字底下的槽位：每套主题给每个槽位填一条 `Ramp`（四种外观各一组值）。
///
/// 加主题时这个枚举是**合同**：`Palette` 里的 switch 是穷尽的，
/// 漏填一个槽位编译不过 —— 不会出现「换了主题某处还是上一套颜色」。
enum ColorToken: String, CaseIterable, Sendable {

    // MARK: 氛围场
    //
    // 玻璃底下那层**会被折射的东西**。系统的 Liquid Glass 是一层光学材质，
    // 不是一块半透明的颜色 —— 它折射、弯折、采样的是背后真实存在的内容。
    // 背后什么都没有的话，一块玻璃面板出来就是一块灰板。
    // 所以这五个槽位不是装饰，它们是这套材质的**前提**。

    case backdrop
    /// 能量星球的发光环。
    case auraLead
    /// 星球的暗球体。和 `auraLead` 是邻近色，不是补色。
    case auraTrail
    /// 星球的外晕；不需要第三层的主题把它设为全透明。
    case auraDeep
    /// 氛围底上那层细网格。玻璃底下垫一层**有规律的东西**，
    /// 移动窗口、滚动内容时才看得出哪一层在动。
    case gridLine

    // MARK: 读写面
    //
    // 正文躺着的那块地：代码框、结果区、长文本。**唯一一块不上玻璃的表面**，
    // 而且必须不上 —— 见 `Glass.swift` 里「什么东西不该是玻璃」那一节。
    case well

        // MARK: 玻璃的边
        /// 左上那道镜面高光：**光**。六套共用一档冷白 —— 光没有主题。
        case rimSpecular
        /// 右下那道色散边：**色**。跟着每套主题自己的 accent 色相走。
        case rimDispersion

    // MARK: 文字
    case ink, inkSecondary, inkTertiary

    // MARK: 边界与悬停
    //
    // 系统玻璃自带边缘和高光，**不要再描一圈**。剩下这三个管的是玻璃管不着的东西：
    // 分割线、自绘行的悬停底、需要读出来的容器边界（拖放高亮、聚焦的槽）。
    case border, borderStrong, hover

    // MARK: 品牌
    //
    // `accentFill` 现在的主要身份是**玻璃的 tint**（`Glass.tint(_:)`）和
    // `.tint()` 递给系统控件的那个色，不再是自己画的一块填充。

    case accent, accentFill, accentSoft, accentSoftBorder
    /// 输入框聚焦时那一圈实线。比 `accent` 亮一档、浓一档 ——
    /// `accent` 是个文字色，浅色外观下必须够深才读得清，拿它画环出来是道墨线。
    case focusRing
    case info, infoSoft, infoSoftBorder
    case success, successSoft, successSoftBorder
    case danger, dangerSoft, dangerSoftBorder
}

extension ColorToken {

    /// 在视图求值时观察主题，绘制时再按系统外观解析这一套颜色。
    @MainActor
    var color: Color { Color(nsColor: nsColor) }

    @MainActor
    var nsColor: NSColor {
        let ramp = PaletteStore.current.ramp(for: self)
        return NSColor(name: nil) { appearance in
            ramp.nsColor(for: appearance)
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
        case .prism: .prism
        case .nebula: .nebula
        case .frost: .frost
        case .morandi: .morandi
        case .mist: .mist
        case .plain: .plain
        }
    }
}

// MARK: - 当前色板

/// 应用级外观状态。读取颜色的视图会观察它，不需要更换视图身份。
@MainActor
@Observable
final class PaletteStore {
    static let shared = PaletteStore()
    var theme: AppTheme

    private init() {
        let raw = UserDefaults.standard.string(forKey: AppTheme.storageKey) ?? ""
        theme = AppTheme(rawValue: raw) ?? .fallback
    }

    static var current: Palette {
        .of(shared.theme)
    }
}

extension Theme {
    @MainActor
    public static func apply(_ theme: AppTheme) {
        PaletteStore.shared.theme = theme
    }
}
