import Foundation

/// 数据访问契约。AppCore 只定义协议，具体实现放在 Persistence，
/// 这样领域层不依赖任何存储技术（SwiftData / GRDB / 文件 / 远端 API 都能换）。
///
/// 协议本身是 `Sendable` 且方法都是 `async`，实现方可以安全地做成 `actor`。
public protocol ItemRepository: Sendable {
    func fetchAll() async throws -> [Item]
    func insert(_ item: Item) async throws
    /// 覆盖已经存在的一条。id 不存在时抛 `AppError.notFound`。
    ///
    /// 为什么不复用 `insert`：`insert` 是 upsert，往一条已经被删掉的待办上打勾
    /// 会让它**原地复活**。打勾改的是既有的东西，找不到就该报错。
    func update(_ item: Item) async throws
    func delete(id: Item.ID) async throws
}

/// 什么都不做的实现，用作 SwiftUI Preview / Environment 的默认值，
/// 避免在没有注入依赖时直接崩溃。
public struct EmptyItemRepository: ItemRepository {
    public init() {}
    public func fetchAll() async throws -> [Item] { [] }
    public func insert(_ item: Item) async throws {}
    public func update(_ item: Item) async throws {}
    public func delete(id: Item.ID) async throws {}
}
