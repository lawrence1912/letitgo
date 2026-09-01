import Foundation

/// 编解码的纯函数。没有状态、没有 I/O —— 所以它整个是可测的，
/// 界面那一层只负责把字符串递进来、把结果摆出去。
///
/// ## 宽进严出
///
/// **编码**只产出一种写法（每种格式最常用的那一种）。
/// **解码**尽量把能认的都认了 —— 粘进来的东西是从别处复制的，
/// 它长什么样不由我们决定：Base64 少了 `=`、URL-safe 和标准字母表混着用、
/// 十六进制带 `0x` 前缀或者中间有空格，这些全都收。
public enum Codec {

    public enum Format: String, CaseIterable, Identifiable, Hashable, Sendable {
        case base64
        case base64URL
        case url
        case hex

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .base64: "Base64"
            case .base64URL: "Base64 URL"
            case .url: "URL"
            case .hex: "十六进制"
            }
        }

        /// 和 Java 那边的对应关系，以及**两边不一致的地方**。
        /// 这行字是这个工具真正的价值 —— 转换本身谁都会写。
        public var note: String {
            switch self {
            case .base64:
                "对应 Base64.getEncoder() / getDecoder()，带 = 补位"
            case .base64URL:
                "对应 Base64.getUrlEncoder().withoutPadding()：+/ 换成 -_，不补 =（JWT 用的就是这种）"
            case .url:
                "空格编成 %20（RFC 3986 / java.net.URI）。URLEncoder 编成 + 是表单语义，两边不通用"
            case .hex:
                "小写，无分隔 —— 对应 String.format(\"%02x\", b)"
            }
        }
    }

    // MARK: - 编码

    /// 文本按 **UTF-8** 取字节再编码。Java 那边 `s.getBytes()` 用平台默认字符集，
    /// 中文 Windows 上是 GBK —— 那是两边编出来对不上的头号原因。
    public static func encode(_ text: String, as format: Format) -> String {
        // URL 编码是对**字符**做的（百分号转义里已经含了 UTF-8 这一步），
        // 走字节那条路会把它变成一串 %XX 的十六进制，不是一回事。
        if case .url = format {
            let unreserved = CharacterSet(charactersIn:
                "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
            return text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? text
        }
        return encode(Data(text.utf8), as: format)
    }

    public static func encode(_ bytes: Data, as format: Format) -> String {
        switch format {
        case .base64:
            return bytes.base64EncodedString()
        case .base64URL:
            return bytes.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        case .url:
            // 只保留 RFC 3986 的 unreserved 集合，别的一律转义。
            // 不用 Foundation 那几个现成的 CharacterSet —— 它们保留了
            // `&=+?/` 这类子分隔符，用来编「整条 URL」是对的，
            // 用来编「一个参数值」就是错的，而后者才是这个工具的用途。
            return encode(String(decoding: bytes, as: UTF8.self), as: .url)
        case .hex:
            return bytes.map { String(format: "%02x", $0) }.joined()
        }
    }

    // MARK: - 解码

    public struct Decoded: Equatable, Sendable {
        public let bytes: Data
        /// 字节能按 UTF-8 读出来才有值。读不出来不是错误 ——
        /// Base64 里装的本来就可能是图片或密文。
        public let text: String?

        public var isText: Bool { text != nil }
    }

    public enum Failure: Error, Equatable, Sendable {
        case notBase64
        case base64Length(Int)
        case hexOddLength(Int)
        case hexInvalidCharacter(Character)
        case percentInvalid

        /// 说清楚**是什么不对**，不是「解码失败」。
        /// 用户粘进来的东西通常只差一点，得让他看得出差在哪。
        public var message: String {
            switch self {
            case .notBase64:
                "不是合法的 Base64 —— 里面有字母表之外的字符。"
            case .base64Length(let count):
                "Base64 长度是 \(count)，除以 4 余 1 —— 这个长度不可能合法，多半是复制时少了几个字符。"
            case .hexOddLength(let count):
                "十六进制长度是 \(count)，是奇数 —— 两个字符才是一个字节。"
            case .hexInvalidCharacter(let character):
                "「\(character)」不是十六进制字符（只能是 0-9 / a-f）。"
            case .percentInvalid:
                "百分号转义不完整 —— % 后面得跟两位十六进制。"
            }
        }
    }

    public static func decode(_ text: String, from format: Format) throws -> Decoded {
        switch format {
        case .base64, .base64URL:
            return try decodeBase64(text)
        case .url:
            guard let decoded = text.removingPercentEncoding else { throw Failure.percentInvalid }
            return Decoded(bytes: Data(decoded.utf8), text: decoded)
        case .hex:
            return try decodeHex(text)
        }
    }

    /// 标准和 URL-safe 走同一条路：字母表和补位都容忍。
    /// 分两个格式只是为了**编码**时给出不同的写法。
    private static func decodeBase64(_ raw: String) throws -> Decoded {
        var compact = raw.filter { !$0.isWhitespace }
        compact = compact
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        compact = compact.replacingOccurrences(of: "=", with: "")

        let remainder = compact.count % 4
        // 余 1 是唯一一个「无论怎么补都不可能对」的长度：
        // Base64 每 4 个字符编 3 个字节，余数只可能是 0 / 2 / 3。
        if remainder == 1 { throw Failure.base64Length(compact.count) }
        if remainder > 0 { compact += String(repeating: "=", count: 4 - remainder) }

        guard let bytes = Data(base64Encoded: compact) else { throw Failure.notBase64 }
        return Decoded(bytes: bytes, text: String(data: bytes, encoding: .utf8))
    }

    private static func decodeHex(_ raw: String) throws -> Decoded {
        var compact = raw.filter { !$0.isWhitespace && $0 != "-" && $0 != ":" }
        if compact.hasPrefix("0x") || compact.hasPrefix("0X") { compact.removeFirst(2) }

        if let bad = compact.first(where: { $0.hexDigitValue == nil }) {
            throw Failure.hexInvalidCharacter(bad)
        }
        guard compact.count % 2 == 0 else { throw Failure.hexOddLength(compact.count) }

        var bytes = Data(capacity: compact.count / 2)
        var index = compact.startIndex
        while index < compact.endIndex {
            let next = compact.index(index, offsetBy: 2)
            // 上面已经逐字符验过，这里不会失败。
            bytes.append(UInt8(compact[index..<next], radix: 16)!)
            index = next
        }
        return Decoded(bytes: bytes, text: String(data: bytes, encoding: .utf8))
    }

    /// 解码出来不是文本时给它一个能看的样子：十六进制 + ASCII，
    /// 每行 16 字节。直接把非 UTF-8 字节塞进 `Text` 只会得到一屏问号。
    public static func hexDump(_ bytes: Data, maxBytes: Int = 512) -> String {
        let shown = bytes.prefix(maxBytes)
        var lines: [String] = []
        for offset in stride(from: 0, to: shown.count, by: 16) {
            let chunk = Array(shown[shown.index(shown.startIndex, offsetBy: offset)...].prefix(16))
            let hex = chunk.map { String(format: "%02x", $0) }.joined(separator: " ")
            let ascii = String(chunk.map { $0 >= 32 && $0 < 127 ? Character(UnicodeScalar($0)) : "." })
            lines.append(String(format: "%08x  %-47s  %@", offset, (hex as NSString).utf8String!, ascii))
        }
        if bytes.count > maxBytes {
            lines.append("… 还有 \(bytes.count - maxBytes) 字节")
        }
        return lines.joined(separator: "\n")
    }
}
