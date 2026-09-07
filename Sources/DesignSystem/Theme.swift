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
    // 又大了一档。小圆角（4–6）是系统控件的语汇，容器用大一点的圆角
    // 才看得出「这是一块面板」而不是「一个没画完的方框」。
    //
    // **玻璃这一档尤其吃圆角。** 系统那层材质的边缘高光是绕着轮廓走的，
    // 而它的方向感只在**弯**的地方读得出来 —— 转角越硬，那圈光就越像
    // 一个方框的四条边，越圆才越像一块有厚度的玻璃被磨过角。
    //
    // 容器和控件在这里分了家：容器走 `md` / `lg`（还是矩形，因为里面装的是
    // 成段的内容），**可点的东西一律走 `pill`**（见 `ActionButtonStyle`）。

    public enum Radius {
        /// 输入框、小色块。
        public static let control: CGFloat = 8
        public static let sm: CGFloat = 10
        /// 面板、卡片、导航项。
        public static let md: CGFloat = 14
        public static let lg: CGFloat = 20
        public static let xl: CGFloat = 26
        /// 胶囊。给足够大的值让 `RoundedRectangle` 退化成 capsule。
        public static let pill: CGFloat = 999
    }

    // MARK: - 文字

    // 三档**全部**读得清。二三档整体提亮过一次：小字压在半透明薄膜上本来就
    // 比压在实色底上吃亏，而之前二档卡着 4.5、三档卡着 3:1 的下限 ——
    // 于是「次要」在屏幕上读成了「发灰」。层次改由**间距**保持：三档之间
    // 各差一档明度，而不是靠把最轻的那一档压到看不清。
    @MainActor
    public enum Ink {
        /// 正文、标题。
        public static var primary: Color { ColorToken.ink.color }
        /// 次级信息：控件标签、计数、说明。四种外观下都 ≥ 7:1。
        public static var secondary: Color { ColorToken.inkSecondary.color }
        /// 最轻的一档：placeholder、单位、⌘ 编号。四种外观下都 ≥ 4.5:1 ——
        /// 它比 `secondary` 轻是为了分层次，不是为了让它读不清。
        public static var tertiary: Color { ColorToken.inkTertiary.color }
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

    @MainActor
    public enum Brand {
        /// 强调色**文字 / 图标**。浅色外观下是深陶土，压在中性表面上够 4.5:1。
        public static var accent: Color { ColorToken.accent.color }
        /// 强调色**实心填充**（主按钮、分段控件的滑块）。比 `accent` 亮得多 ——
        /// 深陶土当底色会读成一块烂泥，「晒褪色的赤陶」才是这个品牌该有的样子。
        public static var accentFill: Color { ColorToken.accentFill.color }
        public static var accentSoft: Color { ColorToken.accentSoft.color }
        public static var accentSoftBorder: Color { ColorToken.accentSoftBorder.color }
        /// 输入框聚焦那一圈实线。比 `accent` 亮一档、浓一档 ——
        /// `accent` 得留给文字，见 `ColorToken.focusRing`。
        public static var focusRing: Color { ColorToken.focusRing.color }

        /// 信息态、拖放高亮。雾霾蓝。
        public static var info: Color { ColorToken.info.color }
        public static var infoSoft: Color { ColorToken.infoSoft.color }
        public static var infoSoftBorder: Color { ColorToken.infoSoftBorder.color }

        /// 成功态。
        public static var success: Color { ColorToken.success.color }
        public static var successSoft: Color { ColorToken.successSoft.color }
        public static var successSoftBorder: Color { ColorToken.successSoftBorder.color }

        /// 失败与破坏性操作。
        public static var danger: Color { ColorToken.danger.color }
        public static var dangerSoft: Color { ColorToken.dangerSoft.color }
        public static var dangerSoftBorder: Color { ColorToken.dangerSoftBorder.color }

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
        /// 入口卡上的名字。比区块标题大一档 —— 一张卡上只有这一行字，
        /// 它就是这张卡的全部内容，不该和区块标题一样重。
        public static let cardTitle = Font.system(size: 18, weight: .semibold)
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
        /// 路径、端口、标识符 —— 夹在别的文字里的短标识，**拿来读的**。
        public static let mono = Font.system(size: 11, design: .monospaced)
        /// 输入框、结果区里的等宽正文 —— **拿来改的**。
        /// 比 `mono` 大一档：那些是扫一眼认出来就行，这里要逐字符落光标，
        /// 11pt 的等宽在 `0/O`、`1/l` 上认得很吃力。
        public static let monoBody = Font.system(size: 13, design: .monospaced)

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
        /// 点击区域的下限；玻璃本体可以更小。
        public static let minimumHitTarget: CGFloat = 44

        /// `TextEditor` 底下那个 `NSTextView` 自带的行内缩进。
        ///
        /// SwiftUI 既不给改也不把它算进 `.padding()` 里：首字形实际落在
        /// `padding + 5` 上，而**光标跟着首字形走**。所以自己叠的 placeholder
        /// 必须手动把这 5pt 补上，否则它会比光标靠左 5pt。
        ///
        /// 量出来的，不是猜的 —— 把 `TextEditor` 塞进 `NSHostingView` 跑一次布局，
        /// 底下那个 `NSTextView` 报的是 `textContainerInset = (0, 0)`、
        /// `lineFragmentPadding = 5`。
        public static let textEditorInlineInset: CGFloat = 5

        /// 侧边栏最窄能拖到多少。**下限是底栏定的**：一个「+」图标按钮（30）
        /// 加一组外观分段（148）加上留白正好 210 —— 拖到比这更窄，
        /// 侧边栏就会开始切掉自己的底栏。分段控件放大之后这个数跟着从 200 抬到 220。
        public static let sidebarMinWidth: CGFloat = 220
        public static let sidebarIdealWidth: CGFloat = 232
        public static let detailMinWidth: CGFloat = 460
        public static let windowMinHeight: CGFloat = 460
        public static let statusBarHeight: CGFloat = 26
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
