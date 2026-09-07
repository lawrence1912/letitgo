import SwiftUI

/// 窗口共享的氛围底。棱镜主题用静态光纹，其他主题保留原有星球。
/// 分栏使用同一窗口坐标，避免接缝处的背景错位；减少透明度和增强对比度时隐藏纹理。
public struct AmbientBackdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.ambientFieldFrame) private var ambientFieldFrame
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    private let showsPlanet: Bool

    public init(showsPlanet: Bool = false) {
        self.showsPlanet = showsPlanet
    }

    public var body: some View {
        GeometryReader { proxy in
            let localFrame = proxy.frame(in: .global)
            let fieldFrame = ambientFieldFrame ?? localFrame

            Theme.Field.backdrop
                .overlay(alignment: .topLeading) {
                    if !reduceTransparency && contrast != .increased {
                        atmosphere(in: fieldFrame.size)
                            .offset(
                                x: fieldFrame.minX - localFrame.minX,
                                y: fieldFrame.minY - localFrame.minY
                            )
                    }
                }
                .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func atmosphere(in size: CGSize) -> some View {
        if PaletteStore.shared.theme == .prism {
            if showsPlanet, let image = Self.resourceBundle.image(forResource: "CausticEnvironment") {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .opacity(colorScheme == .dark ? Self.darkTextureOpacity : Self.lightTextureOpacity)
            }
        } else {
            let diameter = min(max(min(size.width, size.height) * 0.62, 260), 520)
            ZStack(alignment: .topLeading) {
                grid(in: size)
                if showsPlanet {
                    LightFilaments(size: size)
                    AuroraOrb(diameter: diameter)
                        .position(x: size.width * 0.66, y: size.height * 0.52)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
    }

    static let darkTextureOpacity = 0.25
    static let lightTextureOpacity = 0.05

    static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        Bundle.main.resourceURL.flatMap {
            Bundle(url: $0.appendingPathComponent("LetItGo_DesignSystem.bundle"))
        } ?? .module
        #else
        Bundle(for: ResourceMarker.self)
        #endif
    }

    private final class ResourceMarker {}

    /// 一张等距细网格。透明色表示当前主题没有网格。
    private func grid(in size: CGSize) -> some View {
        GridLines(spacing: 40)
            .stroke(Theme.Field.grid, lineWidth: 1)
            .frame(width: size.width, height: size.height)
    }
}

/// 环境里那几缕**不规则的光**。
///
/// ## 为什么需要它：亮度不等于丰富
///
/// 参照图的 hero 区有 21.5% 的像素亮于 0.02，我们只有 3.0%。但**照搬亮度是走不通的** ——
/// 氛围场上还压着文字（工具页那些「N 字符 · N 字节」的说明），
/// 场一放亮它们就先破 4.5:1 的线。
///
/// 而那张图真正比我们多的东西不全是「亮」，是**细节**：
/// 它是一片有走向、有疏密、有断续的光，我们是**几个同心圆**。
/// skill 的原话是「一对模糊的圆只能给出大片的颜色，给不出参照图那种细密的光纹」。
///
/// **细节是免费的** —— 同样的 token 浓度下，一组有方向、粗细不一、时断时续的光丝，
/// 比几个均匀的圆环丰富得多，而它压在文字底下的平均亮度并没有变。
/// 所以这一层不动色板的 alpha，只把**形**做够。
///
/// 光丝的形状是写死的（不是随机的）：随机意味着每次启动都不一样，
/// 而一个背景不该在用户重开应用时变个样。
private struct LightFilaments: View {
    let size: CGSize

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// 每条光丝：起点、三个控制点、粗细、浓度、用哪一档色。
    /// 都按窗口尺寸的比例给，所以缩放窗口时构图不变。
    private static let strokes: [(Double, Double, Double, Double, Double, Double, Double, Double, Bool)] = [
        // (x0, y0, cx1, cy1, cx2, cy2, x1, y1, isLead)
        (0.28, 1.05, 0.42, 0.72, 0.55, 0.46, 0.62, 0.08, true),
        (0.18, 1.02, 0.34, 0.78, 0.44, 0.40, 0.48, -0.04, false),
        (0.44, 1.08, 0.60, 0.74, 0.74, 0.44, 0.80, 0.02, false),
        (0.62, 1.06, 0.78, 0.70, 0.90, 0.38, 0.97, -0.02, true),
        (0.06, 0.96, 0.20, 0.70, 0.26, 0.40, 0.30, 0.06, false),
        (0.78, 1.02, 0.90, 0.72, 1.02, 0.42, 1.08, 0.04, false),
    ]

    var body: some View {
        if !reduceTransparency {
            let lead = Theme.Field.auraLead
            let trail = Theme.Field.auraTrail
            Canvas { context, canvas in
                for (i, s) in Self.strokes.enumerated() {
                    var path = Path()
                    path.move(to: CGPoint(x: s.0 * canvas.width, y: s.1 * canvas.height))
                    path.addCurve(
                        to: CGPoint(x: s.6 * canvas.width, y: s.7 * canvas.height),
                        control1: CGPoint(x: s.2 * canvas.width, y: s.3 * canvas.height),
                        control2: CGPoint(x: s.4 * canvas.width, y: s.5 * canvas.height)
                    )
                    // 一条光丝画两遍：宽而糊的雾 + 细而实的芯。
                    // 只有雾读成一团污渍，只有芯读成一根铁丝 —— 两层才是光。
                    let color = s.8 ? lead : trail
                    let fade = 0.55 + 0.45 * Double((i % 3)) / 2
                    context.stroke(
                        path,
                        with: .color(color.opacity(0.30 * fade)),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    context.stroke(
                        path,
                        with: .color(color.opacity(0.85 * fade)),
                        style: StrokeStyle(lineWidth: 1.1, lineCap: .round)
                    )
                }
            }
            .blur(radius: 2.2)
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
        }
    }
}

/// Shape 会缓存路径，并天然跟随主题的动态网格色。
private struct GridLines: Shape {
    let spacing: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = spacing + 0.5
        while x < rect.maxX {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += spacing
        }

        var y = spacing + 0.5
        while y < rect.maxY {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += spacing
        }
        return path
    }
}

// MARK: - 窗口场

private struct AmbientFieldFrameKey: EnvironmentKey {
    static let defaultValue: CGRect? = nil
}

private extension EnvironmentValues {
    var ambientFieldFrame: CGRect? {
        get { self[AmbientFieldFrameKey.self] }
        set { self[AmbientFieldFrameKey.self] = newValue }
    }
}

private struct AmbientFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { proxy in
            content
                .frame(width: proxy.size.width, height: proxy.size.height)
                .environment(\.ambientFieldFrame, proxy.frame(in: .global))
        }
    }
}

extension View {
    /// 装在窗口根上，一扇窗口只装一次。
    public func ambientField() -> some View {
        modifier(AmbientFieldModifier())
    }
}

extension View {
    /// 给区域垫上氛围底。主窗口的三块区域显式打开星球，
    /// 设置窗口沿用默认值，只显示基底和可选网格。
    public func ambientBackdrop(showsPlanet: Bool = false) -> some View {
        background(AmbientBackdrop(showsPlanet: showsPlanet))
    }
}
