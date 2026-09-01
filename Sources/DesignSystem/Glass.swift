import AppKit
import SwiftUI

// MARK: - 玻璃
//
// 这套界面的表面不再是实心色块，而是**压在一层氛围底上的半透明薄膜**。
// 一块面板的最终颜色 = 氛围底 → 下面每一层薄膜 → 它自己，逐层合成出来的。
//
// ## 为什么模糊的是自己画的东西，不是桌面
//
// 「毛玻璃」在 macOS 上最抢眼的做法是 `behindWindow` 混合 —— 直接把桌面壁纸
// 卷进来。这里**没有**这么做，原因只有一个：壁纸是用户的，亮度随时会变，
// 压在上面的正文就没法算对比度了。算过：浅色外观下把一张黑壁纸垫在
// 半透明表面后面，次级文字会从 6.6:1 掉到 2.7:1 —— 而要把它救回 4.5:1，
// 薄膜得浓到 0.8 以上，那时候「玻璃」已经不透了，白折腾一场。
//
// 所以底下垫的是应用自己画的一层氛围底（`AmbientBackdrop`），亮度带是已知的，
// 模糊一律走 `withinWindow`（只模糊窗口内自己画的东西）。代价是看不见壁纸，
// 换来的是**四种外观下的对比度仍然是算出来的**，和换风格之前一样。
//
// ## 三件套，缺一件就不像玻璃
//
//   1. **薄膜**：半透明着色层，让下面的氛围底透上来。只有这个 → 像蒙了层雾。
//   2. **边缘高光**：左上亮、右下淡的一圈发丝描边。玻璃的厚度全靠它 ——
//      少了它，半透明面板会糊在背景里，看不出是「一块」。
//   3. **投影**：柔、散、位移小。它说明这块玻璃浮在多高的地方。
//
// ## 减弱透明度时整套让位
//
// 系统辅助功能里的「减弱透明度」一开，薄膜全部换成实心色（`GlassLevel.opaque`），
// 模糊层不创建。增强对比度那两档外观走的是同一条路 —— 薄膜的 alpha 直接是 1。
// 玻璃是第一个该让位的东西。

/// 玻璃层级。决定薄膜多浓、要不要真模糊、边缘怎么画、投不投影。
public enum GlassLevel: Sendable, Hashable, CaseIterable {
    /// 应用外壳：侧边栏、底部操作条。薄膜最薄，氛围底透得最多，所以外壳
    /// 天然比内容区暗一档 —— 和换风格之前的层次关系一样，只是换了实现方式。
    case chrome
    /// **底下有东西在滚**的外壳：页头、状态栏。和 `chrome` 同一档薄膜，
    /// 但多一层真模糊 —— 不加的话，列表的文字会从 34% 的薄膜底下清清楚楚
    /// 透上来，和标题叠成一团。
    case frosted
    /// 主工作区。
    case content
    /// 浮在内容上的面板 / 卡片 / 行。
    case panel
    /// 陷进去的槽：输入框、拖放区、分段控件的底。压暗，不是提亮。
    case well
    /// 真正浮起来的东西：sheet、弹出面板。唯一带大投影的一档。
    case floating

    /// 半透明薄膜。压在下层之上，合成结果由「下面是什么」决定。
    var film: Color {
        switch self {
        case .chrome, .frosted: ColorToken.glassChrome.color
        case .content: ColorToken.glassContent.color
        case .panel: Theme.Glass.panel
        case .well: Theme.Glass.well
        case .floating: ColorToken.glassFloating.color
        }
    }

    /// 减弱透明度时的替身。走的是原来那套实心色阶，一比一对应。
    var opaque: Color {
        switch self {
        case .chrome, .frosted: Theme.Surface.canvas
        case .content: Theme.Surface.content
        case .panel: Theme.Surface.raised
        case .well: Theme.Surface.sunken
        case .floating: Theme.Surface.raised
        }
    }

    /// **只有 `frosted` 真模糊。** 别的层底下是一片平滑的氛围底，
    /// 模糊它等于什么都没做 —— 而系统材质本身是半不透明的，垫在那儿只会把
    /// 自己画的氛围底盖掉，玻璃就没东西可透了。侧边栏、面板、浮层都不用。
    var blurs: Bool { self == .frosted }

    /// 材质只提供**模糊**，颜色由上面的薄膜决定 —— 所以挑的是两套外观下
    /// 都跟着窗口底色走的中性材质（`.headerView` 就是系统给工具条 / 页头用的
    /// 那一块），不挑 `.hudWindow` 那种自带强色的：那种会把颜色也一起接管。
    var material: NSVisualEffectView.Material { .headerView }

