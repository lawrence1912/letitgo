import AppKit
import SwiftUI

/// 设计令牌。所有间距 / 圆角 / 颜色 / 字号都从这里取，不要在视图里写魔数，
/// 之后要整体调风格只改这一个文件。
///
/// ## 为什么不用系统语义色
///
/// 早先这里全走 `NSColor` 的语义色（`windowBackgroundColor` / `controlBackgroundColor`…），
/// 省事，但结果就是「一个没人设计过的 AppKit 窗口」——所有分层都是同一档中性灰，
/// 深浅两套外观的层次关系还不一样。
///
/// 现在换成**自己的一套中性色阶**：莫兰迪暖灰（OKLCH 色相 85），四个表面层次
/// （canvas / content / raised / sunken）关系固定，浅深两套外观互为镜像。
/// 暖灰是刻意选的 —— 莫兰迪的底不是中性灰，是掺了土的灰；色相 85 带一点绿黄，
/// 比色相 60 的米黄少一点甜，不至于滑进「暖白米色」那个烂大街的选择。
///
/// 代价是要自己保证对比度和三种外观的适配，所以：
///
/// - 每个色都写成 `Ramp`，**四种外观各给一组 OKLCH**（浅 / 深 / 增强对比度浅 / 深），
///   由 `NSColor(name:dynamicProvider:)` 在运行时按当前外观挑。视图层只写
///   `Theme.Ink.primary`，切外观时它自己变。
/// - 色值用 OKLCH 而不是十六进制：同一个 L 在不同色相下看起来一样亮，
///   调色阶时改一个数就行。转换在 `OKLCH.srgb` 里，30 行。
/// - 对比度是**算过的**，不是估的：正文级别四种外观全部 ≥ 4.5:1，
///   增强对比度那两组 ≥ 7:1。改色值请重新算。
public enum Theme {

    // MARK: - 间距

    public enum Spacing {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 40
    }

    // MARK: - 圆角
    //
    // 比原来大一档。小圆角（4–6）是系统控件的语汇，容器用大一点的圆角
    // 才看得出「这是一块面板」而不是「一个没画完的方框」。

    public enum Radius {
        /// 控件：按钮、输入框、小徽章。
        public static let control: CGFloat = 7
        public static let sm: CGFloat = 8
        /// 面板、卡片、导航项。
        public static let md: CGFloat = 11
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 22
        /// 胶囊。给足够大的值让 `RoundedRectangle` 退化成 capsule。
        public static let pill: CGFloat = 999
    }

    // MARK: - 表面
    //
    // 四层，关系固定，浅深互为镜像：
    //
    //   canvas   ← 应用外壳（侧边栏、底栏）。比内容区暗一档。
    //   content  ← 主工作区。
    //   raised   ← 浮在 content 上的东西（行、卡片、面板）。
    //   sunken   ← 陷进去的东西（输入框、空的拖放区、分段控件的槽）。
    //
    // 「外壳比内容暗一档」是现代应用的通用分层（Xcode / Linear / VS Code 都这样），
    // 它让侧边栏自己成为一块区域，而不是和内容区糊成一片。
    //
    // **这四个现在是实心替身，不是日常画界面用的东西。** 表面换成了玻璃
    // （`GlassLevel` / `Theme.Glass`，见 Glass.swift）：半透明薄膜压在氛围底上，
    // 逐层合成。这套实心色阶留着，是因为系统辅助功能里的「减弱透明度」
    // 一开，玻璃要整套让位换成它 —— 一比一对应，层次关系一模一样。
    //
    // 视图里写背景请用 `.glassBackground(_:)` / `.panel(_:)`，不要直接取这几个色。

    public enum Surface {
        public static let canvas = ColorToken.canvas.color
        public static let content = ColorToken.content.color
        public static let raised = ColorToken.raised.color
        public static let sunken = ColorToken.sunken.color
        /// 悬停填充。只用于可点的东西。
        public static let hover = ColorToken.hover.color
        /// 发丝分割线 / 容器描边。
        public static let border = ColorToken.border.color
        /// 需要读出来的边界（聚焦、选中的容器）。
        public static let borderStrong = ColorToken.borderStrong.color
        /// 卡片投影。深色外观下更重 —— 深色背景上的淡投影等于没有。
        public static let shadow = ColorToken.shadow.color
    }

    // MARK: - 文字

