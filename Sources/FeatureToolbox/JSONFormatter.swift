import Foundation

/// JSON 的格式化 / 压缩 / 转义。
///
/// ## 这个工具真正解决的问题
///
/// 不是「加缩进」——是**从别的东西里面把 JSON 捞出来**。后端手上的 JSON
/// 十次有八次不是干净的：从日志里复制的引号全是 `\"`，从 Java 代码里复制的
/// 外面还包着一层引号。所以这里**先直接解析，失败了再当成转义过的字符串试一次**，
/// 认出来了就在界面上说一声（「已从转义字符串还原」），而不是默默改了用户的输入。
///
/// 反过来那一步同样常用：改完的 JSON 要塞回测试代码里，得再转义成 Java 字面量。
public enum JSONFormatter {

    public enum Style: String, CaseIterable, Identifiable, Hashable, Sendable {
        case pretty
        case minified
        case javaLiteral

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .pretty: "格式化"
            case .minified: "压缩"
            case .javaLiteral: "Java 字面量"
            }
        }
    }

    /// 为了让输入能解析而**动过的地方**。
    ///
    /// 每一项都要在界面上说出来 —— 悄悄「帮你修好」是最难查的一类行为：
    /// 用户会以为自己那份原始数据是好的，直到它在别处又炸一次。
    public enum Repair: String, CaseIterable, Hashable, Sendable {
        case unescaped
        case unquoted
        case straightQuotes
        case fullWidthPunctuation

        public var title: String {
            switch self {
            case .unescaped: "已还原转义"
            case .unquoted: "已剥掉外层引号"
            case .straightQuotes: "中文引号已换成直引号"
            case .fullWidthPunctuation: "全角冒号 / 逗号已换成半角"
            }
        }
    }

    public struct Formatted: Equatable, Sendable {
        public let text: String
        /// 空的就是原样解析出来的。
        public let repairs: [Repair]
    }

    public enum Failure: Error, Equatable, Sendable {
        case empty
        /// `excerpt` 是出错位置前后那一小截，已经把 ▶ 插好了。
        case invalid(message: String, excerpt: String?)

        public var message: String {
            switch self {
            case .empty: "粘一段 JSON 进来。"
            case .invalid(let message, _): message
            }
        }

        public var excerpt: String? {
            switch self {
            case .empty: nil
            case .invalid(_, let excerpt): excerpt
            }
        }
    }

    // MARK: - 格式化

    public static func format(
        _ raw: String,
        style: Style,
        sortKeys: Bool = false
    ) throws -> Formatted {
        let (object, repairs) = try parse(raw)

        var options: JSONSerialization.WritingOptions = [.fragmentsAllowed]
        // 不加这个的话 "/" 会被写成 "\/" —— 合法，但没人想要，
        // 而且 URL 一多就满屏反斜杠。
        options.insert(.withoutEscapingSlashes)
        if sortKeys { options.insert(.sortedKeys) }
        if style == .pretty { options.insert(.prettyPrinted) }

        guard let data = try? JSONSerialization.data(withJSONObject: object, options: options) else {
            throw Failure.invalid(message: "解析出来了，但写不回去 —— 大概是有 NaN 或者无穷大。", excerpt: nil)
        }
        let text = String(decoding: data, as: UTF8.self)
        return Formatted(
            text: style == .javaLiteral ? javaLiteral(text) : text,
            repairs: repairs
        )
    }

    // MARK: - 解析

    /// 宽进：直接解析不行就依次试几种「常见的坏法」，第一个能解析出来的算数。
    ///
    /// 顺序有讲究 —— 先试原样，最后才试改动最大的组合。
    /// **全都失败时报的是第一次（原样解析）的错**：那才是用户实际粘进来的东西，
    /// 报「修完之后」的错只会让人对着一段自己没写过的文本找问题。
    static func parse(_ raw: String) throws -> (object: Any, repairs: [Repair]) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw Failure.empty }

        var candidates: [(text: String, repairs: [Repair])] = [(trimmed, [])]
        // 从日志 / Java 代码里复制的，引号全是 \"
        if trimmed.contains("\\\"") {
            candidates.append((unescape(trimmed), [.unescaped]))
        }
        // 中文输入法或者从聊天、文档里复制的，引号是 “ ”，冒号逗号可能是全角
        if needsPunctuationRepair(trimmed) {
            candidates.append((normalizePunctuation(trimmed), punctuationRepairs(trimmed)))
            if trimmed.contains("\\\"") {
                candidates.append((
                    normalizePunctuation(unescape(trimmed)),
                    [.unescaped] + punctuationRepairs(trimmed)
                ))
            }
        }

        var firstFailure: (any Error)?
        for candidate in candidates {
            do {
                let parsed = try object(from: candidate.text)
                // 整段本身就是个合法的 JSON **字符串**，而字符串里装的又是 JSON ——
                // 从 Java 代码里连着外层引号一起复制过来就是这样。
                // 这时候用户要的是里面那层，不是「一个字符串」。
                if let inner = parsed as? String, looksLikeJSON(inner),
                   let unwrapped = try? object(from: inner) {
                    return (unwrapped, candidate.repairs + [.unquoted])
                }
                return (parsed, candidate.repairs)
            } catch {
                if firstFailure == nil { firstFailure = error }
            }
        }
        throw firstFailure ?? Failure.empty
    }

    // MARK: - 全角标点

    /// 这几个是中文输入法最常混进来的。**引号是关键** ——
    /// `“` 和 `"` 在大多数字体里几乎看不出区别，但 JSON 只认后者。
    private static let curlyQuotes: Set<Character> = ["\u{201C}", "\u{201D}"]

    private static func needsPunctuationRepair(_ text: String) -> Bool {
        text.contains(where: { curlyQuotes.contains($0) })
            || text.contains("：") || text.contains("，")
    }

    private static func punctuationRepairs(_ text: String) -> [Repair] {
        var repairs: [Repair] = []
        if text.contains(where: { curlyQuotes.contains($0) }) { repairs.append(.straightQuotes) }
        if text.contains("：") || text.contains("，") { repairs.append(.fullWidthPunctuation) }
        return repairs
    }

    /// 全角标点换半角。
    ///
    /// **全角冒号和逗号只在字符串外面换。** 这一条是这段代码存在的理由：
    /// `{"msg": "你好，世界"}` 里那个逗号是内容的一部分，换掉它 JSON 依然合法，
    /// 但用户的数据被悄悄改了 —— 那种错误比解析失败难查得多。
    ///
    /// 引号则是先换的：不先统一成直引号，就没法判断哪儿是字符串里面。
    static func normalizePunctuation(_ text: String) -> String {
        let straightened = String(text.map { curlyQuotes.contains($0) ? "\"" : $0 })

        var output = ""
        var insideString = false
        var escaped = false
        for character in straightened {
            if insideString {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    insideString = false
                }
                output.append(character)
                continue
            }
            switch character {
            case "\"": insideString = true; output.append(character)
            case "：": output.append(":")
            case "，": output.append(",")
            case "\u{3000}": output.append(" ")   // 全角空格
            default: output.append(character)
            }
        }
        return output
    }

    private static func looksLikeJSON(_ text: String) -> Bool {
        let head = text.trimmingCharacters(in: .whitespacesAndNewlines).first
        return head == "{" || head == "["
    }

    private static func object(from text: String) throws -> Any {
        do {
            return try JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed])
        } catch let error as NSError {
            // `NSDebugDescriptionErrorKey` 里那句话带着出错的位置
            //（"No value for key in object around line 1, column 18."），
            // 比 localizedDescription 的「数据没有正确的格式」有用得多。
            let debug = (error.userInfo[NSDebugDescriptionErrorKey] as? String)
                ?? error.localizedDescription
            let offset = offset(of: debug, in: text)
            throw Failure.invalid(
                message: debug,
                excerpt: offset.map { excerpt(text, around: $0) } ?? nil
            )
        }
    }

    /// 报错里的行列是 1 起算的，而且**列是按字节数**的（中文一个字算三列）——
    /// 正好和这里按 UTF-8 字节切片的做法对得上，不用再换算。
    private static func offset(of message: String, in text: String) -> Int? {
        guard let line = number(after: "line", in: message),
              let column = number(after: "column", in: message) else { return nil }

        let bytes = Array(text.utf8)
        var index = 0
        var current = 1
        while current < line, index < bytes.count {
            if bytes[index] == 0x0A { current += 1 }
            index += 1
        }
        return min(bytes.count, index + column - 1)
    }

    private static func number(after keyword: String, in message: String) -> Int? {
        guard let range = message.range(of: "\(keyword) \\d+", options: .regularExpression) else {
            return nil
        }
        return Int(message[range].dropFirst(keyword.count + 1))
    }

    /// 在出错的位置插一个 ▶，前后各留一截。
    ///
    /// 不画对齐的 `^` 那种指示线：等宽字体里中文是双宽的，
    /// 一有中文那根线就指偏了 —— 指错地方比不指更糟。
    public static func excerpt(_ raw: String, around offset: Int, radius: Int = 24) -> String? {
        let bytes = Array(raw.utf8)
        guard offset >= 0, offset <= bytes.count else { return nil }

        // 切在多字节字符中间会切出一串问号，三个位置都要退到字符边界上 ——
        // **包括 offset 本身**：它是报错给的字节位置，完全可能落在一个汉字中间。
        var mark = min(offset, bytes.count)
        while mark > 0, bytes[mark] & 0xC0 == 0x80 { mark -= 1 }
        var start = max(0, mark - radius)
        while start > 0, bytes[start] & 0xC0 == 0x80 { start -= 1 }
        var end = min(bytes.count, mark + radius)
        while end < bytes.count, bytes[end] & 0xC0 == 0x80 { end += 1 }

        let head = String(decoding: bytes[start..<mark], as: UTF8.self)
        let tail = String(decoding: bytes[mark..<end], as: UTF8.self)
        return (start > 0 ? "…" : "") + head + "▶" + tail + (end < bytes.count ? "…" : "")
    }

    // MARK: - 转义

    /// Java 字面量 / 日志里那种转义过的串 → 原文。
    static func unescape(_ raw: String) -> String {
        var text = raw
        if text.count >= 2, text.hasPrefix("\""), text.hasSuffix("\"") {
            text = String(text.dropFirst().dropLast())
        }

        var output = ""
        let characters = Array(text)
        var index = 0
        while index < characters.count {
            guard characters[index] == "\\", index + 1 < characters.count else {
                output.append(characters[index])
                index += 1
                continue
            }
            let escape = characters[index + 1]
            index += 2
            switch escape {
            case "\"": output.append("\"")
            case "\\": output.append("\\")
            case "/": output.append("/")
            case "n": output.append("\n")
            case "r": output.append("\r")
            case "t": output.append("\t")
            case "b": output.append("\u{08}")
            case "f": output.append("\u{0C}")
            case "u":
                let hex = String(characters[index..<min(index + 4, characters.count)])
                if hex.count == 4, let code = UInt32(hex, radix: 16),
                   let scalar = Unicode.Scalar(code) {
                    output.unicodeScalars.append(scalar)
                    index += 4
                } else {
                    output.append("\\u")   // 认不出来就原样留着，别吞了用户的字符
                }
            default:
                // 不认识的转义原样保留，别吞掉用户的字符。
                //
                // 注意这里有个**没法解决**的歧义：`C:\name` 里的 `\n` 是合法的
                // JSON 转义，一定会被当成换行 —— 光看字符串没法知道它原本是
                // 一个 Windows 路径。反转义只对「本来就是转义过的 JSON」成立。
                output.append("\\")
                output.append(escape)
            }
        }
        return output
    }

    /// 原文 → Java 字面量（外面带引号，可以直接粘进代码）。
    static func javaLiteral(_ text: String) -> String {
        var output = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": output += "\\\""
            case "\\": output += "\\\\"
            case "\n": output += "\\n"
            case "\r": output += "\\r"
            case "\t": output += "\\t"
            default: output.unicodeScalars.append(scalar)
            }
        }
        return output + "\""
    }
}
