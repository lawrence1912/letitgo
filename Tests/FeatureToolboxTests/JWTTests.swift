import CryptoKit
import Foundation
import Testing

@testable import FeatureToolbox

@Suite("JWT")
struct JWTTests {
    private let secret = "letitgo-test-secret"

    /// 自己签一个 —— 这样密钥是已知的，验签那条路才测得到。
    private func makeToken(
        header: String = #"{"alg":"HS256","typ":"JWT"}"#,
        payload: String,
        secret: String? = nil,
        algorithm: String = "HS256"
    ) -> String {
        let head = base64url(Data(header.utf8))
        let body = base64url(Data(payload.utf8))
        let key = SymmetricKey(data: Data((secret ?? self.secret).utf8))
        let message = Data("\(head).\(body)".utf8)

        let signature: Data = switch algorithm {
        case "HS384": Data(HMAC<SHA384>.authenticationCode(for: message, using: key))
        case "HS512": Data(HMAC<SHA512>.authenticationCode(for: message, using: key))
        default: Data(HMAC<SHA256>.authenticationCode(for: message, using: key))
        }
        return "\(head).\(body).\(base64url(signature))"
    }

    private func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - 拆解

    @Test("拆得开真实世界的 token（jwt.io 那个例子）")
    func decodesAWellKnownToken() throws {
        let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
            + ".eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ"
            + ".SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"

        let decoded = try JWT.decode(token)

        #expect(decoded.algorithm == "HS256")
        #expect(decoded.type == "JWT")
        #expect(decoded.payload.contains("John Doe"))
        // header / payload 是格式化过的 —— 原始的一行 JSON 没人读得下去
        #expect(decoded.header.contains("\n"))
        #expect(decoded.times.first(where: { $0.name == "iat" })?.date
            == Date(timeIntervalSince1970: 1_516_239_022))
    }

    @Test("Authorization 头整行复制进来也认")
    func stripsTheBearerPrefix() throws {
        let token = makeToken(payload: #"{"sub":"a"}"#)

        #expect(try JWT.decode("Bearer " + token).payload == (try JWT.decode(token).payload))
    }

    @Test("段数不对要说清楚数出来几段")
    func wrongSegmentCountIsReported() {
        #expect(throws: JWT.Failure.segments(1)) { try JWT.decode("notatoken") }
        #expect(throws: JWT.Failure.segments(4)) { try JWT.decode("a.b.c.d") }
    }

    @Test("空输入单独一种提示")
    func emptyInputIsItsOwnFailure() {
        #expect(throws: JWT.Failure.empty) { try JWT.decode("  ") }
        #expect(throws: JWT.Failure.empty) { try JWT.decode("Bearer ") }
    }

    @Test("某一段坏了要指出是哪一段")
    func badSegmentNamesTheSegment() {
        #expect(throws: JWT.Failure.badBase64("payload")) {
            try JWT.decode("eyJhbGciOiJIUzI1NiJ9.@@@.sig")
        }
    }

    // MARK: - 有效期

    @Test("过期 / 未过期 / 还没生效 / 没有 exp，四种都要分得开")
    func validityCoversEveryShape() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let expired = try JWT.decode(makeToken(payload: #"{"exp":1699999000}"#))
        let live = try JWT.decode(makeToken(payload: #"{"exp":1700003600}"#))
        let early = try JWT.decode(makeToken(payload: #"{"nbf":1700003600,"exp":1700007200}"#))
        let forever = try JWT.decode(makeToken(payload: #"{"sub":"a"}"#))

        #expect(JWT.validity(of: expired, now: now) == .expired(ago: 1000))
        #expect(JWT.validity(of: live, now: now) == .valid(remaining: 3600))
        #expect(JWT.validity(of: early, now: now) == .notYetValid(in: 3600))
        #expect(JWT.validity(of: forever, now: now) == .noExpiry)
    }

    @Test("时间声明按 RFC 7519 一律当秒读")
    func timeClaimsAreSeconds() throws {
        let decoded = try JWT.decode(makeToken(payload: #"{"exp":1700000000,"iat":1699996400}"#))

        #expect(decoded.times.count == 2)
        #expect(decoded.times.first(where: { $0.name == "exp" })?.date
            == Date(timeIntervalSince1970: 1_700_000_000))
    }

    // MARK: - 验签

    @Test("密钥对了就是对了，错了就是错了")
    func hmacVerificationDistinguishesTheSecret() throws {
        let decoded = try JWT.decode(makeToken(payload: #"{"sub":"a"}"#))

        #expect(JWT.verify(decoded, secret: secret) == .valid)
        #expect(JWT.verify(decoded, secret: secret + "x") == .invalid)
    }

    @Test("HS384 / HS512 也验", arguments: ["HS384", "HS512"])
    func supportsTheOtherHMACSizes(algorithm: String) throws {
        let token = makeToken(
            header: #"{"alg":"\#(algorithm)","typ":"JWT"}"#,
            payload: #"{"sub":"a"}"#,
            algorithm: algorithm
        )
        let decoded = try JWT.decode(token)

        #expect(JWT.verify(decoded, secret: secret) == .valid)
        #expect(JWT.verify(decoded, secret: "nope") == .invalid)
    }

    @Test("没给密钥不算验失败 —— 那两件事得分开")
    func noSecretIsNotAFailure() throws {
        let decoded = try JWT.decode(makeToken(payload: #"{"sub":"a"}"#))

        #expect(JWT.verify(decoded, secret: "") == .noSecret)
    }

    @Test("RS256 这类要公钥的，明说不支持，不假装验过")
    func asymmetricAlgorithmsAreDeclined() throws {
        let token = makeToken(header: #"{"alg":"RS256","typ":"JWT"}"#, payload: #"{"sub":"a"}"#)
        let decoded = try JWT.decode(token)

        #expect(JWT.verify(decoded, secret: "whatever") == .unsupported("RS256"))
    }
}