    /// 边缘高光的浓度。面板和浮层最厚；槽是凹的，没有高光；
    /// 内容区是通栏底，本来就不描边。
    var highlight: Double {
        switch self {
        case .chrome, .frosted: 0.6
        case .content: 0.0
        case .panel: 1.0
        case .well: 0.0
        case .floating: 1.0
        }
    }
}

// MARK: - 令牌

extension Theme {

    /// 玻璃专用令牌。中性色阶（`Theme.Surface`）没有消失 ——
    /// 它现在是「减弱透明度」时的那套替身，日常画界面从这里取。
    public enum Glass {
        /// 氛围底：所有玻璃压在它上面。**不透明**，所以整套合成是确定的。
        public static let backdrop = ColorToken.backdrop.color
        /// 左上那团光晕。氛围底上的一团，给玻璃一点可折射的东西。
        public static let auraLead = ColorToken.auraLead.color
        /// 右下那团。和 `auraLead` 是邻近色，不是补色 —— 前两套主题都守这条；
        /// 素白没有色相可分，两团只剩一提亮一压暗。
        public static let auraTrail = ColorToken.auraTrail.color

        /// 悬停填充。半透明 —— 压在侧边栏、行、按钮上都成立。只用于可点的东西。
        public static let hover = ColorToken.glassHover.color
        /// 面板薄膜。自绘控件（按钮、导航项）自己拼背景时用它，
        /// 拼出来的东西才和 `.panel()` 是同一块玻璃。
        public static let panel = ColorToken.glassPanel.color
        /// 槽薄膜。
        public static let well = ColorToken.glassWell.color

        /// 玻璃的一圈发丝边。半透明 —— 压在哪一层上都能读出边界。
        public static let rim = ColorToken.glassRim.color
        /// 需要读出来的边界（聚焦、拖放高亮的容器）。
        public static let rimStrong = ColorToken.glassRimStrong.color
        /// 左上角那道高光。玻璃的厚度全靠它。
        public static let highlight = ColorToken.glassHighlight.color

        /// 面板投影。比换风格之前更散、位移更小 —— 玻璃是浮着的，不是贴着的。
        public static let shadow = ColorToken.glassShadow.color
        /// 浮层投影。
        public static let shadowFloating = ColorToken.glassShadowFloating.color
    }
}

// MARK: - 模糊层

/// 真模糊。只在 `GlassLevel.blurs` 为真的层上创建。
///
/// `blendingMode` 固定 `.withinWindow`：只模糊**窗口内自己画的东西**。
/// 不用 `.behindWindow` 的理由写在本文件顶部 —— 一句话，桌面壁纸的亮度是用户的，
/// 卷进来之后这套界面的对比度就没法算了。
private struct BackdropBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .withinWindow
        // .followsWindowActiveState 会让窗口失焦时整块玻璃塌下去，
        // 一个装着工具的外壳不该在你去看别的窗口时变个样。
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

// MARK: - 玻璃表面

/// 一层玻璃：模糊（可选）+ 薄膜。不裁剪、不描边、不投影 ——
/// 通栏区域（内容区、侧边栏、页头）用它，圆角面板走 `panel()`。
public struct GlassPane: View {
    private let level: GlassLevel

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(_ level: GlassLevel) {
        self.level = level
    }

    public var body: some View {
        if reduceTransparency {
            level.opaque
        } else {
            ZStack {
                if level.blurs {
                    BackdropBlur(material: level.material)
                }
                level.film
            }
        }
    }
}

extension View {

    /// 一整片玻璃底。通栏区域用它。
    public func glassBackground(_ level: GlassLevel) -> some View {
        background(GlassPane(level))
    }

    /// 边缘高光：左上亮、右下淡的一圈发丝描边，压在最上层。
    ///
    /// 这是玻璃的厚度所在。少了它，半透明面板会糊进背景里 ——
    /// 看得出「这里颜色浅了一点」，看不出「这里有一块东西」。
    func glassRim(
        _ shape: some InsettableShape,
        rim: Color,
        highlight: Double
    ) -> some View {
        overlay {
            shape.strokeBorder(rim, lineWidth: 1)
        }
        .overlay {
            shape.strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: Theme.Glass.highlight.opacity(highlight), location: 0),
                        .init(color: .clear, location: 0.45),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        }
    }
}
