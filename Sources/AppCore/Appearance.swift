import Foundation

/// 应用外观。`system` 表示跟随系统设置。
///
/// rawValue 会写进 UserDefaults，**改动等于让老用户的设置失效**，
/// 所以 `AppCoreTests` 里把这三个字符串钉死了。
public enum Appearance: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    case system
    case light
    case dark

    /// UserDefaults 的键。视图侧统一写 `@AppStorage(Appearance.storageKey)`，
    /// 不要各处硬编码字符串。
    public static let storageKey = "appearance"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }

    public var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
}
