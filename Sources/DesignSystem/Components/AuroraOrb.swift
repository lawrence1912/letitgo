import SwiftUI

/// 氛围底里的能量星球：外晕 + 暗球体 + 边缘光 + 环外波纹 + 星光粒子 + 一圈能量环。
///
/// 它只由 `AmbientBackdrop` 放进窗口级坐标系，不直接出现在任何页面的布局里。
/// 所以切换分区时星球留在原地，侧边栏与详情区各自绘制的那一份也能严丝合缝。
///
/// ## 它是一个**光源**，不是一张贴图
///
/// 第一版把这颗星球画成了「几圈线 + 一团雾」：能量环从头到尾一样亮，
/// 球体中心比周围亮一点，外晕淡得几乎不存在。出图之后它读成的是
/// **一组同心圆线框**，不是一颗在发光的球 —— 而一组同心圆压在工作区底下，
/// 除了让人以为界面画错了之外没有任何作用。
///
/// 问题不在浓度，在**光从哪儿来**：环上每一处一样亮，就等于说这里没有光源。
/// 现在整颗星球服从一个方向 —— 光从**左上**打过来（和玻璃的边缘高光、斜光、
/// 投影是同一个光源）：
///
/// | 层 | 画什么 | 说的是 |
/// |---|---|---|
/// | 外晕 | 一团宽而软的 `auraDeep` | 这团东西在往外漏光 |
/// | 波纹 | 环外三道细同心线，分段明暗 | 能量在往外扩散，不是三圈边框 |
/// | 球体 | 中心压到近底色，只在左上留一点 `auraTrail` | 它是个**实心的暗球**，不是一块色斑 |
/// | 边缘光 | 球体左上那道内弧 | 球有体积（光擦着球面过去） |
/// | 能量环 | 左上一道**热弧**，绕回右下衰减到微光 | 光源在左上 |
///
/// 能量环底下垫了一层它自己的模糊副本 —— 那是「亮」和「发亮」的区别：
/// 一条清晰的亮线只是一条线，一条清晰的亮线**外面渗着光**才是在发光。
///
/// ## 亮度是有闸的
///
/// 这颗星球压在整扇窗口底下，前景所有半透明面板都要从它上面经过。
/// 所以这里守一条硬规矩，`Tests/DesignSystemTests` 的亮度带正是按它建模的：
///
/// > **同一档 aura 色在任何一个像素上的实际叠加，不超过它 token 自己的 alpha。**
///
/// 能量环的「模糊层 0.55 + 清晰层 0.45」就是按这条配的：两层叠出来是
/// `a − 0.2475a²`，恒小于 `a`。想让星球更亮，改**色板里的 token**
/// （那样对比度测试会跟着算），不要在这里多叠一层。
public struct AuroraOrb: View {
    @Environment(\.colorScheme) private var colorScheme

    private let diameter: CGFloat

    public init(diameter: CGFloat = 168) {
        self.diameter = diameter
    }

    /// 光源方向。0 = 右，顺时针增加（SwiftUI 的 y 轴朝下）。
    /// 0.62 落在左上 —— 和系统玻璃那圈边缘高光落的是同一个角。
    private static let lightAngle: Double = 0.62

