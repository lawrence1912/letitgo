import AppCore
import AppKit
import SwiftUI

// MARK: - 彩色图标
//
// 「品牌色只出现在主操作、当前选中、状态指示上，不做装饰」——
// **这里是那条规矩唯一的例外，而且是有条件的例外。**
//
// 条件是：颜色在这儿承担的是**辨识**，不是装饰。一个装了八个分区的壳，
// 图标全是同一档灰的时候，找「时间戳」只能靠读字；给每个分区一个固定的颜色之后，
// 眼睛可以先按颜色缩小范围再读字。macOS 系统设置就是这么做的 ——
// 那一列彩色图标不是好看，是让你在二十个面板里一眼找到「网络」。
//
// 所以它守着三条：
//
// 1. **色族是写死的**，一个分区永远是那个颜色。随机分配或按下标算的话，
//    「紫色那个是编解码」这条肌肉记忆就建立不起来，颜色就真的只剩装饰了。
// 2. **饱和度跟着主题走**，不自己另开一套。莫兰迪里它们是脏的，雾青里它们是冷的，
//    素白里它们是全屏仅有的颜色（那套主题自己一点色都不上）。
// 3. **不动语义色**。accent / info / success / danger 那四个角色一个没碰 ——
//    一枚红色的图标底板不该让人以为那个分区出错了。

/// 图标色的三件套。和 `Tone` 是一样的结构（tint / soft / softBorder），
/// 但走的是另一套取色：`Tone` 是**语义**（成功、失败），`IconTint` 是**辨识**。
enum IconRole {
    case tint
    case soft
    case softBorder
}

extension IconTint {

    /// 图标本身的颜色。
    public var tint: Color { color(.tint) }
    /// 图标底板。
    public var soft: Color { color(.soft) }
    /// 底板的描边。
    public var softBorder: Color { color(.softBorder) }

    private func color(_ role: IconRole) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            ramp(role, in: PaletteStore.current).nsColor(for: appearance)
        })
    }

    /// 亮度和饱和度是**所有色族共用**的一套（和品牌色那套对齐，所以对比度落在
    /// 同一个位置），色相由当前主题给。这样加一族只要给一个角度，
    /// 不用再抄一遍四种外观的值。
    func ramp(_ role: IconRole, in palette: Palette) -> Ramp {
        let hue = palette.iconHue(self)
        // 中性那一族只留一点点色 —— 它是「这个分区还没上色」的意思，
        // 不是第七种颜色。
        let scale = self == .neutral ? 0.18 : 1.0

        switch role {
        case .tint:
            return Ramp(
                light: OKLCH(0.480, 0.070 * scale, hue),
                dark: OKLCH(0.780, 0.065 * scale, hue),
                lightHC: OKLCH(0.385, 0.082 * scale, hue),
                darkHC: OKLCH(0.865, 0.070 * scale, hue)
            )
        case .soft:
            return Ramp(
                light: OKLCH(0.880, 0.042 * scale, hue, alpha: 0.55),
                dark: OKLCH(0.340, 0.044 * scale, hue, alpha: 0.50),
                lightHC: OKLCH(0.945, 0.028 * scale, hue),
                darkHC: OKLCH(0.270, 0.034 * scale, hue)
            )
        case .softBorder:
            return Ramp(
                light: OKLCH(0.800, 0.050 * scale, hue, alpha: 0.80),
                dark: OKLCH(0.490, 0.046 * scale, hue, alpha: 0.75),
                lightHC: OKLCH(0.740, 0.062 * scale, hue),
                darkHC: OKLCH(0.560, 0.054 * scale, hue)
            )
        }
    }
}
