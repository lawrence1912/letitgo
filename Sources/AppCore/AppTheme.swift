/// 主题：整套色板换一遍，不动外观（浅 / 深）。
///
/// 两件正交的事，别混：
///
/// - **外观**（`Appearance`）是「浅色还是深色」，跟随系统或用户指定。
/// - **主题**（`AppTheme`）是「哪一套色板」。每套主题自己给四种外观
///   （浅 / 深 / 增强对比度浅 / 深）各备一组值，所以换主题不影响外观选择，
///   反之亦然。
///
/// 加新主题：在这里加一个 case，再去 `DesignSystem/Palettes/` 填一套色板 ——
/// 那边的 switch 是穷尽的，漏填编译不过。对比度有测试兜着
/// （`Tests/DesignSystemTests`），填错了跑测试就会红。
public enum AppTheme: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    /// 莫兰迪：暖灰打底，陶土 / 雾霾蓝 / 鼠尾草 / 干玫瑰。
    case morandi
    /// 雾青：蓝灰打底，青 / 蓝 / 绿 / 红，同样是降饱和那一档。
    case mist
    /// 素白：中性灰打底，强调色是石墨 —— 蓝 / 绿 / 红是全屏仅有的颜色。
    case plain

    /// UserDefaults 的键。视图侧统一写 `@AppStorage(AppTheme.storageKey)`，
    /// 不要各处硬编码字符串。
    public static let storageKey = "appTheme"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .morandi: "莫兰迪"
        case .mist: "雾青"
        case .plain: "素白"
        }
    }

    /// 设置里那行说明。说的是**这套色板长什么样**，不是形容词堆砌。
    public var subtitle: String {
        switch self {
        case .morandi: "暖灰打底，陶土点睛"
        case .mist: "蓝灰打底，青色点睛"
        case .plain: "中性灰打底，石墨点睛"
        }
    }
}
