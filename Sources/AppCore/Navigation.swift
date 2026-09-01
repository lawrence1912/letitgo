import Foundation

/// 侧边栏的顶层分区。加一个 case，侧边栏和详情区会自动跟着长出来
/// —— `DetailView` 里的 switch 是穷尽的，编译器会提醒你补上。
public enum SidebarItem: String, CaseIterable, Identifiable, Hashable, Sendable {
    case overview
    case items
    case activity
    case codec
    case timestamp
    case hash
    case random
    case json
    case jwt
    case rsa

    public var id: String { rawValue }

    /// 侧边栏里的分组。四个分区的时候不需要它，七个就需要了 ——
    /// 一列拉平的七项读起来是一堆并列的名词，看不出「哪几个是一类的」。
    ///
    /// 分组只是**视觉上的**：⌘1–7、Tab、VoiceOver 的遍历顺序仍然按
    /// `allCases` 一条线走，不受分组影响。
    public var group: SidebarGroup {
        switch self {
        case .overview, .items, .activity: .workspace
        case .codec, .timestamp, .hash, .random, .json, .jwt, .rsa: .tools
        }
    }

    public var title: String {
        switch self {
        case .overview: "概览"
        case .items: "备忘"
        case .activity: "活动"
        case .codec: "编解码"
        case .timestamp: "时间戳"
        case .hash: "哈希"
        case .random: "随机串"
        case .json: "JSON"
        case .jwt: "JWT"
        case .rsa: "RSA"
        }
    }

    /// 一句话说明这个分区是干什么的。显示在详情区标题下面 ——
    /// 一个装着好几个工具的外壳里，用户切过来第一眼要看的就是这行。
    public var subtitle: String {
        switch self {
        case .overview: "点开一个分区，或者按它卡片上的快捷键"
        case .items: "卡片式的备忘：标题、正文、时间，写完就落盘"
        case .activity: "操作历史与时间线"
        case .codec: "Base64 / URL / 十六进制，编码与解码"
        case .timestamp: "epoch 时间戳与日期互转，秒毫秒自动判断"
        case .hash: "MD5 / SHA-1 / SHA-256 / SHA-512"
        case .random: "密码 / 密钥 / 测试数据，一次给 10 个，字符集和长度可选"
        case .json: "格式化 / 压缩 / 转成 Java 字面量，坏在哪儿会指出来"
        case .jwt: "拆开看 header 与 payload，过期没过期一眼看到"
        case .rsa: "生成密钥对、加解密。收 Java 那边的 PEM 格式"
        }
    }

    /// 这个分区是不是还只是块留白。
    ///
    /// 留白不是待办（见 PRODUCT.md）—— 它证明这个壳能装下更多东西。
    /// 但概览的快速入口**不列留白**：一张点进去只有「功能还没接」的卡片
    /// 不是入口，是死路。
    public var isPlaceholder: Bool {
        switch self {
        case .activity: true
        case .overview, .items, .codec, .timestamp, .hash, .random,
             .json, .jwt, .rsa: false
        }
    }

    /// 「显示」菜单里的 ⌘1–⌘9，也显示在概览的卡片上。
    ///
    /// **编号只发给能用的分区** —— 留白分区不占号，把有限的九个位置
    /// 留给真能干活的东西。
    ///
    /// 第 10 个（能用的）分区开始就没有快捷键了：编号只有一位，
    /// `Character("10")` 会在运行时直接崩。菜单和概览读的是同一个值，
    /// 所以两边不会对不上。
    public var shortcutNumber: Int? {
        guard !isPlaceholder else { return nil }
        let numbered = Self.allCases.filter { !$0.isPlaceholder }
        guard let index = numbered.firstIndex(of: self), index < 9 else { return nil }
        return index + 1
    }

    /// 概览上摊开的入口：能真的用的分区，且不包括概览自己。
    public static var quickLaunch: [SidebarItem] {
        allCases.filter { $0 != .overview && !$0.isPlaceholder }
    }

    /// 这个分区的图标色。
    ///
    /// 和 `systemImage` 一样是**表现**，不是领域概念 —— 但它和标题、图标一样
    /// 属于「这个分区长什么样」，放在一起才不会散。具体色值由当前主题决定
    /// （见 DesignSystem 的 `IconTint`），这里只说它属于哪一族。
    ///
    /// 分配是**写死的**，不是按下标算的：按下标算的话，中间插一个分区
    /// 后面所有颜色都会跟着挪一位 —— 用户刚记住「紫色那个是编解码」就没了。
    public var tint: IconTint {
        switch self {
        case .overview, .activity: .neutral
        case .items: .blue
        case .codec: .violet
        case .timestamp: .green
        case .hash: .rose
        case .random: .teal
        case .json: .indigo
        case .jwt: .plum
        case .rsa: .lime
        }
    }

    public var systemImage: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .items: "note.text"
        case .activity: "clock.arrow.circlepath"
        case .codec: "arrow.left.arrow.right"
        case .timestamp: "calendar.badge.clock"
        case .hash: "number"
        case .random: "dice"
        case .json: "curlybraces"
        case .jwt: "key.horizontal"
        case .rsa: "lock.shield"
        }
    }
}

/// 图标色的色族。
///
/// 只说「哪一族」，不说具体色值 —— 每套主题自己决定这族在它的色环上落在哪儿，
/// 所以换主题时彩色图标跟着一起换，不会出现一套莫兰迪配色里插着一块荧光蓝。
///
/// 十族，其中 `neutral` 是不上色的那一档（留白分区用它）。
public enum IconTint: String, CaseIterable, Identifiable, Hashable, Sendable {
    case neutral
    case warm
    case rose
    case violet
    case blue
    case teal
    case green
    case indigo
    case plum
    case lime

    public var id: String { rawValue }
}

/// 侧边栏的分组。加分区时顺手归个类，别让列表一直往下拉平。
public enum SidebarGroup: String, CaseIterable, Identifiable, Hashable, Sendable {
    case workspace
    case tools

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .workspace: "工作区"
        case .tools: "工具"
        }
    }

    public var items: [SidebarItem] {
        SidebarItem.allCases.filter { $0.group == self }
    }
}
