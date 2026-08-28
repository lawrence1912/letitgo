import AppCore
import Foundation

/// `ItemRepository` 的内存实现。
///
/// 做成 `actor`：并发访问由编译器保证串行化，不需要手写锁。
/// 换成真实存储时只要再写一个实现同一协议的类型，
/// 在 `LetItGo/App/AppDependencies.swift` 里改一行注入即可，
/// 上层视图和 Model 一行都不用动。
public actor InMemoryItemRepository: ItemRepository {
    private var storage: [Item.ID: Item] = [:]

    public init(seed: [Item] = []) {
        self.storage = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    public func fetchAll() async throws -> [Item] {
        storage.values.sorted { $0.createdAt < $1.createdAt }
    }

    public func insert(_ item: Item) async throws {
        storage[item.id] = item
    }

    public func delete(id: Item.ID) async throws {
        guard storage.removeValue(forKey: id) != nil else {
            throw AppError.notFound
        }
    }
}
