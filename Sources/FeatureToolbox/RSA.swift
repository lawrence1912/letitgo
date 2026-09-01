import Foundation
import Security

/// RSA 加解密。
///
/// ## 麻烦的从来不是加解密，是密钥格式
///
/// Apple 的 `SecKey` 只认 **PKCS#1**（`BEGIN RSA PUBLIC KEY`），
/// 而 Java 那边 `X509EncodedKeySpec` / `PKCS8EncodedKeySpec` 给出来的是
/// **X.509 SubjectPublicKeyInfo**（`BEGIN PUBLIC KEY`）和 **PKCS#8**
/// （`BEGIN PRIVATE KEY`）—— 也就是 `openssl` 默认吐出来的那两种。
///
/// 两边差的只是外面包的那层 DER 壳子。所以这里自己拆壳、自己包壳：
/// **收进来的和吐出去的都是 Java 那边直接能用的格式**，不用先 openssl 转一道。
///
/// ## 加密本身没什么可写的
///
/// 真正的 RSA 运算全部交给 `Security.framework` —— 密码学不自己实现，
/// 这里只负责把字节喂进去。
public enum RSA {

    public enum KeySize: Int, CaseIterable, Identifiable, Hashable, Sendable {
        case bits2048 = 2048
        case bits3072 = 3072
        case bits4096 = 4096

        public var id: Int { rawValue }
        public var title: String { "\(rawValue)" }
    }

