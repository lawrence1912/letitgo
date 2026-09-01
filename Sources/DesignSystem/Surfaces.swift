import SwiftUI

// 表面修饰符。所有「一块面板 / 一条分割线 / 一块浅底」都从这里走，
// 视图里不要再手写 RoundedRectangle + strokeBorder 的组合 ——
// 那样每处的圆角和描边色迟早会跑偏。
//
// 换成玻璃之后这条更要紧了：一块玻璃是**三层**（薄膜 + 边缘高光 + 投影）
// 叠出来的，手写必漏一层，漏哪一层都会让那块面板看着「没做完」。

extension View {

    /// 一块玻璃面板：圆角 + 薄膜（可能带模糊）+ 边缘高光 + 可选投影。
    ///
    /// `level` 决定它浮在多高的地方，颜色是**合成**出来的，不是写死的 ——
    /// 同一块 `.panel()` 压在内容区和压在侧边栏上会自己得到不同的最终色，
    /// 但相对关系（比底下亮一档）始终成立。
    ///
    /// 边缘高光不是装饰。半透明面板压在半透明背景上，只靠明度差**看不出边界**；
    /// 那圈左上亮、右下淡的发丝线就是这块玻璃的厚度。
    public func panel(
        _ level: GlassLevel = .panel,
        radius: CGFloat = Theme.Radius.md,
        rim: Color? = nil,
        elevated: Bool = false
    ) -> some View {
        modifier(PanelSurface(level: level, radius: radius, rim: rim, elevated: elevated))
    }

    /// 一块带色调的浅底（提示条、徽章、选中项）。
    ///
    /// `tone.soft` 也是半透明的 —— 徽章底下的氛围底会透上来，
    /// 所以它压在内容区和压在侧边栏上是两个略微不同的颜色，和玻璃面板一致。
    public func softFill(
        _ tone: Tone,
        radius: CGFloat = Theme.Radius.md,
        bordered: Bool = true
    ) -> some View {
        softFill(
            fill: tone.soft,
            border: bordered ? tone.softBorder : .clear,
            radius: radius
        )
    }

    /// 直接给颜色的版本。语义色调（`Tone`）之外还有一套辨识用的图标色
    /// （`IconTint`），两套走同一段绘制。
    func softFill(fill: Color, border: Color, radius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background(shape.fill(fill))
            .clipShape(shape)
            // 色调块的高光收一半：它已经有颜色在承担「这是一块东西」，
            // 再来一道亮边会让徽章看着像按钮。
            .glassRim(shape, rim: border, highlight: 0.4)
    }

    /// 贴边的发丝分割线。用它代替 `Divider()` —— `Divider` 走系统 separator 色，
    /// 混在这套色阶里会突然亮一条。
    public func hairline(_ edge: Edge) -> some View {
        overlay(alignment: edge.hairlineAlignment) {
            Rectangle()
                .fill(Theme.Glass.rim)
                .frame(
                    width: edge == .leading || edge == .trailing ? 1 : nil,
                    height: edge == .top || edge == .bottom ? 1 : nil
                )
        }
    }
}

/// `panel()` 的实现。单独拆出来是因为要读 `accessibilityReduceTransparency` ——
/// 修饰符函数里拿不到 `@Environment`。
private struct PanelSurface: ViewModifier {
    let level: GlassLevel
    let radius: CGFloat
    let rim: Color?
    let elevated: Bool

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    /// 浮层永远带投影；普通面板只在显式要求时带。
    /// 投影挂在**玻璃层自己**身上（而不是整块视图上）：这样它画在裁剪之外，
    /// 又不会把面板里的文字也描一圈边。
    private var castsShadow: Bool { elevated || level == .floating }

    func body(content: Content) -> some View {
        content
            .background {
                GlassPane(level)
                    .clipShape(shape)
                    .shadow(
                        color: castsShadow
                            ? (level == .floating ? Theme.Glass.shadowFloating : Theme.Glass.shadow)
                            : .clear,
                        radius: castsShadow ? (level == .floating ? 26 : 14) : 0,
                        y: castsShadow ? (level == .floating ? 10 : 4) : 0
                    )
            }
            .clipShape(shape)
            .glassRim(shape, rim: rim ?? Theme.Glass.rim, highlight: level.highlight)
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

/// 用自己的色阶画的分割线。SwiftUI 的 `Divider()` 走系统 separator 色，
/// 混在这套色阶里会偏亮 / 偏冷一档。
public struct Hairline: View {
    private let axis: Axis

    public init(_ axis: Axis = .horizontal) {
        self.axis = axis
    }

    public var body: some View {
        Rectangle()
            .fill(Theme.Glass.rim)
            .frame(
                width: axis == .vertical ? 1 : nil,
                height: axis == .horizontal ? 1 : nil
            )
    }
}
