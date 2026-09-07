import Foundation

/// 一条待办：要做的那件事、做完没做完、写下的时间。
///
/// **没有标题。** 待办说的就是那件事本身 ——「买牛奶」三个字既是标题也是正文，
/// 逼用户分两栏填，只会让他在写之前先纠结这三个字该放哪儿。一条待办一段文本，
/// 加一条只要打字 + 回车。
///
/// 文本可以是多行的（粘一段进来就是一条），行怎么排是用户的事，不替他折行、
/// 也不截断 —— 截断是列表版面的事，不是内容的事。
public struct Item: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    /// 要做的那件事。不能是空串 —— 一条没有字的待办等于一行看不见的东西，
    /// 由 `HomeModel.create` 把关。
    public var text: String
    /// 打勾了没有。
    public var isDone: Bool
    /// 写下的时间。
    public var createdAt: Date
    /// 打勾的时间。没打勾就是 `nil`。
    ///
    /// 存它不是为了「记录」，是为了**排序**：「已完成」那一列按完成时间倒序，
    /// 刚拖过去的那张才会出现在列首。按 `createdAt` 排的话，一张刚勾掉的卡
    /// 会插进那一列中间某处 —— 用户看到的是「它不见了」。
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        text: String,
        isDone: Bool = false,
        createdAt: Date = .now,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.isDone = isDone
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case isDone
        case createdAt
        case completedAt
    }

    /// 备忘时代落盘用的键。只在解码老文件时用得上，写出去的永远不带它们。
    private enum LegacyKeys: String, CodingKey {
        case title
        case content
    }

    /// 手写解码，只为了让升级前的 items.json 还读得进来。
    ///
    /// 改成待办之前，一条记录是「标题 + 正文」两个字段。合成的 `Codable` 碰上
    /// 那样的文件会抛 `keyNotFound`，而 `FileItemRepository` 把任何解码失败都翻译成
    /// 「读不了 items.json」—— 换个字段名就会让用户之前写的**全部**内容
    /// 一起消失在一个错误态后面。
    ///
    /// 老记录的标题和正文拼成一条待办的文本（中间一个换行），一个字都不丢；
    /// `isDone` / `completedAt` 缺席的意思是「还没做」，不是「文件坏了」。
    /// 编码那一侧照旧走合成实现：写出去的永远是带 `text` / `isDone` 的新格式。
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.isDone = try container.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        // 缺席 = 不知道什么时候打的勾（升级前存的），不是文件坏了。
        // 排序那一侧对 nil 有回落，读不出来也不会空一块。
        self.completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)

        if let text = try container.decodeIfPresent(String.self, forKey: .text) {
            self.text = text
            return
        }

        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        let title = try legacy.decode(String.self, forKey: .title)
        let content = try legacy.decodeIfPresent(String.self, forKey: .content) ?? ""
        self.text = content.isEmpty ? title : "\(title)\n\(content)"
    }
}
