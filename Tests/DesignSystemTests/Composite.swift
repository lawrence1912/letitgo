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

/// 界面上文字真正躺着的那两块底。
///
/// ## 为什么只剩两块
///
/// 上一版这里有六块（外壳 / 内容 / 面板 / 槽 / 悬停 / 浮层），因为那时候
/// **每一层都是自己画的**：一块面板的最终颜色 = 氛围底 → 每一层薄膜 → 它自己，
/// 逐层 alpha 合成，算得出来。
///
/// 换成系统 Liquid Glass 之后那个前提没了。系统材质怎么混、混多少、
/// 它按背后的内容做了什么自适应 —— 我们既不知道也不该假设。
/// 继续拿一个编出来的 alpha 去「合成」它，算出来的数会很好看，但它是假的，
/// **而一个假的对比度测试比没有测试更坏**。
///
/// 所以这套测试退回到还归自己管的两块：
enum Surface: String, CaseIterable {
    /// 氛围场：氛围底 + 网格 + 星球那几层。全是自己画的，不透明，亮度带已知。
    ///
    /// 玻璃压在它上面，所以它是**下界**：一段字如果直接压在氛围场上就读得清，
    /// 那么隔着一层玻璃看也读得清 —— 玻璃只会把背后往中间调拉，
    /// 不会把对比度拉得比这更差。
    ///
    /// 亮度带里**也包含压了那道斜光的那几格**（`Theme.Line.sheen`）。
    /// 斜光是我们自己画的、而且就压在正文底下，所以它必须进合成链 ——
    /// 系统材质算不了，不代表自己加的那层也可以不算。
    ///
    /// 这是一条**假设**，不是算出来的结论。写在这儿是为了让它可被反驳：
    /// 哪天发现某个外观下不成立，改的是这条注释和下面的门槛，不是悄悄调色值。
    case field
    /// 读写面：代码框、结果区、长文本。不透明，**唯一一块能精确算的底**。
    ///
    /// 它也是最要紧的一块 —— 一屏上要逐字读的东西全在这儿。
    case well
}

struct RGB {
    var r: Double
    var g: Double
    var b: Double
    var a: Double
}

/// 按绘制时的顺序把一套色板里**还归自己画**的那几层合成出来。
struct Composite {
    let theme: AppTheme
    let slot: Slot
    private let palette: Palette

    /// 氛围场的**亮度带**：没有星球的地方、每一层最浓处、几层叠加处，
    /// 每一格再乘以「压着 / 没压着一条网格线」。
    /// 同一段文字压在带的两端会得到两个对比度 —— 按最差的那一格算。
    private let band: [RGB]

    init(theme: AppTheme, slot: Slot) {
        self.theme = theme
        self.slot = slot
        self.palette = .of(theme)

        let backdrop = Self.rgb(palette.ramp(for: .backdrop).value(slot))
        let grid = Self.rgb(palette.ramp(for: .gridLine).value(slot))
        let lead = Self.rgb(palette.ramp(for: .auraLead).value(slot))
        var trail = Self.rgb(palette.ramp(for: .auraTrail).value(slot))
        let deep = Self.rgb(palette.ramp(for: .auraDeep).value(slot))

        // 球体的最亮一格也只画 token 的 72%（见 AuroraOrb.sphere）。
        // 这里缩放实际 alpha，避免把并不存在的满强度 trail 当成背景。
        trail.a *= 0.72

        // 网格画在光晕**下面**（`AmbientBackdrop` 就是这个顺序），
        // 所以先把「压着一条网格线」的底算出来，再按星球的绘制顺序合成：
        // 外晕 deep → 球体 / 环外波纹 trail → 粒子 / 能量环 lead。
        var band: [RGB] = []
        for base in [backdrop, Self.over(grid, backdrop)] {
            band.append(base)
            band.append(Self.over(deep, base))
            band.append(Self.over(trail, base))
            band.append(Self.over(lead, base))
            band.append(Self.over(trail, Self.over(deep, base)))
            band.append(Self.over(lead, Self.over(deep, base)))
            band.append(Self.over(lead, Self.over(trail, base)))
            band.append(Self.over(lead, Self.over(trail, Self.over(deep, base))))
        }
        // 玻璃面上那道斜光（`Theme.Line.sheen`）压在正文底下，所以它进合成链。
        // 峰值取渐变最浓的那一端：`rimSpecular` × 0.16，和 `Glass.swift` 里一致。
        let spec = palette.ramp(for: .rimSpecular).value(slot)
        var sheen = Self.rgb(spec)
        sheen.a *= 0.16
        self.band = band + band.map { Self.over(sheen, $0) }
    }

