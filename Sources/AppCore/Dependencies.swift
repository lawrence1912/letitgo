import Foundation

/// 依赖容器：把「副作用」集中成一组可替换的值。
///
/// 做成 `Sendable` 的 struct 而不是单例，好处是测试和 Preview 里
/// 可以直接换掉某一项，不用碰全局状态。新增依赖就在这里加一个字段。
public struct Dependencies: Sendable {
    public var items: any ItemRepository

    /// 时间也当依赖注入 —— 测试里可以钉死在某个时刻。
    public var now: @Sendable () -> Date

    public init(
        items: any ItemRepository,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.items = items
        self.now = now
    }
}

extension Dependencies {
    /// Preview / 默认值用的空实现：不崩溃，也不产生任何数据。
    public static let preview = Dependencies(items: EmptyItemRepository())
}
