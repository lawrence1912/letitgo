import CryptoKit
import Foundation

/// JWT 拆解。
///
/// ## 为什么这个要有本地版本
///
/// 网页版的 JWT 工具很好用，代价是**你把 token 粘进了别人的输入框**。
/// 生产环境的 access token 里通常带着用户 id、租户、权限列表，有效期还没到 ——
/// 那就是一份能直接用的凭证。这个工具整段跑在本机，不发任何请求，
/// 那正是它存在的理由。
///
/// ## 它其实是三个已有工具拼起来的
///
/// base64url 解码（`Codec`）→ JSON 格式化（`JSONFormatter`）→
/// 时间戳换算（`TimeConversion`）。JWT 本身没有神秘的地方，
/// 麻烦的是手工做这三步。
public enum JWT {

    public struct TimeClaim: Identifiable, Equatable, Sendable {
        public let name: String
        public let meaning: String
        public let date: Date

        public var id: String { name }
    }

    public struct Decoded: Equatable, Sendable {
        /// 格式化之后的 header / payload JSON。
        public let header: String
        public let payload: String
        public let algorithm: String?
        public let type: String?
        public let times: [TimeClaim]
        public let signature: Data
        /// 签名覆盖的那段：`header.payload`（原样的 base64url 文本）。
        public let signingInput: String
    }

    public enum Failure: Error, Equatable, Sendable {
        case empty
        case segments(Int)
        case badBase64(String)
        case badJSON(String)

        public var message: String {
            switch self {
            case .empty:
                "粘一个 token 进来。开头带 Bearer 也没关系，会自己去掉。"
            case .segments(let count):
                "JWT 是用 . 分成三段的（header.payload.signature），这里数出来 \(count) 段。"
            case .badBase64(let part):
                "\(part) 那一段不是合法的 base64url —— 复制的时候可能少了几个字符。"
            case .badJSON(let part):
                "\(part) 解出来了，但不是 JSON。"
            }
        }
    }

    /// RFC 7519 里带时间语义的那几个声明，全部是**秒**级 epoch。
    private static let timeClaims: [(String, String)] = [
        ("exp", "过期时间"),
        ("iat", "签发时间"),
        ("nbf", "生效时间"),
        ("auth_time", "认证时间"),
    ]

    public static func decode(_ raw: String) throws -> Decoded {
        var token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // 十有八九是从 Authorization 头里整行复制过来的。
        // 按词切而不是按前缀切 —— 只复制到 "Bearer" 那半截也得认，
        // 那时候该报「空」，不是「段数不对」。
        let words = token.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        if words.first?.lowercased() == "bearer" {
            token = words.count > 1
                ? words[1].trimmingCharacters(in: .whitespacesAndNewlines)
                : ""
        }
        guard !token.isEmpty else { throw Failure.empty }

        let segments = token.components(separatedBy: ".")
        // 两段是 alg=none 的未签名 token；三段但第三段为空也是同一回事。
        guard segments.count == 2 || segments.count == 3 else {
            throw Failure.segments(segments.count)
        }

        let headerJSON = try json(from: segments[0], part: "header")
        let payloadJSON = try json(from: segments[1], part: "payload")
        let signature = segments.count == 3 ? ((try? Codec.decode(segments[2], from: .base64URL).bytes) ?? Data()) : Data()

        let headerObject = try? JSONSerialization.jsonObject(with: Data(headerJSON.raw.utf8)) as? [String: Any]
        let payloadObject = try? JSONSerialization.jsonObject(with: Data(payloadJSON.raw.utf8)) as? [String: Any]

        return Decoded(
            header: headerJSON.formatted,
            payload: payloadJSON.formatted,
            algorithm: (headerObject ?? [:])?["alg"] as? String,
            type: (headerObject ?? [:])?["typ"] as? String,
            times: times(in: (payloadObject ?? [:]) ?? [:]),
            signature: signature,
            signingInput: "\(segments[0]).\(segments[1])"
        )
    }

    private static func json(from segment: String, part: String) throws -> (raw: String, formatted: String) {
        guard let decoded = try? Codec.decode(segment, from: .base64URL), let text = decoded.text else {
            throw Failure.badBase64(part)
        }
        guard let formatted = try? JSONFormatter.format(text, style: .pretty) else {
            throw Failure.badJSON(part)
        }
        return (text, formatted.text)
    }

    private static func times(in payload: [String: Any]) -> [TimeClaim] {
        timeClaims.compactMap { name, meaning in
            guard let seconds = payload[name] as? Double else { return nil }
            return TimeClaim(
                name: name,
                meaning: meaning,
                date: Date(timeIntervalSince1970: seconds)
            )
        }
    }

    // MARK: - 有效期

    public enum Validity: Equatable, Sendable {
        case noExpiry
        case valid(remaining: TimeInterval)
        case expired(ago: TimeInterval)
        case notYetValid(in: TimeInterval)
    }

    public static func validity(of decoded: Decoded, now: Date = Date()) -> Validity {
        if let notBefore = decoded.times.first(where: { $0.name == "nbf" })?.date, notBefore > now {
            return .notYetValid(in: notBefore.timeIntervalSince(now))
        }
        guard let expiry = decoded.times.first(where: { $0.name == "exp" })?.date else {
            return .noExpiry
        }
        return expiry > now
            ? .valid(remaining: expiry.timeIntervalSince(now))
            : .expired(ago: now.timeIntervalSince(expiry))
    }

    // MARK: - 签名

    public enum Verification: Equatable, Sendable {
        case noSecret
        case unsupported(String)
        case valid
        case invalid

        public var message: String {
            switch self {
            case .noSecret: "填上密钥就能验签"
            case .unsupported(let algorithm):
                "\(algorithm) 要用公钥验，这里只做 HMAC（HS256 / HS384 / HS512）"
            case .valid: "签名对得上"
            case .invalid: "签名对不上"
            }
        }
    }

    /// 只做 HMAC 那几个。RS/ES/PS 系列要解公钥，那是 RSA 那个工具的活儿，
    /// 而且验签还要证书链，不是一个小工具该假装能做的事。
    public static func verify(_ decoded: Decoded, secret: String) -> Verification {
        guard !secret.isEmpty else { return .noSecret }
        guard let algorithm = decoded.algorithm else { return .unsupported("没写 alg") }

        let key = SymmetricKey(data: Data(secret.utf8))
        let message = Data(decoded.signingInput.utf8)
        let signature = decoded.signature

        let matches: Bool
        switch algorithm.uppercased() {
        case "HS256":
            matches = HMAC<SHA256>.isValidAuthenticationCode(signature, authenticating: message, using: key)
        case "HS384":
            matches = HMAC<SHA384>.isValidAuthenticationCode(signature, authenticating: message, using: key)
        case "HS512":
            matches = HMAC<SHA512>.isValidAuthenticationCode(signature, authenticating: message, using: key)
        default:
            return .unsupported(algorithm)
        }
        return matches ? .valid : .invalid
    }
}
