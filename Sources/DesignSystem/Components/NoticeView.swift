import SwiftUI

/// 一条需要用户读完的提示。
///
/// 和 `EmptyStateView` 的分工：空态是「这里本来就没东西」，提示条是
/// 「有件事你必须知道」——所以它**不截断正文**。一条说不清楚的警告
/// 等于没有警告。
///
/// 画成一块有圆角有描边的卡片，而不是一条通栏的色带：色带是「系统横幅」的
/// 语汇，读起来像应用在替别人传话；卡片是应用自己在说话。
/// 刻意不用左侧色条 —— 那是最偷懒的一种强调，且色条本身不传达任何信息。
public struct NoticeView<Trailing: View>: View {

    public enum Severity: Sendable {
        case info
        case success
        /// 「能用，但结果可能是错的」——比 danger 轻，比 info 重。
        case warning
        case danger

        var tone: Tone {
            switch self {
            case .info: .info
            case .success: .success
            case .warning: .accent
            case .danger: .danger
            }
        }

        var systemImage: String {
            switch self {
            case .info: "info.circle.fill"
            case .success: "checkmark.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .danger: "xmark.octagon.fill"
            }
        }

        /// VoiceOver 得听得出严重程度，光靠颜色和图标形状不够。
        var spokenPrefix: String {
            switch self {
            case .info: "提示"
            case .success: "已就绪"
            case .warning: "警告"
            case .danger: "错误"
            }
        }
    }

    private let severity: Severity
    private let title: String
    private let message: String?
    private let trailing: Trailing

    public init(
        _ severity: Severity,
        title: String,
        message: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.severity = severity
        self.title = title
        self.message = message
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: severity.systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(severity.tone.tint)
                // 和标题那一行对齐，而不是和整块内容的顶边对齐。
                .frame(height: 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(Theme.Typo.headline)
                    .foregroundStyle(Theme.Ink.primary)

                if let message {
                    Text(message)
                        .font(Theme.Typo.body)
                        .foregroundStyle(Theme.Ink.secondary)
                        // 这里**不要**加 `.fixedSize(horizontal: false, vertical: true)`。
                        //
                        // 那是「让多行文字别被截断」的常见写法，但在
                        // `NavigationSplitView` 的详情区里它会炸：SwiftUI 会拿
                        // 一个还没定下来的宽度去算高度，这段话能把自己撑到
                        // 一千多点高，于是整个窗口的内容上下溢出 —— 侧边栏、
                        // 状态条、底部操作栏统统被顶出可视区，界面看着像是
                        // 「没画出来」，而 AX 树里它们全都在（还带着屏幕外的坐标）。
                        //
                        // 不加就对了：`Text` 本来就会换行，父级给了宽度就够。
                }
            }
            // 文本列自己吃掉剩余宽度，**不要**在它后面放 Spacer。
            //
            // 放了会炸：Spacer 会把宽度抢光，文本列被挤成一条窄缝，而
            // `.fixedSize(vertical: true)` 的语义是「高度按内容给够」——
            // 于是这段话为了在那条缝里放下，把自己撑到一千多点高，
            // 整个窗口的内容跟着上下溢出，界面看着像是「没画出来」。
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softFill(severity.tone)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(severity.spokenPrefix)：\(title)")
    }
}

extension NoticeView where Trailing == EmptyView {
    public init(_ severity: Severity, title: String, message: String? = nil) {
        self.init(severity, title: title, message: message) { EmptyView() }
    }
}