    public enum Ink {
        /// 正文、标题。
        public static let primary = ColorToken.ink.color
        /// 次级信息。四种外观下都 ≥ 4.5:1，可以放正文。
        public static let secondary = ColorToken.inkSecondary.color
        /// 装饰性 / 大号文字专用（≥ 3:1）。**不要拿它放正文。**
        public static let tertiary = ColorToken.inkTertiary.color
    }

    // MARK: - 品牌色
    //
    // 四个角色沿用上一版网页工具（主操作 / 信息 / 成功 / 失败），
    // 但**色相和饱和度都换过了**：莫兰迪就是降饱和 + 往灰里挪，
    // 保住原色相等于没换色系。陶土 62 / 雾霾蓝 238 / 鼠尾草 150 / 干玫瑰 25，
    // chroma 全部压到 0.05 上下 —— 只有 danger 留了一半（0.105），
    // **一个被调进壁纸里的警报不是警报**。
    //
    // 用量守 Restrained：强调色只出现在主操作、当前选中、状态指示上，
    // 不做装饰、不做分区底色。降饱和之后这条更好守：`accentFill` 是全屏
    // 唯一允许比周围响一档的东西。

    public enum Brand {
        /// 强调色**文字 / 图标**。浅色外观下是深陶土，压在中性表面上够 4.5:1。
        public static let accent = ColorToken.accent.color
        /// 强调色**实心填充**（主按钮、分段控件的滑块）。比 `accent` 亮得多 ——
        /// 深陶土当底色会读成一块烂泥，「晒褪色的赤陶」才是这个品牌该有的样子。
        /// 配 `onAccent` 的近黑文字，四种外观下都 ≥ 7:1。
        public static let accentFill = ColorToken.accentFill.color
        public static let accentSoft = ColorToken.accentSoft.color
        public static let accentSoftBorder = ColorToken.accentSoftBorder.color
        /// 压在 `accentFill` 上的文字色。**不能写死白色** ——
        /// 陶土填充在两种外观下都是亮色，白字压上去只有 2 点几比一。
        public static let onAccent = ColorToken.onAccent.color

        /// 信息态、拖放高亮。雾霾蓝。
        public static let info = ColorToken.info.color
        public static let infoSoft = ColorToken.infoSoft.color
        public static let infoSoftBorder = ColorToken.infoSoftBorder.color

        /// 成功态。
        public static let success = ColorToken.success.color
        public static let successSoft = ColorToken.successSoft.color
        public static let successSoftBorder = ColorToken.successSoftBorder.color

        /// 失败与破坏性操作。
        public static let danger = ColorToken.danger.color
        public static let dangerSoft = ColorToken.dangerSoft.color
        public static let dangerSoftBorder = ColorToken.dangerSoftBorder.color

        /// 旧名。新代码写 `accent`。
        public static let brand = accent
    }

    // MARK: - 排版
    //
    // 系统字体一个家族，靠字重和字号拉层次，不引第二个字体 —— 产品 UI 不需要
    // 标题体 / 正文体配对。字号写死不做流体缩放：桌面 DPI 固定，缩放只会更难读。
    //
    // 比例 1.15 左右，比 SwiftUI 默认的语义字号密。标题带负字距 ——
    // 系统字体在 15pt 以上默认字距偏松，收一点才像「排过版」。

    public enum Typo {
        /// 页面标题。
        public static let display = Font.system(size: 19, weight: .semibold)
        /// 区块标题、空态标题。
        public static let title = Font.system(size: 15, weight: .semibold)
        /// 强调正文（提示条标题、行主文案）。
        public static let headline = Font.system(size: 13, weight: .semibold)
        /// 正文。
        public static let body = Font.system(size: 13)
        /// 控件文字：按钮、徽章、导航项。
        public static let label = Font.system(size: 12, weight: .medium)
        /// 次级说明。
        public static let caption = Font.system(size: 11)
        /// 计数、大小、时间 —— 等宽数字，对齐比好看重要。
        public static let numeric = Font.system(size: 12, weight: .medium).monospacedDigit()
        /// 路径、端口、标识符。
        public static let mono = Font.system(size: 11, design: .monospaced)

        /// 标题的字距收紧值。配合 `.tracking()` 用。
        public static let displayTracking: CGFloat = -0.3
        public static let titleTracking: CGFloat = -0.2
    }

    // MARK: - 动效
    //
    // 只表达状态变化，150–250ms。没有入场编排，没有滚动揭示。
    // 全部走 `Theme.Motion.x(reduceMotion:)` —— 减弱动态时返回 nil（直接切换），
    // SwiftUI 不会替你做这件事。

