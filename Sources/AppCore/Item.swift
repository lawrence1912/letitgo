import Foundation

/// 一条备忘：标题、正文、写下的时间。三样都直接出现在卡片上，
/// 模型里没有「只给程序看」的字段。
///
/// 正文允许为空 —— 「买牛奶」这种一行就说完的备忘不该被逼着再写一段。
/// 也不替用户折行、不截断：多行怎么排是他自己的事，卡片只负责显示得下几行。
public struct Item: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var title: String
    /// 正文。可以是空串。
    public var content: String
    /// 写下的时间。卡片页脚显示的就是它。
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        content: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
    }

    /// 手写解码，只为了让 `content` 能缺席。
    ///
    /// 合成的 `Codable` 碰上老的 items.json（那会儿还没有正文）会抛
    /// `keyNotFound`，而 `FileItemRepository` 把任何解码失败都翻译成
    /// 「读不了 items.json」—— 加一个新字段就会让用户之前写的**全部**内容
    /// 一起消失在一个错误态后面。字段缺席的意思是「没有正文」，不是「文件坏了」。
    ///
    /// 编码那一侧照旧走合成实现：写出去的永远是带 `content` 的新格式。
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}
