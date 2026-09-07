import SwiftUI

// MARK: - 玻璃
//
// macOS 26 之后，玻璃是**系统的一层光学材质**，不再是自己拼出来的一叠颜色。
// 这个文件因此从七百多行掉到不足两百行 —— 删掉的那些（薄膜、边缘高光、
// 投影、斜光，以及顶面高光 / 底缘聚光 / 色散边那一套「宝石」）
// 全部是在**模仿**一件系统现在自己会做的事。
//
// ## 为什么模仿再准也只是模仿
//
// 自己画的「玻璃」是一层**贴在屏幕上的颜色**：它不知道背后是什么，
// 所以它不会折射，边缘不会随着背后的亮暗改变浓度，挪动窗口时它纹丝不动。
// 上一版靠三件事去补：薄膜的浓度差、有方向的发丝边、位移很小的投影 ——
// 补得挺像，但它补的是「看上去像玻璃」，不是「是玻璃」。
//
// `glassEffect` 是后者：它**采样背后的内容**，把它弯折、聚焦、按亮度自适应
// 前景色。所以同一块面板压在星球的亮环上和压在暗处，出来是两种边缘，
// 而这件事没有任何一组静态色值写得出来。
//
// ## 代价：对比度不再是「算出来的」
//
// 上一版有一整套合成测试，把「氛围底 → 每一层薄膜 → 文字」逐层算一遍。
// 那套算法的前提是**每一层都是我们自己画的**，现在这个前提没了：
// 系统材质怎么混，我们既不知道也不该假设。
//
// 换来的是系统自己在保证这件事（Liquid Glass 会按背后的内容调前景），
// 而我们守住**还归自己管**的那部分：
//
//   - 玻璃底下垫什么（`Theme.Field`，见下面「氛围场」一节）——
//     这是唯一还能算的一层，测试仍然算它。
//   - 正文永远是实色，永远不上渐变，永远不靠玻璃提供对比度。
//   - tint 只表达**响度**，不表达装饰。
//
// ## 一条硬规矩：玻璃底下必须有东西
//
// 一块玻璃背后什么都没有的时候，它出来就是一块灰板 —— 因为它折射的是虚空。
// 所以 `AmbientBackdrop` 不是装饰，它是这套材质的**前提**：
// 星球、外晕和那层细网格给玻璃提供了可折射的起伏和可对齐的规律。
// 移动窗口、滚动内容时看得出层次，靠的就是它。
//
// ## 什么东西不该是玻璃
//
// 上一条反过来还有一半：**会动的背景是给 chrome 用的，不是给正文用的。**
//
// 一段等宽代码压在一片会折射的东西上是读不下去的 —— 每挪一下窗口，
// 字底下的亮度就变一次。所以这套界面里有一块表面**刻意不上玻璃**：
// `Theme.Surface.well`，代码框、结果区、长文本躺的那块地。
//
// 分工是这么划的：
//
// | | 材质 | 为什么 |
// |---|---|---|
// | 窗口 chrome、工具栏、边栏 | 系统玻璃 | 它们浮在内容上，要让人看出「底下还有东西」 |
// | 控件、徽章、卡片 | 系统玻璃 | 小、短、可点，折射是反馈的一部分 |
// | 代码框、结果区、长文本 | `Surface.well` | 拿来读和改的东西，底下不能动 |
//
// 判断标准不是「这块大不大」，是**「这上面的字要读多久」**。

// MARK: - 氛围场

extension Theme {

    /// 玻璃**背后**那一层。所有玻璃折射的都是它。
    ///
    /// 它是不透明的、自己画的，所以亮度带是已知的 ——
    /// 这是整套界面里唯一还能把对比度算准的一层，也是唯一需要算的一层。
    ///
    /// 刻意**不用** `.behindWindow` 把桌面壁纸卷进来：壁纸是用户的，
    /// 亮度随时会变，卷进来之后连这一层也没法算了。
    @MainActor
    public enum Field {
        /// 氛围底。不透明。
        public static var backdrop: Color { ColorToken.backdrop.color }
        /// 能量星球的发光环。
        public static var auraLead: Color { ColorToken.auraLead.color }
        /// 星球的暗球体。和 `auraLead` 是邻近色，不是补色。
        public static var auraTrail: Color { ColorToken.auraTrail.color }
        /// 星球的外晕；不需要第三层的主题把它设为全透明。
        public static var auraDeep: Color { ColorToken.auraDeep.color }
        /// 氛围底上那层细网格 —— 玻璃底下的「规律」。
        public static var grid: Color { ColorToken.gridLine.color }
    }

