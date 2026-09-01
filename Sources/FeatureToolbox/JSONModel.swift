import Foundation
import Observation

/// JSON 工具的状态。逻辑全在 `JSONFormatter` 里，这里只管选项。
///
/// 结果是**算出来的**（不像随机串和 RSA 那样要存下来）：
/// 同样的输入永远得到同样的输出，重绘多少次都一样。
@MainActor
@Observable
public final class JSONModel {
    public var input = ""
    public var style: JSONFormatter.Style = .pretty
    public var sortKeys = false

    public init() {}

    public var result: Result<JSONFormatter.Formatted, JSONFormatter.Failure> {
        do {
            return .success(try JSONFormatter.format(input, style: style, sortKeys: sortKeys))
        } catch let failure as JSONFormatter.Failure {
            return .failure(failure)
        } catch {
            return .failure(.invalid(message: "\(error)", excerpt: nil))
        }
    }
}