    public enum Motion {
        /// 悬停、按下这类即时反馈。
        public static func fast(reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : .easeOut(duration: 0.14)
        }

        /// 常规状态切换。
        public static func base(reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : .easeOut(duration: 0.2)
        }

        /// 位置变化（选中滑块、布局重排）。弹簧，但不回弹过冲。
        public static func spring(reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86)
        }
    }

    // MARK: - 尺寸

    public enum Size {
        public static let sidebarMinWidth: CGFloat = 200
        public static let sidebarIdealWidth: CGFloat = 232
        public static let detailMinWidth: CGFloat = 460
        public static let windowMinHeight: CGFloat = 460
        public static let statusBarHeight: CGFloat = 26
        /// 详情区顶部标题栏。
        public static let headerHeight: CGFloat = 52
        /// 无标题栏窗口里红绿灯占掉的高度，侧边栏顶部要给它让位。
        public static let trafficLightInset: CGFloat = 28
    }
}


// MARK: - OKLCH

/// 一个 OKLCH 颜色。写色板用它而不是十六进制：同一个 L 在不同色相下
/// 看起来一样亮，调色阶时只改一个数，不用逐通道试。
public struct OKLCH: Sendable, Hashable {
    public let l: Double
    public let c: Double
    public let h: Double
    public let alpha: Double

    public init(_ l: Double, _ c: Double, _ h: Double, alpha: Double = 1) {
        self.l = l
        self.c = c
        self.h = h
        self.alpha = alpha
    }

    /// OKLCH → 线性 LMS → 线性 sRGB → gamma 编码的 sRGB。
    /// 超出色域的通道直接夹到 [0,1]（本色板里的值都在色域内，夹取不会触发）。
    var srgb: (red: Double, green: Double, blue: Double) {
        let radians = h * .pi / 180
        let a = c * cos(radians)
        let b = c * sin(radians)

        let lp = l + 0.3963377774 * a + 0.2158037573 * b
        let mp = l - 0.1055613458 * a - 0.0638541728 * b
        let sp = l - 0.0894841775 * a - 1.2914855480 * b

        let lc = lp * lp * lp
        let mc = mp * mp * mp
        let sc = sp * sp * sp

        let r = 4.0767416621 * lc - 3.3077115913 * mc + 0.2309699292 * sc
        let g = -1.2684380046 * lc + 2.6097574011 * mc - 0.3413193965 * sc
        let bl = -0.0041960863 * lc - 0.7034186147 * mc + 1.7076147010 * sc

        func encode(_ value: Double) -> Double {
            let v = min(1, max(0, value))
            return v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1 / 2.4) - 0.055
        }
        return (encode(r), encode(g), encode(bl))
    }
}


// MARK: - 色阶

/// 一个语义色在四种外观下的四组取值。
///
/// 它只是数据 —— 「哪个槽位取哪条 Ramp」由当前主题（`Palette`）决定，
/// 「取四组里的哪一组」由当前外观决定，两件事都在**绘制时**才发生。
struct Ramp: Sendable {
    let light: OKLCH
    let dark: OKLCH
    let lightHC: OKLCH
    let darkHC: OKLCH

    /// 增强对比度那两档不给时，退回普通浅 / 深色。
    init(light: OKLCH, dark: OKLCH, lightHC: OKLCH? = nil, darkHC: OKLCH? = nil) {
        self.light = light
        self.dark = dark
        self.lightHC = lightHC ?? light
        self.darkHC = darkHC ?? dark
    }

    /// 按外观挑一组值。`NSColor(name:dynamicProvider:)` 会在**每次绘制时**调到这里，
    /// 所以视图层拿到的 `Color` 是活的：用户切浅深色、开增强对比度、换主题，
    /// 界面自己就变了，一行代码都不用改。
    func nsColor(for appearance: NSAppearance) -> NSColor {
        let match = appearance.bestMatch(from: [
            .aqua,
            .darkAqua,
            .accessibilityHighContrastAqua,
            .accessibilityHighContrastDarkAqua,
        ])
        let token: OKLCH = switch match {
        case .darkAqua: dark
        case .accessibilityHighContrastAqua: lightHC
        case .accessibilityHighContrastDarkAqua: darkHC
        default: light
        }
        let (r, g, b) = token.srgb
        return NSColor(srgbRed: r, green: g, blue: b, alpha: token.alpha)
    }
}