    /// 玻璃**管不着**的那几件事。
    ///
    /// 分割线、自绘行的悬停底、需要**读出来**的边界（拖放高亮、聚焦的输入框），
    /// 以及玻璃那圈**镜面边**。
    ///
    /// ## 关于那圈边，改过一次口
    ///
    /// 这里原来写着「系统玻璃自带边缘，不要再描一圈」。那句话对了一半：
    /// 再描一圈**同性质**的边确实只会让边变粗。
    ///
    /// 但系统那圈边是为 OS chrome 调的 —— 它要的是克制，压在深色氛围场上几乎读不出来，
    /// 一屏卡片因此读成一排深色方块，而不是一排玻璃。
    ///
    /// 补的这一圈**不是同一件事**：它是有方向的**镜面高光**（左上冷白 → 右下色散），
    /// 说的是「光落在这块玻璃的棱上」，而系统那圈说的是「这里有个边界」。
    /// 两件事叠在一起不冲突 —— 现实里的玻璃也是既有轮廓又有高光。
    ///
    /// 它便宜也是有原因的：**1px 的边不进对比度合成链**（正文压不到边上），
    /// 所以它可以比任何一个面都亮，而不用还任何东西。
    /// 这条是上一版就验证过的，那时候它是唯一的玻璃感来源；
    /// 现在它退回成配角，但仍然是最划算的那一层。
    @MainActor
    public enum Line {
        /// 发丝分割线。
        public static var hairline: Color { ColorToken.border.color }
        /// 需要读出来的边界。
        public static var strong: Color { ColorToken.borderStrong.color }

