import CryptoKit
import Foundation

/// 摘要的纯函数。
///
/// 四个算法一次全算出来 —— 它们都很快（几十 KB 的文本在微秒级），
/// 而「我要的是哪一个」经常是看到结果才想起来的。
public enum Digest {

    public enum Algorithm: String, CaseIterable, Identifiable, Hashable, Sendable {
        case md5
        case sha1
        case sha256
        case sha512

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .md5: "MD5"
            case .sha1: "SHA-1"
            case .sha256: "SHA-256"
            case .sha512: "SHA-512"
            }
        }

        /// MD5 / SHA-1 早就不能用来防篡改了，但它们在工程里还有大量正当用途
        /// （文件指纹、缓存键、对老系统的兼容）。所以不藏起来，也不假装它们安全 ——
        /// 在旁边写清楚。
        public var caution: String? {
            switch self {
            case .md5, .sha1: "只用于指纹 / 缓存键，别用来防篡改"
            case .sha256, .sha512: nil
            }
        }
    }

    /// 文本先按 **UTF-8** 取字节，再算摘要。
    ///
    /// 这一步是跨语言对不上的头号原因：`MessageDigest.digest(s.getBytes())`
    /// 用的是**平台默认字符集**，在中文 Windows 上是 GBK，算出来和这里不一样。
    /// Java 那边要写 `s.getBytes(StandardCharsets.UTF_8)` 才对得上。
    public static func hex(_ text: String, _ algorithm: Algorithm, uppercase: Bool = false) -> String {
        hex(Data(text.utf8), algorithm, uppercase: uppercase)
    }

    public static func hex(_ bytes: Data, _ algorithm: Algorithm, uppercase: Bool = false) -> String {
        let digest: any Sequence<UInt8> = switch algorithm {
        case .md5: Array(Insecure.MD5.hash(data: bytes))
        case .sha1: Array(Insecure.SHA1.hash(data: bytes))
        case .sha256: Array(SHA256.hash(data: bytes))
        case .sha512: Array(SHA512.hash(data: bytes))
        }
        return digest.map { String(format: uppercase ? "%02X" : "%02x", $0) }.joined()
    }
}
