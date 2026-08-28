import Foundation

/// 占位领域模型。真实功能进来时，把这里换成你自己的实体
/// （或拆成多个文件），Repository 协议和 UI 层不需要改结构。
public struct Item: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var title: String
    public var createdAt: Date

    public init(id: UUID = UUID(), title: String, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
    }
}