        /// 一块玻璃的边：左上是**光**（冷白），右下是**色**（主题自己的色）。
        ///
        /// 中间那两段是全透明的 —— 一圈粗细均匀的亮边读成的是「描了个框」，
        /// 只有两头亮、中间断，才读成「光落在这块玻璃的两条棱上」。
        ///
        /// 方向永远是左上 → 右下，和星球的光源同一个角。每块玻璃各挑一个角度的话，
        /// 一屏上的光就来自四面八方 —— 那不是设计，是没对齐。
        /// 玻璃**表面**那道斜光：左上一小片冷白，很快化掉。
        ///
        /// 它和 `rim` 是一对：`rim` 说「光落在棱上」，这道说「光扫过面上」。
        /// 只有棱没有面的话，一块玻璃读成的是一个描了亮边的深色方块。
        ///
        /// **它进对比度合成链**（正文压在它上面），所以浓度只有边的零头 ——
        /// 边可以到 0.85，这里 0.07。棱和面的预算不是一回事。
        ///
        /// 这个数是从 0.16 收下来的：0.16 那一版把卡片和按钮洗成了**塑料糖豆** ——
        /// 一层看得见的白洗 在表面上，读成的是「这块东西是白的」，
        /// 不是「有光扫过它」。光该是**察觉不到的一层**，只在余光里说明有个光源。
        static var sheen: LinearGradient {
            LinearGradient(
                stops: [
                    .init(color: ColorToken.rimSpecular.color.opacity(0.07), location: 0),
                    .init(color: .clear, location: 0.55),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        /// 镜面高光的原色。控件上那道**顶面亮带**（`GlassGloss`）直接取它。
        static var specular: Color { ColorToken.rimSpecular.color }

        static var rim: LinearGradient {
            LinearGradient(
                stops: [
                    .init(color: ColorToken.rimSpecular.color, location: 0),
                    .init(color: ColorToken.rimSpecular.color.opacity(0.12), location: 0.34),
                    .init(color: .clear, location: 0.56),
                    .init(color: ColorToken.rimDispersion.color, location: 1),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @MainActor
    public enum Fill {
        /// 悬停填充。只用于可点的东西。
        public static var hover: Color { ColorToken.hover.color }
    }

    /// **不是**玻璃的那块表面。
    @MainActor
    public enum Surface {
        /// 正文躺着的那块地：代码框、结果区、长文本。
        /// 见上面「什么东西不该是玻璃」。
        public static var well: Color { ColorToken.well.color }
    }
}

// MARK: - 一块玻璃

/// 一块玻璃的**响度**。
///
/// tint 在这套界面里只表达一件事：**这块东西此刻有多重要**。
/// 它不是装饰色，也不是分类色 —— 分类靠图标色（`IconTint`），那是另一回事。
///
/// 规矩没变：**一屏只有一个响亮的东西**。`accent` 留给主操作和当前选中，
/// 语义色只在真的发生了那件事时出现。
/// **这里没有「强调色填充」那一档，而且是故意的。**
/// 一屏最多一个响亮的东西，那个名额属于主操作 —— 而主操作走的是系统的
/// `.glassProminent`（见 `ButtonStyles.swift`），不从这里取色。
/// 「当前选中」比主操作低一档，所以它用的是 `.semantic(.accent)`，
/// 也就是 `accentSoft`：认得出来，但不抢。
public enum GlassTone: Sendable, Hashable {
    /// 不上色。绝大多数容器走这档。
    case plain
    /// 上色。语义色（提示条、徽章、状态）和「当前选中」（`.accent`）都走它。
    case semantic(Tone)

    @MainActor
    var tint: Color? {
        switch self {
        case .plain: nil
        case .semantic(let tone): tone.soft
        }
    }
}

extension View {

    /// 一块玻璃面板：卡片、行、浮层、分组容器。
    ///
    /// **不要再往它身上加描边、渐变或投影。** 那三样都是系统这层材质自己的
    /// 一部分，补上去只会和它打架 —— 一圈自绘的边压在系统的边缘高光上，
    /// 读出来是「描粗了」，不是「更清楚」。
    ///
    /// - Parameters:
    ///   - tone: 响度。默认不上色。
    ///   - radius: 圆角。容器走 `Theme.Radius.md` / `.lg`；
    ///     可点的小东西走 `glassControl()`，那边是胶囊。
    ///   - interactive: 这块玻璃**能不能按**。开了之后系统会给它
    ///     指针和按压的光学反馈（材质自己形变，不是我们做的动画）。
    ///     容器不要开 —— 一张不能点的卡片跟着鼠标闪，是在撒谎。
    public func glassPanel(
        _ tone: GlassTone = .plain,
        radius: CGFloat = Theme.Radius.md,
        interactive: Bool = false
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        // 顺序就是玻璃的剖面：材质在最下，斜光扫在它的面上，内容站在斜光之上，
        // 最后那圈镜面边绕着轮廓走。
        //
        // 斜光走 `.background` 而不是 `.overlay`，就是为了让它落在**内容底下** ——
        // 压在字上面的一层白洗会把正文洗淡，那是给玻璃加光，不是给字减对比度。
        return background { shape.fill(Theme.Line.sheen) }
            .glassEffect(glass(tone, interactive: interactive), in: shape)
            .overlay { shape.strokeBorder(Theme.Line.rim, lineWidth: 1) }
    }


    private func glass(_ tone: GlassTone, interactive: Bool) -> Glass {
        Glass.regular.tint(tone.tint).interactive(interactive)
    }
}

// MARK: - 当前选中

/// 边栏、主题格和待办共用的选中底：浅色调与左侧亮线。
/// 选中切换只改变颜色，避免新增玻璃材质时产生折射跳变。
public struct SelectionSurface: View {
    private let isSelected: Bool
    private let radius: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    public init(isSelected: Bool, radius: CGFloat = Theme.Radius.md) {
        self.isSelected = isSelected
        self.radius = radius
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    public var body: some View {
        if isSelected {
            shape
                .fill(LinearGradient(
                    colors: [Theme.Brand.accentSoft, Theme.Brand.accentSoft.opacity(0.25)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .background {
                    if reduceTransparency || contrast == .increased {
                        shape.fill(Theme.Surface.well)
                    }
                }
                .overlay {
                    shape.strokeBorder(
                        contrast == .increased ? Theme.Brand.focusRing : Theme.Brand.accent.opacity(0.24),
                        lineWidth: 1
                    )
                }
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Theme.Brand.accent)
                        .frame(width: 2)
                        .padding(.vertical, Theme.Spacing.sm)
                }
                .transition(.identity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - 分割线

/// 用自己的色阶画的分割线。SwiftUI 的 `Divider()` 走系统 separator 色，
/// 混在这套色阶里会偏亮 / 偏冷一档。
///
/// 玻璃面板**之间**通常不需要它 —— 两块玻璃自己就分得开。
/// 它是给一块玻璃**内部**分区用的（一张卡片里上下两段内容）。
public struct Hairline: View {
    private let axis: Axis

    public init(_ axis: Axis = .horizontal) {
        self.axis = axis
    }

    public var body: some View {
        Rectangle()
            .fill(Theme.Line.hairline)
            .frame(
                width: axis == .vertical ? 1 : nil,
                height: axis == .horizontal ? 1 : nil
            )
    }
}
