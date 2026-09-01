import AppCore
import Foundation

@testable import DesignSystem

/// 四种外观各是色板里的一「格」。
enum Slot: String, CaseIterable, CustomStringConvertible {
    case light, dark, lightHC, darkHC

    static let normal: [Slot] = [.light, .dark]
    static let highContrast: [Slot] = [.lightHC, .darkHC]
    static let all: [Slot] = allCases

    var description: String { rawValue }
}

extension Ramp {
    func value(_ slot: Slot) -> OKLCH {
        switch slot {
        case .light: light
        case .dark: dark
        case .lightHC: lightHC
        case .darkHC: darkHC
        }
    }
}

/// 界面上真正会出现的表面。名字带 Surface 后缀是为了和 `ColorToken` 里
/// 那些**薄膜**分开 —— 薄膜是原料，这些是合成结果。
enum Surface: String, CaseIterable {
    /// 侧边栏 / 底部操作条：chrome 薄膜压在氛围底上。
    case canvasSurface
    /// 主工作区。
    case contentSurface
    /// 卡片 / 行：panel 薄膜压在内容区上。
    case raisedSurface
    /// 输入框 / 槽：well 薄膜压在内容区上。
    case sunkenSurface
    /// 悬停：hover 薄膜压在外壳上（导航项是最常见的那个）。
    case hoverSurface
    /// sheet：自己带一份氛围底，所以直接压在氛围底上。
    case floatingSurface
}

struct RGB {
    var r: Double
    var g: Double
    var b: Double
    var a: Double
}

/// 按**绘制时的顺序**把一套色板合成出来。
///
/// 这不是「近似模拟」——层的顺序、每层的 alpha、合成发生在 gamma 空间
/// （屏幕就是这么混的），都和 `GlassPane` / `panel()` 实际画出来的一致。
struct Composite {
    let theme: AppTheme
    let slot: Slot
    private let palette: Palette

    /// 氛围底的**亮度带**：没有光晕的地方、单团最浓处、两团叠加处。
    /// 玻璃是半透明的，所以同一块面板压在带的两端会得到两个颜色 ——
    /// 对比度得按最差的那一端算。
    private let band: [RGB]

    init(theme: AppTheme, slot: Slot) {
        self.theme = theme
        self.slot = slot
        self.palette = .of(theme)

        let base = Self.rgb(palette.ramp(for: .backdrop).value(slot))
        let lead = Self.rgb(palette.ramp(for: .auraLead).value(slot))
        let trail = Self.rgb(palette.ramp(for: .auraTrail).value(slot))
        let both = Self.over(trail, Self.over(lead, base))
        self.band = [base, Self.over(lead, base), Self.over(trail, base), both]
    }

    // MARK: - 取色

    /// 一个槽位在当前主题 / 外观下的原始色（不合成）。
    func flat(_ token: ColorToken) -> RGB {
        Self.rgb(palette.ramp(for: token).value(slot))
    }

    /// 一个表面在亮度带上的每一处的合成结果。
    func samples(of surface: Surface) -> [RGB] {
        let content = band.map { Self.over(flat(.glassContent), $0) }
        let canvas = band.map { Self.over(flat(.glassChrome), $0) }
        return switch surface {
        case .canvasSurface: canvas
        case .contentSurface: content
        case .raisedSurface: content.map { Self.over(flat(.glassPanel), $0) }
        case .sunkenSurface: content.map { Self.over(flat(.glassWell), $0) }
        case .hoverSurface: canvas.map { Self.over(flat(.glassHover), $0) }
        case .floatingSurface: band.map { Self.over(flat(.glassFloating), $0) }
        }
    }

    func luminance(_ surface: Surface) -> Double {
        Self.luminance(samples(of: surface)[0])
    }

    // MARK: - 最差格

    /// 一族彩色图标的某个角色在当前主题 / 外观下的色值。
    func icon(_ tint: IconTint, _ role: IconRole) -> RGB {
        Self.rgb(tint.ramp(role, in: palette).value(slot))
    }

    /// 一个文字色压在**所有**表面、**整条**亮度带上，最差的那一格。
    func worstSurface(for text: ColorToken) -> (Surface, Double) {
        worstSurface(forInk: flat(text))
    }

    func worstSurface(forInk ink: RGB) -> (Surface, Double) {
        var worst = (Surface.contentSurface, Double.infinity)
        for surface in Surface.allCases {
            for sample in samples(of: surface) {
                let ratio = contrast(ink, sample)
                if ratio < worst.1 { worst = (surface, ratio) }
            }
        }
        return worst
    }

    /// 色调文字压在同色调浅底上 —— 而浅底自己压在内容区 / 外壳 / 面板上。
    func worstToneFill(tint: ColorToken, soft: ColorToken) -> Double {
        worstToneFill(ink: flat(tint), fill: flat(soft))
    }

    func worstToneFill(ink: RGB, fill: RGB) -> Double {
        var worst = Double.infinity
        for surface in [Surface.contentSurface, .canvasSurface, .raisedSurface] {
            for sample in samples(of: surface) {
                worst = min(worst, contrast(ink, Self.over(fill, sample)))
            }
        }
        return worst
    }

    // MARK: - 色彩数学

    func contrast(_ a: RGB, _ b: RGB) -> Double {
        let (hi, lo) = (max(Self.luminance(a), Self.luminance(b)), min(Self.luminance(a), Self.luminance(b)))
        return (hi + 0.05) / (lo + 0.05)
    }

    private static func rgb(_ color: OKLCH) -> RGB {
        let (r, g, b) = color.srgb
        return RGB(r: r, g: g, b: b, a: color.alpha)
    }

    /// alpha 合成。**在 gamma 空间做** —— 屏幕就是这么混的，
    /// 在线性空间算出来的结果和眼睛看到的不是一回事。
    private static func over(_ src: RGB, _ dst: RGB) -> RGB {
        RGB(
            r: src.r * src.a + dst.r * (1 - src.a),
            g: src.g * src.a + dst.g * (1 - src.a),
            b: src.b * src.a + dst.b * (1 - src.a),
            a: 1
        )
    }

    /// WCAG 相对亮度。
    private static func luminance(_ color: RGB) -> Double {
        func linear(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b)
    }
}

// MARK: - 分组

extension ColorToken {
    /// 会被拿来放正文的色。三级文字不在里面 —— 它的底线是 3:1，单独测。
    static let bodyLevelText: [ColorToken] = [
        .ink, .inkSecondary, .accent, .info, .success, .danger,
    ]

    /// 色调文字和它自己的浅底。
    static let tonePairs: [(ColorToken, ColorToken)] = [
        (.accent, .accentSoft), (.info, .infoSoft),
        (.success, .successSoft), (.danger, .dangerSoft),
    ]

    /// 玻璃薄膜。增强对比度下它们必须变成不透明的。
    static let films: [ColorToken] = [
        .glassChrome, .glassContent, .glassPanel, .glassWell, .glassFloating, .glassHover,
    ]
}