    // MARK: - 取色

    /// 一个槽位在当前主题 / 外观下的原始色（不合成）。
    func flat(_ token: ColorToken) -> RGB {
        Self.rgb(palette.ramp(for: token).value(slot))
    }

    /// 一块底上的每一处取样。
    func samples(of surface: Surface) -> [RGB] {
        switch surface {
        case .field: band
        // 读写面是不透明的（下面有测试盯着这件事），所以它只有一格。
        case .well: [flat(.well)]
        }
    }

    /// 一族彩色图标的某个角色在当前主题 / 外观下的色值。
    func icon(_ tint: IconTint, _ role: IconRole) -> RGB {
        Self.rgb(tint.ramp(role, in: palette).value(slot))
    }

    // MARK: - 最差格

    /// 一个文字色压在**所有**底、**整条**亮度带上，最差的那一格。
    func worstSurface(for text: ColorToken) -> (Surface, Double) {
        worstSurface(forInk: flat(text))
    }

    func worstSurface(forInk ink: RGB) -> (Surface, Double) {
        var worst = (Surface.field, Double.infinity)
        for surface in Surface.allCases {
            for sample in samples(of: surface) {
                let ratio = contrast(ink, sample)
                if ratio < worst.1 { worst = (surface, ratio) }
            }
        }
        return worst
    }

    /// 色调文字压在**同色调的浅底**上，而那块浅底压在两块底上。
    ///
    /// 徽章的底现在是**上了色的玻璃**（`tone.soft` 当 tint），不再是一层
    /// 自己画的半透明色。这里仍然按简单 alpha 合成来算 —— 它是个近似，
    /// 而且是**偏保守**的那一侧：系统玻璃会把底往中间调拉，
    /// 拉完之后文字和底的差只会比这里算出来的更大，不会更小。
    func worstToneFill(tint: ColorToken, soft: ColorToken) -> Double {
        worstToneFill(ink: flat(tint), fill: flat(soft))
    }

    func worstToneFill(ink: RGB, fill: RGB) -> Double {
        var worst = Double.infinity
        for surface in Surface.allCases {
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
    static func over(_ src: RGB, _ dst: RGB) -> RGB {
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
    /// 会被拿来放正文的色。三级文字不在里面 —— 它单独测。
    static let bodyLevelText: [ColorToken] = [
        .ink, .inkSecondary, .accent, .info, .success, .danger,
    ]

    /// 色调文字和它自己的浅底。
    static let tonePairs: [(ColorToken, ColorToken)] = [
        (.accent, .accentSoft), (.info, .infoSoft),
        (.success, .successSoft), (.danger, .dangerSoft),
    ]

    /// 气氛层：光晕和网格。增强对比度下**全部归零** —— 气氛不该挡路。
    ///
    /// 上一版这个名单里还有两道高光、控件上那道斜光、宝石那三层和辉光。
    /// 它们不是被放宽了，是**不存在了** —— 那些效果现在由系统材质提供，
    /// 它自己会在增强对比度下让位。名单短了六项，因为要守的东西少了六项。
    static let ambientWashes: [ColorToken] = [
        .auraLead, .auraTrail, .auraDeep, .gridLine,
    ]
}
