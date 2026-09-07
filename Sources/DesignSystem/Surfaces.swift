import SwiftUI

// 长文本用稳定的读写底色，玻璃留给导航与短控件。
// 同一块读写面也用于减弱透明度和增强对比度，避免背景纹理影响逐字阅读。
extension View {

    /// 输入和结果共用的稳定底色。边界保持安静，焦点单独表达。
    public func readingSurface(radius: CGFloat = Theme.Radius.control) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background(Theme.Surface.well, in: shape)
            .overlay { shape.strokeBorder(Theme.Line.hairline, lineWidth: 1) }
    }

    /// 一个**能打字**的地方：`TextField` / `TextEditor` / `SecureField`。
    ///
    /// 和 `readingSurface()` 同一块底，多一个焦点环：一屏可能有三四个输入框，
    /// 「光标在哪儿」必须一眼看到。底越淡，这圈环越要紧 ——
    /// 它现在是「这个框在等你打字」唯一的信号。
    ///
    /// 只读的结果框走 `readingSurface()`：那些不接受输入，不该长出一个焦点环。
    public func field(focused: Bool, radius: CGFloat = Theme.Radius.control) -> some View {
        modifier(FieldSurface(focused: focused, radius: radius))
    }

    /// 一块带色调的浅底：徽章、提示条、状态胶囊。
    ///
    /// 走的是**上了色的玻璃**（`GlassTone.semantic`），不是一块半透明的颜色 ——
    /// 这样一枚徽章和它旁边的按钮是同一种材质，只是响度不同。
    public func softFill(
        _ tone: Tone,
        radius: CGFloat = Theme.Radius.md
    ) -> some View {
        glassPanel(.semantic(tone), radius: radius)
    }

    /// 一张**大卡**的底：概览的入口墙、工具页上成块的内容面板。
    ///
    /// ## 大卡不该是玻璃
    ///
    /// 试过给它上 `glassEffect`，出来是**一排深色方块**；再往上堆高光，
    /// 出来是**一排塑料糖豆**。两条路都不对，因为前提就错了：
    ///
    /// **玻璃是给控件和导航的**（小、短、会被按，光学反馈是交互的一部分）。
    /// 一张大卡是**内容的容器**，它的活儿是**沉下去、把注意力让给里面的字**。
    /// 一块会折射的大面积表面正好反着来。
    ///
    /// 所以大卡走「烟熏」这一档：系统材质 + 一层压沉的幕 + 一道几乎看不见的斜光
    /// + 一圈跟着它自己的辨识色的细边 + 一道有位移的投影。
    /// 分层靠的是**投影和边**，不是靠让表面自己发亮。
    ///
    /// - Parameters:
    ///   - accent: 这张卡自己的辨识色（分区图标色）。只用在那圈细边和
    ///     斜光的尾巴上 —— 卡面本身不上色。
    public func smokedCard(
        accent: Color,
        radius: CGFloat = Theme.Radius.lg,
        isHovered: Bool = false,
        isFocused: Bool = false
    ) -> some View {
        modifier(SmokedCard(accent: accent, radius: radius, isHovered: isHovered, isFocused: isFocused))
    }

    /// 一块**装内容的烟熏面**：工具页的整块工作区、空态、分组标签。
    ///
    /// ## 它是为了让氛围底能放亮才存在的
    ///
    /// 量过参考图：它的 hero 区有 21.5% 的像素亮于 0.02，我们只有 3.0%。
    /// 而我们放不亮的原因不是材质，是**文字直接压在氛围场上** ——
    /// 场最亮的一格到 L 0.036 时三级文字就只剩 6.1:1，再亮就破 4.5 的线。
    ///
    /// 参考图敢那么亮，是因为**它的文字从不压在光上**：侧边栏和底部面板
    /// 都比我们的场还黑，光全在没有文字的区域。
    ///
    /// 所以规矩改成一条：**正文一律待在面上，氛围场只负责发光。**
    /// 这块面就是那个「面」—— 比 `smokedCard` 轻（不投影、不吃 accent），
    /// 因为它是装内容的底，不是一个可点的物件。
    public func smokedPanel(radius: CGFloat = Theme.Radius.lg) -> some View {
        modifier(SmokedPanel(radius: radius))
    }

    /// 参考图的静态玻璃表现：暗色顶面、下沿厚度、局部亮边和内衬边。
    /// 光照强调轮廓，长文本仍使用 readingSurface。
    public func referenceGlassPanel(
        accent: Color,
        radius: CGFloat = Theme.Radius.lg,
        isHovered: Bool = false,
        isFocused: Bool = false,
        textured: Bool = false,
        textureKey: String = ""
    ) -> some View {
        modifier(ReferenceGlassPanel(
            accent: accent, radius: radius, isHovered: isHovered,
            isFocused: isFocused, textured: textured, textureKey: textureKey
        ))
    }

    /// 贴边的发丝分割线。用它代替 `Divider()` —— `Divider` 走系统 separator 色，
    /// 混在这套色阶里会突然亮一条。
    public func hairline(_ edge: Edge) -> some View {
        overlay(alignment: edge.hairlineAlignment) {
            Rectangle()
                .fill(Theme.Line.hairline)
                .frame(
                    width: edge == .leading || edge == .trailing ? 1 : nil,
                    height: edge == .top || edge == .bottom ? 1 : nil
                )
        }
    }
}