    public enum Padding: String, CaseIterable, Identifiable, Hashable, Sendable {
        case pkcs1
        case oaepSHA1
        case oaepSHA256

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .pkcs1: "PKCS#1"
            case .oaepSHA1: "OAEP SHA-1"
            case .oaepSHA256: "OAEP SHA-256"
            }
        }

        /// Java 那边对应的 transformation 字符串，以及**对不上的地方**。
        public var note: String {
            switch self {
            case .pkcs1:
                "对应 Cipher.getInstance(\"RSA/ECB/PKCS1Padding\")"
            case .oaepSHA1:
                "对应 \"RSA/ECB/OAEPWithSHA-1AndMGF1Padding\""
            case .oaepSHA256:
                "对应 \"RSA/ECB/OAEPWithSHA-256AndMGF1Padding\" —— 但 JDK 里那个串的 MGF1 仍然用 SHA-1，"
                    + "要显式传 OAEPParameterSpec 才和这里一致，否则两边解不开"
            }
        }

        var algorithm: SecKeyAlgorithm {
            switch self {
            case .pkcs1: .rsaEncryptionPKCS1
            case .oaepSHA1: .rsaEncryptionOAEPSHA1
            case .oaepSHA256: .rsaEncryptionOAEPSHA256
            }
        }

        /// 明文上限 = 模长 − 填充开销。
        func maximumPlaintext(blockSize: Int) -> Int {
            switch self {
            case .pkcs1: blockSize - 11
            case .oaepSHA1: blockSize - 2 * 20 - 2
            case .oaepSHA256: blockSize - 2 * 32 - 2
            }
        }
    }

    public struct KeyPair: Equatable, Sendable {
        /// X.509 SubjectPublicKeyInfo，`BEGIN PUBLIC KEY`。
        public let publicKey: String
        /// PKCS#8，`BEGIN PRIVATE KEY`。
        public let privateKey: String
    }

    public enum Failure: Error, Equatable, Sendable {
        case noKey
        case badPEM(String)
        case tooLong(limit: Int, actual: Int)
        case notUTF8
        case security(String)

        public var message: String {
            switch self {
            case .noKey:
                "先填一个密钥。PEM 格式，BEGIN PUBLIC KEY / BEGIN PRIVATE KEY 那种。"
            case .badPEM(let detail):
                "密钥读不出来：\(detail)"
            case .tooLong(let limit, let actual):
                """
                明文 \(actual) 字节，超过了这个密钥能加密的上限 \(limit) 字节。
                RSA 本来就不是用来加长内容的 —— 通常的做法是用 AES 加密内容，再用 RSA 加密那把 AES 密钥。
                """
            case .notUTF8:
                "解出来的字节不是 UTF-8 文本 —— 密钥或填充方式可能对不上。"
            case .security(let detail):
                detail
            }
        }
    }

    // MARK: - 生成

    public static func generate(_ size: KeySize) throws -> KeyPair {
        var error: Unmanaged<CFError>?
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: size.rawValue,
            // 不进钥匙串：这是个临时生成的调试用密钥，不该留在系统里。
            kSecAttrIsPermanent as String: false,
        ]
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw Failure.security(describe(error))
        }
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw Failure.security("生成了私钥但取不出公钥。")
        }

        return KeyPair(
            publicKey: pem(DER.wrapSubjectPublicKeyInfo(try external(publicKey)), label: "PUBLIC KEY"),
            privateKey: pem(DER.wrapPKCS8(try external(privateKey)), label: "PRIVATE KEY")
        )
    }

    // MARK: - 加解密

    public static func encrypt(_ text: String, publicKeyPEM: String, padding: Padding) throws -> String {
        let key = try key(from: publicKeyPEM, isPrivate: false)
        let plaintext = Data(text.utf8)

        let limit = padding.maximumPlaintext(blockSize: SecKeyGetBlockSize(key))
        guard plaintext.count <= limit else {
            throw Failure.tooLong(limit: limit, actual: plaintext.count)
        }

        var error: Unmanaged<CFError>?
        guard let encrypted = SecKeyCreateEncryptedData(
            key, padding.algorithm, plaintext as CFData, &error
        ) else {
            throw Failure.security(describe(error))
        }
        return (encrypted as Data).base64EncodedString()
    }

    public static func decrypt(_ base64: String, privateKeyPEM: String, padding: Padding) throws -> String {
        let key = try key(from: privateKeyPEM, isPrivate: true)
        // 密文多半是从别处复制来的，带换行也收下。
        guard let ciphertext = try? Codec.decode(base64, from: .base64).bytes else {
            throw Failure.badPEM("密文不是合法的 Base64。")
        }

        var error: Unmanaged<CFError>?
        guard let decrypted = SecKeyCreateDecryptedData(
            key, padding.algorithm, ciphertext as CFData, &error
        ) else {
            throw Failure.security(describe(error))
        }
        guard let text = String(data: decrypted as Data, encoding: .utf8) else {
            throw Failure.notUTF8
        }
        return text
    }

    // MARK: - 密钥

    static func key(from pem: String, isPrivate: Bool) throws -> SecKey {
        let trimmed = pem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw Failure.noKey }

        let (label, der) = try parsePEM(trimmed)
        // 带壳的先拆壳。标签认不出来时按内容试 —— 用户从哪儿复制来的都有。
        let pkcs1: [UInt8] = switch label {
        case "PUBLIC KEY": try DER.unwrapSubjectPublicKeyInfo(der)
        case "PRIVATE KEY": try DER.unwrapPKCS8(der)
        default: der
        }

        var error: Unmanaged<CFError>?
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: isPrivate ? kSecAttrKeyClassPrivate : kSecAttrKeyClassPublic,
        ]
        guard let key = SecKeyCreateWithData(
            Data(pkcs1) as CFData, attributes as CFDictionary, &error
        ) else {
            throw Failure.badPEM(describe(error))
        }
        return key
    }

    static func parsePEM(_ text: String) throws -> (label: String, der: [UInt8]) {
        let lines = text.components(separatedBy: .newlines).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard let header = lines.first(where: { $0.hasPrefix("-----BEGIN") }) else {
            throw Failure.badPEM("找不到 -----BEGIN 那一行。")
        }
        let label = header
            .replacingOccurrences(of: "-----BEGIN ", with: "")
            .replacingOccurrences(of: "-----", with: "")
            .trimmingCharacters(in: .whitespaces)

        let body = lines
            .filter { !$0.hasPrefix("-----") && !$0.isEmpty }
            .joined()
        guard let data = Data(base64Encoded: body) else {
            throw Failure.badPEM("中间那段不是合法的 Base64。")
        }
        return (label.uppercased(), Array(data))
    }

    static func pem(_ der: [UInt8], label: String) -> String {
        let base64 = Data(der).base64EncodedString()
        // PEM 一行 64 个字符 —— 不折行的话 openssl 之类的老工具会读不进去。
        let lines = stride(from: 0, to: base64.count, by: 64).map { offset -> String in
            let start = base64.index(base64.startIndex, offsetBy: offset)
            let end = base64.index(start, offsetBy: min(64, base64.count - offset))
            return String(base64[start..<end])
        }
        return (["-----BEGIN \(label)-----"] + lines + ["-----END \(label)-----"]).joined(separator: "\n")
    }

    private static func external(_ key: SecKey) throws -> [UInt8] {
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(key, &error) else {
            throw Failure.security(describe(error))
        }
        return Array(data as Data)
    }

    private static func describe(_ error: Unmanaged<CFError>?) -> String {
        guard let error = error?.takeRetainedValue() else { return "Security.framework 没说原因。" }
        return CFErrorCopyDescription(error) as String? ?? "\(error)"
    }
}