    public var body: some View {
        ZStack {
            halo
            orbitalRipples
            sphere
            limb
            StarlightParticles(diameter: diameter)
            energyRing
        }
        .frame(width: diameter * 1.62, height: diameter * 1.62)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - 外晕

    /// 最外层只负责把星球从平底里托起来，不画第二个实体圆。
    /// 峰值压在环所在的半径上（0.5 一带）而不是圆心 —— 光是从**环**上漏出去的，
    /// 从圆心漏出去的话，暗球体中间会先亮起来，那就成了一颗恒星。
    private var halo: some View {
        Circle()
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: Theme.Field.auraDeep.opacity(0.30), location: 0),
                        .init(color: Theme.Field.auraDeep.opacity(0.72), location: 0.32),
                        .init(color: Theme.Field.auraDeep, location: 0.44),
                        .init(color: Theme.Field.auraDeep.opacity(0.34), location: 0.68),
                        .init(color: .clear, location: 1),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter * 0.81
                )
            )
            .frame(width: diameter * 1.62, height: diameter * 1.62)
    }

    // MARK: - 球体

    /// 中心是一颗**压暗**的球，不是一块发亮的色斑。这一层是整颗星球里唯一
    /// 会被大面积正文压住的部分，所以它必须是暗的 —— 亮的那部分全部收在
    /// 环和边缘光那两条细线上，细线不挡字。
    private var sphere: some View {
        Circle()
            .fill(
                RadialGradient(
                    stops: [
                        // 圆心比氛围底还沉一点：一颗球该有的样子是「这里挡住了背后的光」。
                        .init(color: Theme.Field.backdrop.opacity(0.55), location: 0),
                        .init(color: Theme.Field.auraTrail.opacity(0.30), location: 0.62),
                        .init(color: Theme.Field.auraTrail.opacity(0.62), location: 0.92),
                        .init(color: Theme.Field.auraTrail.opacity(0.34), location: 1),
                    ],
                    // 偏左上：亮的那一侧朝着光源。
                    center: .init(x: 0.38, y: 0.32),
                    startRadius: 0,
                    endRadius: diameter * 0.62
                )
            )
            .frame(width: diameter, height: diameter)
    }

    /// 球体左上那道内弧（limb light）。一条**贴着球面内侧**的亮弧，
    /// 是「这是个球」和「这是个圆」之间的全部区别：圆没有厚度，球有。
    private var limb: some View {
        Circle()
            .strokeBorder(
                AngularGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: Self.lightAngle - 0.20),
                        .init(color: Theme.Field.auraTrail.opacity(0.72), location: Self.lightAngle),
                        .init(color: .clear, location: Self.lightAngle + 0.20),
                        .init(color: .clear, location: 1),
                    ],
                    center: .center
                ),
                lineWidth: max(4, diameter * 0.030)
            )
            .blur(radius: max(3, diameter * 0.018))
            .frame(width: diameter * 0.965, height: diameter * 0.965)
    }

    // MARK: - 能量环

    /// 一圈能量边，**左上最热、绕回右下衰减到微光**。
    ///
    /// 两层：底下一层**宽而糊**的雾，上面一层**细而实**的核。
    ///
    /// 关键在两层用的是**不同的 token**：核是 `auraLead`（近白，满强度），
    /// 雾是 `auraDeep`（那团靛紫的外晕色）。这不是为了好看 ——
    ///
    /// - 同一档色叠两层的话，两层的强度得分着用（`a − ka²` 那笔账），
    ///   核最多只能拿到 token 的七成。而**核是这颗星球上唯一真正在发光的东西**，
    ///   把它的亮度分一半给雾，出来的就是一圈发灰的胖环：
    ///   一条糊的亮线读成的是雾，不是光。
    /// - 换成两个 token 之后，核可以拿满 `auraLead`，雾走 `auraDeep` ——
    ///   而「lead 叠在 deep 上」本来就是亮度带里已经建模的一格
    ///   （见 `Composite.band`），一格都不用新开。
    ///
    /// 顺带它在物理上也更对：发光体的核心偏白，**颜色在它周围的光晕里**。
    private var energyRing: some View {
        let width = max(3, diameter * 0.013)
        return ZStack {
            Circle()
                .strokeBorder(ringGradient(Theme.Field.auraDeep, 1.0), lineWidth: width * 5.0)
                .blur(radius: width * 2.8)
            Circle()
                .strokeBorder(ringGradient(Theme.Field.auraLead, 1.0), lineWidth: width)
        }
        .frame(width: diameter, height: diameter)
    }

    /// 一道热弧。**不回到全透明** —— 留一档底光（0.18），否则环在背光那侧
    /// 会断掉，读成一段孤零零的弧而不是一整圈环。
    private func ringGradient(_ color: Color, _ strength: Double) -> AngularGradient {
        AngularGradient(
            stops: [
                .init(color: color.opacity(strength * 0.18), location: 0),
                .init(color: color.opacity(strength * 0.22), location: Self.lightAngle - 0.42),
                .init(color: color.opacity(strength * 0.68), location: Self.lightAngle - 0.16),
                .init(color: color.opacity(strength), location: Self.lightAngle),
                .init(color: color.opacity(strength * 0.60), location: Self.lightAngle + 0.15),
                .init(color: color.opacity(strength * 0.24), location: Self.lightAngle + 0.34),
                .init(color: color.opacity(strength * 0.18), location: 1),
            ],
            center: .center
        )
    }

    // MARK: - 波纹

    /// 三道从能量环向外扩散的同心波纹。分段明暗让它们读成能量扩散，
    /// 而不是三圈新的容器边框；每一道都跟着同一个光源转，
    /// 所以最亮的一段永远在左上。
    private var orbitalRipples: some View {
        ZStack {
            ripple(scale: 1.13, strength: 1.00)
            ripple(scale: 1.32, strength: 0.70)
            ripple(scale: 1.52, strength: 0.46)
        }
    }

    private func ripple(scale: CGFloat, strength: Double) -> some View {
        ZStack {
            Circle()
                .stroke(
                    rippleGradient(color: Theme.Field.auraTrail, strength: strength * 0.62),
                    style: StrokeStyle(lineWidth: rippleLineWidth * 3.0, lineCap: .round)
                )
                .blur(radius: rippleLineWidth * 1.2)

            Circle()
                .stroke(
                    rippleGradient(color: Theme.Field.auraLead, strength: strength * 0.72),
                    style: StrokeStyle(lineWidth: rippleLineWidth, lineCap: .round)
                )
        }
        .frame(width: diameter * scale, height: diameter * scale)
    }

    private func rippleGradient(color: Color, strength: Double) -> AngularGradient {
        AngularGradient(
            stops: [
                .init(color: color.opacity(strength * 0.10), location: 0),
                .init(color: .clear, location: max(0, AuroraOrb.lightAngle - 0.46)),
                .init(color: color.opacity(strength * 0.52), location: AuroraOrb.lightAngle - 0.22),
                .init(color: color.opacity(strength), location: AuroraOrb.lightAngle),
                .init(color: color.opacity(strength * 0.44), location: AuroraOrb.lightAngle + 0.18),
                .init(color: .clear, location: min(1, AuroraOrb.lightAngle + 0.33)),
                .init(color: color.opacity(strength * 0.10), location: 1),
            ],
            center: .center
        )
    }

    /// 浅色背景的色差更小，所以线比深色下粗一点。
    private var rippleLineWidth: CGFloat {
        let minimum: CGFloat = colorScheme == .light ? 2.0 : 1.6
        let ratio: CGFloat = colorScheme == .light ? 0.0052 : 0.0042
        return max(minimum, diameter * ratio)
    }
}