/// `smokedPanel()` 的实现。
private struct SmokedPanel: ViewModifier {
    let radius: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    if reduceTransparency {
                        shape.fill(Theme.Surface.well)
                    } else {
                        shape.fill(.ultraThinMaterial)
                        // 幕比 `smokedCard` 还厚一点：这块面底下是**放亮过的**
                        // 氛围场，而它上面躺的是成段的正文。
                        shape.fill(Theme.Surface.well.opacity(0.84))
                    }
                    shape.fill(Theme.Line.sheen)
                }
            }
            .overlay { shape.strokeBorder(Theme.Line.hairline, lineWidth: 1) }
    }
}

/// 双主题液态玻璃：原生 clear 材质、固定光向的倒角与弯曲光带。
private struct ReferenceGlassPanel: ViewModifier {
    let accent: Color
    let radius: CGFloat
    let isHovered: Bool
    let isFocused: Bool
    let textured: Bool
    let textureKey: String

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var enabled
    @State private var pointer: CGPoint?

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
    // 稳定标识只改变光带曲率，不随重排或重启变化。
    private var seed: UInt64 {
        textureKey.utf8.reduce(14_695_981_039_346_656_037) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
    }
    private var opaque: Bool { reduceTransparency || contrast == .increased }
    private var rim: LinearGradient {
        LinearGradient(stops: [
            .init(color: .white.opacity(isHovered ? 1 : (scheme == .dark ? 0.85 : 0.95)), location: 0),
            .init(color: .cyan.opacity(0.25), location: 0.30),
            .init(color: accent.opacity(0.10), location: 0.5),
            .init(color: Color.purple.opacity(0.48), location: 0.8),
            .init(color: (seed % 3 == 0 ? Color.orange : Color.blue).opacity(0.40), location: 1),
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    if opaque {
                        shape.fill(Theme.Surface.well)
                    } else {
                        shape.fill(.clear)
                            .glassEffect(.clear.tint(scheme == .dark ? Color(red: 0.035, green: 0.085, blue: 0.22).opacity(0.22) : .white.opacity(0.12)), in: shape)
                        shape.fill(LinearGradient(
                            colors: [scheme == .dark ? Color(red: 0.05, green: 0.14, blue: 0.32).opacity(0.18) : .white.opacity(0.18), accent.opacity(0.025)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        GeometryReader { proxy in
                            let point = reduceMotion ? nil : pointer
                            shape.fill(RadialGradient(
                                colors: [.white.opacity(scheme == .dark ? 0.045 : 0.12), .clear],
                                center: UnitPoint(x: (point?.x ?? 24) / max(proxy.size.width, 1),
                                                  y: (point?.y ?? 8) / max(proxy.size.height, 1)),
                                startRadius: 0, endRadius: 120
                            ))
                        }
                    }
                }
                .shadow(color: .black.opacity(scheme == .dark ? 0.30 : 0.08), radius: 8, y: textured ? 5 : 2)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .overlay {
                ZStack {
                    if opaque {
                        shape.strokeBorder(Theme.Line.strong, lineWidth: 1.5)
                    } else {
                        shape.strokeBorder(rim, lineWidth: 1)
                        shape.inset(by: textured ? 3 : 2).strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.28), .clear, .cyan.opacity(0.24), .purple.opacity(0.25)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.7
                        )
                        if textured {
                            LiquidCaustics(seed: seed)
                                .offset(x: reduceMotion ? 0 : min(max(((pointer?.x ?? 80) - 80) / 80, -1.5), 1.5))
                                .clipShape(shape)
                        }
                    }
                    if isFocused {
                        shape.strokeBorder(Theme.Brand.focusRing, lineWidth: 1.5)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .background(alignment: .bottom) {
                if textured && !opaque {
                    Capsule().fill(LinearGradient(colors: [.cyan.opacity(0.32), .purple.opacity(0.20), .clear],
                                                   startPoint: .leading, endPoint: .trailing))
                        .frame(height: 3).padding(.horizontal, radius)
                        .blur(radius: 4).offset(y: 3)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .onContinuousHover { phase in
                guard textured && enabled && !reduceMotion && !opaque else { pointer = nil; return }
                switch phase {
                case .active(let location): pointer = location
                case .ended: pointer = nil
                }
            }
            .transaction { $0.animation = nil }
    }
}

/// `smokedCard()` 的实现。
private struct SmokedCard: ViewModifier {
    let accent: Color
    let radius: CGFloat
    let isHovered: Bool
    let isFocused: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    if reduceTransparency {
                        shape.fill(Theme.Surface.well)
                    } else {
                        shape.fill(.ultraThinMaterial)
                        // 压沉的那一层。走 `Surface.well` 而不是写死的黑 ——
                        // 这套界面浅深两套外观都在用，一层黑幕在浅色下是个洞。
                        shape.fill(Theme.Surface.well.opacity(isHovered ? 0.68 : 0.78))
                    }
                    shape.fill(
                        LinearGradient(
                            colors: [
                                Theme.Line.specular.opacity(0.07),
                                .clear,
                                accent.opacity(0.035),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
            }
            .overlay {
                // 悬停时边亮一档，聚焦时整圈换成焦点色。
                // **这两件事分开** —— 「鼠标在上面」和「键盘停在这儿」不是一回事。
                shape.strokeBorder(
                    isFocused ? Theme.Brand.focusRing : accent.opacity(isHovered ? 0.58 : 0.34),
                    lineWidth: isFocused ? 1.5 : 1
                )
            }
            // 投影是这张卡浮起来的**唯一**证据（它自己不发亮），所以位移不能省。
            .shadow(
                color: .black.opacity(0.34),
                radius: isHovered && !reduceMotion ? 18 : 14,
                y: isHovered && !reduceMotion ? 11 : 8
            )
    }
}

/// `field()` 的实现。单独拆出来是为了读 `accessibilityReduceMotion` ——
/// 修饰符函数里拿不到 `@Environment`。
private struct FieldSurface: ViewModifier {
    let focused: Bool
    let radius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .readingSurface(radius: radius)
            .overlay {
                if focused {
                    shape.strokeBorder(Theme.Brand.focusRing, lineWidth: 1.5)
                }
            }
            .animation(Theme.Motion.fast(reduceMotion: reduceMotion), value: focused)
    }
}

extension Edge {
    var hairlineAlignment: Alignment {
        switch self {
        case .top: .top
        case .bottom: .bottom
        case .leading: .leading
        case .trailing: .trailing
        }
    }
}
