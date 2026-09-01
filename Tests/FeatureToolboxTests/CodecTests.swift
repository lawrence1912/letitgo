import Foundation
import Testing

@testable import FeatureToolbox

@Suite("编解码")
struct CodecTests {

    @Test("四种格式都能原样转回来", arguments: Codec.Format.allCases)
    func roundTrip(format: Codec.Format) throws {
        let original = "Hello, 世界! ~_-.@#$ 空格 和 换行\n结束"
        let encoded = Codec.encode(original, as: format)
        let decoded = try Codec.decode(encoded, from: format)
        #expect(decoded.text == original)
    }

    // MARK: - Base64

    @Test("URL-safe 不补 = ，而且不含 + /（JWT 就是这么要求的）")
    func urlSafeAlphabetHasNoPaddingOrSlashes() {
        // 这段字节的标准 Base64 里同时有 + 和 /，正好能验出字母表换没换。
        // 走 Data 那个重载：这些字节不是合法 UTF-8，包成 String 会被替换字符吃掉。
        let source = Data([0xFB, 0xEF, 0xBE, 0xFF, 0x00])
        let standard = Codec.encode(source, as: .base64)
        let urlSafe = Codec.encode(source, as: .base64URL)

        #expect(standard.contains("="))
        #expect(!urlSafe.contains("="))
        #expect(!urlSafe.contains("+"))
        #expect(!urlSafe.contains("/"))
    }

    @Test("解码收下少了 = 的 Base64 —— 从 JWT 里抠出来的就是这样")
    func decodeToleratesMissingPadding() throws {
        let padded = Codec.encode("hi", as: .base64)           // "aGk="
        let stripped = padded.replacingOccurrences(of: "=", with: "")

        #expect(try Codec.decode(stripped, from: .base64).text == "hi")
    }

    @Test("解码收下混着用的两套字母表")
    func decodeAcceptsEitherAlphabet() throws {
        let source = Data([0xFB, 0xEF, 0xBE])
        let standard = Codec.encode(source, as: .base64)
        let urlSafe = Codec.encode(source, as: .base64URL)

        // 用「标准」这一档去解 URL-safe 的串，反过来也一样 —— 两边都得认。
        #expect(try Codec.decode(urlSafe, from: .base64).bytes == Data([0xFB, 0xEF, 0xBE]))
        #expect(try Codec.decode(standard, from: .base64URL).bytes == Data([0xFB, 0xEF, 0xBE]))
    }

    @Test("解码时空白被忽略 —— 粘进来的东西常常带换行")
    func decodeIgnoresWhitespace() throws {
        // aGVsbG8gd29ybGQ= 是 "hello world"，中间塞进空格和换行。
        #expect(try Codec.decode("aGVs bG8g\nd29ybGQ=", from: .base64).text == "hello world")
    }

    @Test("长度余 1 的 Base64 直接说清楚是长度不对，而不是「解码失败」")
    func impossibleBase64LengthIsReportedAsLength() {
        #expect(throws: Codec.Failure.base64Length(5)) {
            try Codec.decode("aGVsb", from: .base64)
        }
    }

    @Test("字母表之外的字符要报出来")
    func nonAlphabetCharacterIsRejected() {
        #expect(throws: Codec.Failure.notBase64) {
            try Codec.decode("aG!k", from: .base64)
        }
    }

    @Test("解出来不是 UTF-8 时，bytes 还在、text 是 nil —— 那不是错误")
    func binaryPayloadDecodesToBytesWithoutText() throws {
        let decoded = try Codec.decode(Data([0xFF, 0xFE, 0x00]).base64EncodedString(), from: .base64)

        #expect(decoded.bytes == Data([0xFF, 0xFE, 0x00]))
        #expect(decoded.text == nil)
        #expect(!decoded.isText)
    }

    // MARK: - URL

    @Test("空格编成 %20，不是 + —— 和 URLEncoder 的差别就在这儿")
    func spaceBecomesPercentTwentyNotPlus() {
        #expect(Codec.encode("a b", as: .url) == "a%20b")
    }

    @Test("参数值里的分隔符也要转义，否则拼进 URL 会把查询串劈开")
    func subDelimitersAreEscaped() {
        #expect(Codec.encode("k=v&x", as: .url) == "k%3Dv%26x")
        #expect(Codec.encode("a/b?c", as: .url) == "a%2Fb%3Fc")
    }

    @Test("unreserved 集合原样保留")
    func unreservedCharactersSurvive() {
        #expect(Codec.encode("aZ0-._~", as: .url) == "aZ0-._~")
    }

    // MARK: - 十六进制

    @Test("小写、无分隔 —— 对齐 String.format(\"%02x\")")
    func hexIsLowercaseAndUnseparated() {
        #expect(Codec.encode("hi", as: .hex) == "6869")
    }

    @Test("解码收下 0x 前缀、大写、空格和冒号分隔")
    func hexDecodeIsLenientAboutFormatting() throws {
        for variant in ["0x6869", "68 69", "68:69", "6869", "0X6869"] {
            #expect(try Codec.decode(variant, from: .hex).text == "hi", "\(variant) 没解出来")
        }
    }

    @Test("奇数长度报长度，非法字符报那个字符")
    func hexFailuresSayWhichProblemItIs() {
        #expect(throws: Codec.Failure.hexOddLength(3)) { try Codec.decode("686", from: .hex) }
        #expect(throws: Codec.Failure.hexInvalidCharacter("g")) { try Codec.decode("68g9", from: .hex) }
    }

    // MARK: - 十六进制预览

    @Test("hexDump 每行 16 字节，尾部说明还剩多少")
    func hexDumpTruncatesAndSaysSo() {
        let dump = Codec.hexDump(Data(repeating: 0x41, count: 40), maxBytes: 32)
        let lines = dump.split(separator: "\n")

        #expect(lines.count == 3)                       // 两行数据 + 一行说明
        #expect(lines[0].hasPrefix("00000000"))
        #expect(lines[0].hasSuffix("AAAAAAAAAAAAAAAA"))
        #expect(lines.last?.contains("还有 8 字节") == true)
    }
}
