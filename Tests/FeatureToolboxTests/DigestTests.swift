import Foundation
import Testing

@testable import FeatureToolbox

@Suite("哈希")
struct DigestTests {

    /// 标准测试向量，和命令行的 `md5` / `shasum` 对过。
    @Test(
        "四个算法对上公开测试向量",
        arguments: [
            (Digest.Algorithm.md5, "900150983cd24fb0d6963f7d28e17f72"),
            (.sha1, "a9993e364706816aba3e25717850c26c9cd0d89d"),
            (.sha256, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
            (
                .sha512,
                "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a"
                    + "2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"
            ),
        ]
    )
    func matchesKnownVectors(algorithm: Digest.Algorithm, expected: String) {
        #expect(Digest.hex("abc", algorithm) == expected)
    }

    @Test("空输入也有摘要 —— 不是空字符串")
    func emptyInputStillHashes() {
        #expect(Digest.hex("", .md5) == "d41d8cd98f00b204e9800998ecf8427e")
    }

    /// 跨语言对不上的头号原因：Java 那边 `s.getBytes()` 用平台默认字符集，
    /// 中文 Windows 上是 GBK。这里钉死 UTF-8。
    @Test("中文按 UTF-8 取字节，不是平台默认字符集")
    func chineseTextHashesItsUTF8Bytes() {
        #expect(Digest.hex("中文", .md5) == "a7bac2239fcdcb3a067903d8077c4a07")
        #expect(Digest.hex(Data("中文".utf8), .md5) == Digest.hex("中文", .md5))
    }

    @Test("大小写只改呈现，不改内容")
    func uppercaseIsPresentationOnly() {
        let lower = Digest.hex("abc", .sha256)
        let upper = Digest.hex("abc", .sha256, uppercase: true)

        #expect(upper == lower.uppercased())
    }

    @Test("MD5 / SHA-1 带着「别拿来防篡改」的提醒，SHA-2 不带")
    func legacyAlgorithmsCarryACaution() {
        #expect(Digest.Algorithm.md5.caution != nil)
        #expect(Digest.Algorithm.sha1.caution != nil)
        #expect(Digest.Algorithm.sha256.caution == nil)
        #expect(Digest.Algorithm.sha512.caution == nil)
    }
}
