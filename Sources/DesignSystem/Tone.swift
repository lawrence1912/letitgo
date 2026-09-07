import SwiftUI

/// 语义色调。徽章、提示条、状态点共用同一套取色，
/// 所以「成功」在应用里任何地方都是同一个绿，不会一处一个样。
///
/// 每个色调给三个值：`tint`（文字 / 图标）、`soft`（填充）、`softBorder`（描边）。
/// 三个一起用才有实体感 —— 只有浅底没有描边的色块在深色外观下会糊掉。
///
/// `soft` 现在的身份是**玻璃的 tint**（见 `GlassTone.semantic`）：一枚徽章
/// 和它旁边的按钮是同一种材质，只是上了色。`softBorder` 留给玻璃管不着的
/// 那几处 —— 拖放高亮的容器边、需要读出来的分隔。
///
/// `tint` 是实色，永远不靠玻璃提供对比度：四种外观下压在氛围场上都不低于 4.5:1，
/// 有测试兜着（`Tests/DesignSystemTests`）。
public enum Tone: Sendable, Hashable, CaseIterable {
    /// 不带情绪的信息。走中性色阶，不占用品牌色。
    case neutral
    /// 主操作、进行中。
    case accent
    case info
    case success
    case danger

    @MainActor
    public var tint: Color {
        switch self {
        case .neutral: Theme.Ink.secondary
        case .accent: Theme.Brand.accent
        case .info: Theme.Brand.info
        case .success: Theme.Brand.success
        case .danger: Theme.Brand.danger
        }
    }

    @MainActor
    public var soft: Color {
        switch self {
        case .neutral: Theme.Fill.hover
        case .accent: Theme.Brand.accentSoft
        case .info: Theme.Brand.infoSoft
        case .success: Theme.Brand.successSoft
        case .danger: Theme.Brand.dangerSoft
        }
    }

    @MainActor
    public var softBorder: Color {
        switch self {
        case .neutral: Theme.Line.hairline
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
