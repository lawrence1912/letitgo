import Foundation

/// 侧边栏的顶层分区。加一个 case，侧边栏和详情区会自动跟着长出来
/// —— `DetailView` 里的 switch 是穷尽的，编译器会提醒你补上。
public enum SidebarItem: String, CaseIterable, Identifiable, Hashable, Sendable {
    case overview
    case items
    case activity

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .overview: "概览"
        case .items: "条目"
        case .activity: "活动"
        }
    }

    public var systemImage: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .items: "list.bullet"
        case .activity: "clock.arrow.circlepath"
        }
    }
}