/// 固定在星球外围的稀疏星光。Canvas 一次绘制，避免为每颗粒子建立视图。
private struct StarlightParticles: View {
    @Environment(\.colorScheme) private var colorScheme

    let diameter: CGFloat

    private static let particles: [(x: CGFloat, y: CGFloat, radius: CGFloat)] = [
        (0.10, 0.25, 0.0055), (0.22, 0.10, 0.0035),
        (0.39, 0.06, 0.0028), (0.63, 0.07, 0.0044),
        (0.80, 0.14, 0.0032), (0.92, 0.30, 0.0050),
        (0.95, 0.51, 0.0031), (0.89, 0.69, 0.0040),
        (0.78, 0.86, 0.0052), (0.58, 0.94, 0.0030),
        (0.36, 0.92, 0.0044), (0.18, 0.83, 0.0030),
        (0.07, 0.65, 0.0050), (0.06, 0.45, 0.0028),
        (0.26, 0.23, 0.0027), (0.75, 0.24, 0.0032),
        (0.77, 0.77, 0.0028), (0.23, 0.74, 0.0037),
        (0.14, 0.39, 0.0030), (0.16, 0.59, 0.0042),
        (0.32, 0.16, 0.0036), (0.51, 0.13, 0.0029),
        (0.69, 0.18, 0.0040), (0.85, 0.40, 0.0031),
        (0.83, 0.61, 0.0045), (0.66, 0.83, 0.0033),
    ]

    var body: some View {
        let deep = Theme.Field.auraDeep
        let trail = Theme.Field.auraTrail
        let lead = Theme.Field.auraLead
        Canvas { context, size in
            let sizeBoost: CGFloat = colorScheme == .light ? 1.58 : 1.32
            let minimumRadius: CGFloat = colorScheme == .light ? 1.25 : 1.0
            let glowOpacity = colorScheme == .light ? 0.55 : 0.38

            for particle in Self.particles {
                let center = CGPoint(x: size.width * particle.x, y: size.height * particle.y)
                let radius = max(minimumRadius, diameter * particle.radius * sizeBoost)

                var glow = Path()
                glow.addEllipse(in: CGRect(
                    x: center.x - radius * 3.2,
                    y: center.y - radius * 3.2,
                    width: radius * 6.4,
                    height: radius * 6.4
                ))
                context.fill(glow, with: .color(deep.opacity(glowOpacity)))

                var core = Path()
                if particle.radius >= 0.0036 {
                    let arm = radius * 2.2
                    let waist = max(0.55, radius * 0.42)
                    core.move(to: CGPoint(x: center.x, y: center.y - arm))
                    core.addLine(to: CGPoint(x: center.x + waist, y: center.y - waist))
                    core.addLine(to: CGPoint(x: center.x + arm, y: center.y))
                    core.addLine(to: CGPoint(x: center.x + waist, y: center.y + waist))
                    core.addLine(to: CGPoint(x: center.x, y: center.y + arm))
                    core.addLine(to: CGPoint(x: center.x - waist, y: center.y + waist))
                    core.addLine(to: CGPoint(x: center.x - arm, y: center.y))
                    core.addLine(to: CGPoint(x: center.x - waist, y: center.y - waist))
                    core.closeSubpath()
                } else {
                    core.addEllipse(in: CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    ))
                }
                context.fill(core, with: .color(trail))

                let lightRadius = radius * 0.70
                var light = Path()
                light.addEllipse(in: CGRect(
                    x: center.x - lightRadius,
                    y: center.y - lightRadius,
                    width: lightRadius * 2,
                    height: lightRadius * 2
                ))
                context.fill(light, with: .color(lead))
            }
        }
        .frame(width: diameter * 1.62, height: diameter * 1.62)
        .saturation(colorScheme == .light ? 1.40 : 1.20)
        .brightness(colorScheme == .light ? -0.08 : 0.035)
    }
}
