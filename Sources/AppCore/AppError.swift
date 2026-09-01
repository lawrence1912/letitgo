import Foundation

/// 应用级错误。UI 只认这一种类型，底层错误在边界处统一包一层，
/// 好处是错误提示的措辞集中在一个地方。
public enum AppError: Error, LocalizedError, Equatable, Sendable {
    case storage(String)
    case notFound
    case invalidInput(String)
    case unexpected(String)

    public var errorDescription: String? {
        switch self {
        case .storage(let detail): "存储出错：\(detail)"
        case .notFound: "找不到对应的内容。"
        // 输入校验的措辞由调用方给全，不加前缀 —— 「标题不能为空。」比
        // 「出了点问题：标题不能为空。」更像是在说人话。
        case .invalidInput(let detail): detail
        case .unexpected(let detail): "出了点问题：\(detail)"
        }
    }
}
