import SwiftUI

/// 氛围底：整个窗口最下面那一层，所有玻璃压在它上面。
///
/// ## 它为什么必须存在
///
/// 玻璃需要有东西可折射。压在一片死平的灰色上，半透明和不透明看起来一模一样 ——
/// 「毛玻璃」就退化成「浅一点的灰」。所以底下垫一层有起伏的东西：
/// 一块暖灰灰泥基底，加两团低饱和的光晕（干玫瑰 + 鼠尾草）。
///
/// ## 为什么是自己画的，不是桌面壁纸
///
/// 见 `Glass.swift` 顶部：壁纸的亮度是用户的，卷进来之后正文的对比度就没法算了。
/// 自己画的底是**不透明且已知**的，所以整套合成结果是确定的，四种外观下的
/// 对比度仍然是算出来的。
///
/// ## 光晕是深度，不是装饰
///
/// 饱和度压得很低（峰值 chroma 0.05，且只有 24% 不透明），
/// 扫一眼说不出它是什么颜色，只觉得这一片有厚度。
/// 「品牌色只出现在主操作 / 当前选中 / 状态指示上」那条没有破 ——
/// 光晕在语义上是表面的一部分，不是一块被染色的分区。
///
/// ## 接缝
///
/// 侧边栏和内容区是 `NavigationSplitView` 的两列，各自画一份氛围底
/// （不这么做的话，系统会在侧边栏那一列垫上它自己的 `.sidebar` 材质，
/// 那块材质是**透到桌面**的，前面那套对比度就白算了）。
///
/// 两份之间不会出现缝：光晕的位置按**窗口坐标**算，每份都用
/// `frame(in: .global)` 把自己的原点减掉 —— 画出来正好接得上。
public struct AmbientBackdrop: View {

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin

            Theme.Glass.backdrop
                .overlay(alignment: .topLeading) {
                    if !reduceTransparency {
                        aura.offset(x: -origin.x, y: -origin.y)
                    }
                }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    /// 两团光晕，位置写死在窗口坐标里。
    /// 不跟着窗口尺寸缩放 —— 拉大窗口时光晕留在原地，右下角是干净的基底，
    /// 这比「一团永远跟着你走的渐变」更像一块有固定光源的表面。
    private var aura: some View {
        ZStack(alignment: .topLeading) {
            blob(Theme.Glass.auraLead, diameter: 940)
                .offset(x: -260, y: -320)

            blob(Theme.Glass.auraTrail, diameter: 1000)
                .offset(x: 280, y: 40)
        }
    }

    private func blob(_ color: Color, diameter: CGFloat) -> some View {
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: color, location: 0),
                .init(color: color.opacity(0), location: 1),
            ]),
            center: .center,
            startRadius: 0,
            endRadius: diameter / 2
        )
        .frame(width: diameter, height: diameter)
    }
}

extension View {
    /// 给一整块区域垫上氛围底。窗口级的东西（根视图、设置窗口、sheet）用它。
    public func ambientBackdrop() -> some View {
        background(AmbientBackdrop())
    }
}
