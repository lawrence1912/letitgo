import SwiftUI

/// 语义色调。徽章、提示条、状态点共用同一套取色，
/// 所以「成功」在应用里任何地方都是同一个绿，不会一处一个样。
///
/// 每个色调给三个值：`tint`（文字 / 图标）、`soft`（填充）、`softBorder`（描边）。
/// 三个一起用才有实体感 —— 只有浅底没有描边的色块在深色外观下会糊掉。
///
/// `soft` / `softBorder` 和别的表面一样是**半透明薄膜**：底下的氛围底会透上来，
/// 所以同一枚徽章压在内容区和压在侧边栏上是两个略微不同的颜色。
/// 对比度按「压在最亮和最暗的那两处」都算过，四种外观下 tint 不低于 4.5:1。
public enum Tone: Sendable, Hashable, CaseIterable {
    /// 不带情绪的信息。走中性色阶，不占用品牌色。
    case neutral
    /// 主操作、进行中。
    case accent
    case info
    case success
    case danger

    public var tint: Color {
        switch self {
        case .neutral: Theme.Ink.secondary
        case .accent: Theme.Brand.accent
        case .info: Theme.Brand.info
        case .success: Theme.Brand.success
        case .danger: Theme.Brand.danger
        }
    }

    public var soft: Color {
        switch self {
        case .neutral: Theme.Glass.panel
        case .accent: Theme.Brand.accentSoft
        case .info: Theme.Brand.infoSoft
        case .success: Theme.Brand.successSoft
        case .danger: Theme.Brand.dangerSoft
        }
    }

    public var softBorder: Color {
        switch self {
        case .neutral: Theme.Glass.rim
        case .accent: Theme.Brand.accentSoftBorder
        case .info: Theme.Brand.infoSoftBorder
        case .success: Theme.Brand.successSoftBorder
        case .danger: Theme.Brand.dangerSoftBorder
        }
    }

    /// VoiceOver 得听得出严重程度 —— 颜色和图标形状对它不存在。
    public var spokenPrefix: String? {
        switch self {
        case .neutral, .accent: nil
        case .info: "提示"
        case .success: "已就绪"
        case .danger: "错误"
        }
    }
}