// MARK: - DER

/// 够用就好的 DER 读写。只处理 RSA 密钥那几层壳子，不是通用 ASN.1 实现。
enum DER {

    /// rsaEncryption 的 AlgorithmIdentifier：`SEQUENCE { OID 1.2.840.113549.1.1.1, NULL }`
    static let rsaAlgorithmIdentifier: [UInt8] = encode(
        0x30,
        [0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01] + [0x05, 0x00]
    )

    struct Element {
        let tag: UInt8
        let value: [UInt8]
        /// 下一个元素的起点。
        let end: Int
    }

    static func read(_ bytes: [UInt8], from index: Int) throws -> Element {
        guard index + 1 < bytes.count else { throw RSA.Failure.badPEM("DER 结构不完整。") }
        let tag = bytes[index]
        var cursor = index + 1

        var length = Int(bytes[cursor])
        cursor += 1
        if length & 0x80 != 0 {
            let byteCount = length & 0x7F
            guard byteCount > 0, byteCount <= 4, cursor + byteCount <= bytes.count else {
                throw RSA.Failure.badPEM("DER 长度字段读不出来。")
            }
            length = 0
            for _ in 0..<byteCount {
                length = length << 8 | Int(bytes[cursor])
                cursor += 1
            }
        }
        guard cursor + length <= bytes.count else { throw RSA.Failure.badPEM("DER 长度超出了数据本身。") }
        return Element(tag: tag, value: Array(bytes[cursor..<(cursor + length)]), end: cursor + length)
    }

    static func encode(_ tag: UInt8, _ value: [UInt8]) -> [UInt8] {
        var output: [UInt8] = [tag]
        if value.count < 0x80 {
            output.append(UInt8(value.count))
        } else {
            var length = value.count
            var lengthBytes: [UInt8] = []
            while length > 0 {
                lengthBytes.insert(UInt8(length & 0xFF), at: 0)
                length >>= 8
            }
            output.append(0x80 | UInt8(lengthBytes.count))
            output += lengthBytes
        }
        return output + value
    }

    // MARK: 拆壳

    /// `SEQUENCE { AlgorithmIdentifier, BIT STRING { PKCS#1 } }` → PKCS#1
    static func unwrapSubjectPublicKeyInfo(_ der: [UInt8]) throws -> [UInt8] {
        let outer = try read(der, from: 0)
        guard outer.tag == 0x30 else { throw RSA.Failure.badPEM("公钥外层不是 SEQUENCE。") }

        let algorithm = try read(outer.value, from: 0)
        let bitString = try read(outer.value, from: algorithm.end)
        guard bitString.tag == 0x03, bitString.value.first == 0x00 else {
            throw RSA.Failure.badPEM("公钥里找不到 BIT STRING。")
        }
        // BIT STRING 的第一个字节是「末尾有几个空位」，密钥里永远是 0。
        return Array(bitString.value.dropFirst())
    }

    /// `SEQUENCE { INTEGER 0, AlgorithmIdentifier, OCTET STRING { PKCS#1 } }` → PKCS#1
    static func unwrapPKCS8(_ der: [UInt8]) throws -> [UInt8] {
        let outer = try read(der, from: 0)
        guard outer.tag == 0x30 else { throw RSA.Failure.badPEM("私钥外层不是 SEQUENCE。") }

        let version = try read(outer.value, from: 0)
        let algorithm = try read(outer.value, from: version.end)
        let octetString = try read(outer.value, from: algorithm.end)
        guard octetString.tag == 0x04 else { throw RSA.Failure.badPEM("私钥里找不到 OCTET STRING。") }
        return octetString.value
    }

    // MARK: 包壳

    static func wrapSubjectPublicKeyInfo(_ pkcs1: [UInt8]) -> [UInt8] {
        encode(0x30, rsaAlgorithmIdentifier + encode(0x03, [0x00] + pkcs1))
    }

    static func wrapPKCS8(_ pkcs1: [UInt8]) -> [UInt8] {
        encode(0x30, [0x02, 0x01, 0x00] + rsaAlgorithmIdentifier + encode(0x04, pkcs1))
    }
}
