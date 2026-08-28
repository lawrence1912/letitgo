import SwiftUI

/// 设计令牌。所有间距 / 圆角 / 语义色都从这里取，不要在视图里写魔数，
/// 之后要整体调风格只改这一个文件。
public enum Theme {

    // MARK: - 间距

    public enum Spacing {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 40
    }

    // MARK: - 圆角

    public enum Radius {
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 10
        public static let lg: CGFloat = 16
    }

    // MARK: - 语义色
    //
    // 全部基于系统色，自动跟随浅色 / 深色外观和用户的强调色设置。
    // 需要品牌色时，在这里换成自己的 Color，视图层不用动。

    public enum Palette {
        public static let accent = Color.accentColor
        public static let label = Color.primary
        public static let secondaryLabel = Color.secondary
        public static let separator = Color(nsColor: .separatorColor)
        public static let surface = Color(nsColor: .controlBackgroundColor)
        public static let background = Color(nsColor: .windowBackgroundColor)
        public static let danger = Color.red
    }

    // MARK: - 尺寸

    public enum Size {
        public static let sidebarMinWidth: CGFloat = 180
        public static let sidebarIdealWidth: CGFloat = 220
        public static let detailMinWidth: CGFloat = 420
        public static let windowMinHeight: CGFloat = 420
        public static let statusBarHeight: CGFloat = 28
    }
}
