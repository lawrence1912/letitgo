import Foundation
import Testing

@testable import FeatureToolbox

@Suite("JSON")
struct JSONFormatterTests {

    @Test("格式化会缩进，压缩会拍平")
    func prettyAndMinifiedAreInverses() throws {
        let compact = #"{"a":1,"b":[1,2]}"#

        let pretty = try JSONFormatter.format(compact, style: .pretty).text
        #expect(pretty.contains("\n"))
        #expect(pretty.contains("  "))

        #expect(try JSONFormatter.format(pretty, style: .minified).text == compact)
    }

    @Test("斜杠不转义 —— URL 里全是 \\/ 没人想看")
    func slashesSurviveUnescaped() throws {
        let json = #"{"url":"https://example.com/a/b"}"#

        #expect(try JSONFormatter.format(json, style: .minified).text == json)
    }

    @Test("按键排序是可选的，不排序时保持原样解析出的顺序")
    func sortKeysIsOptIn() throws {
        let json = #"{"b":1,"a":2}"#

        #expect(try JSONFormatter.format(json, style: .minified, sortKeys: true).text == #"{"a":2,"b":1}"#)
    }

    // MARK: - 转义

    @Test("Java 字面量：外面带引号，里面的引号转义")
    func javaLiteralIsPasteable() throws {
        let result = try JSONFormatter.format(#"{"a":1}"#, style: .javaLiteral).text

        #expect(result == #""{\"a\":1}""#)
    }

    @Test("从日志里复制的转义 JSON 会自动还原，并且说出来")
    func escapedInputIsRecovered() throws {
        let fromLog = #"{\"name\":\"张三\",\"age\":30}"#

        let result = try JSONFormatter.format(fromLog, style: .minified)
        #expect(result.repairs.contains(.unescaped))
        #expect(result.text == #"{"name":"张三","age":30}"#)
    }

    @Test("外面还包着一层引号的 Java 字面量也认")
    func quotedJavaLiteralIsRecovered() throws {
        let result = try JSONFormatter.format(#""{\"a\":1}""#, style: .minified)

        #expect(result.repairs.contains(.unquoted))
        #expect(result.text == #"{"a":1}"#)
    }

    @Test("正常的 JSON 不该被标成动过手脚")
    func plainInputNeedsNoRepairs() throws {
        #expect(try JSONFormatter.format(#"{"a":1}"#, style: .minified).repairs.isEmpty)
    }

    // MARK: - 中文标点
    //
    // 这一组的来历：输入框（NSTextView）默认开着智能引号替换，
    // **在里面打一个 \" 出来的是 “ 或 ”** —— 打出来的 JSON 自己解析不了。
    // 那个开关已经在 AppDelegate 里关掉了，但从聊天、文档、PPT 里粘进来的
    // 照样带中文引号，所以解析这一侧也得收下。

    @Test("中文引号自动换成直引号，并且说出来改了什么")
    func curlyQuotesAreRepairedAndReported() throws {
        let typed = "{\u{201C}name\u{201D}: \u{201C}lawrence\u{201D}}"

        let result = try JSONFormatter.format(typed, style: .minified)
        #expect(result.text == #"{"name":"lawrence"}"#)
        #expect(result.repairs.contains(.straightQuotes))
    }

    @Test("全角冒号和逗号在结构位置上会换成半角")
    func fullWidthPunctuationIsRepairedWhereItIsStructure() throws {
        let typed = "{\u{201C}a\u{201D}：1，\u{201C}b\u{201D}：2}"

        let result = try JSONFormatter.format(typed, style: .minified)
        #expect(result.text == #"{"a":1,"b":2}"#)
        #expect(result.repairs.contains(.fullWidthPunctuation))
    }

    /// 最要紧的一条：字符串**里面**的全角逗号是内容，不是语法。
    /// 换掉它 JSON 依然合法，但用户的数据被悄悄改了 —— 那种错误比解析失败难查得多。
    @Test("字符串里面的全角逗号一个字都不动")
    func fullWidthPunctuationInsideStringsIsLeftAlone() throws {
        let typed = "{\u{201C}msg\u{201D}：\u{201C}你好，世界：再见\u{201D}}"

        let result = try JSONFormatter.format(typed, style: .minified)
        #expect(result.text == #"{"msg":"你好，世界：再见"}"#)
    }

    @Test("字符串里的转义引号不会让「在不在字符串里」判断跑偏")
    func escapedQuotesDoNotConfuseTheScanner() {
        let text = #"{"a":"x\"y，z"，"b":1}"#

        // 第一个全角逗号在字符串里（留着），第二个在外面（换成半角）
        #expect(JSONFormatter.normalizePunctuation(text) == #"{"a":"x\"y，z","b":1}"#)
    }

    @Test("修不好的时候，报的是原始输入的错，不是修完之后那段的错")
    func unrepairableInputReportsTheOriginalError() {
        // 中文引号 + 结构本身也是坏的
        let broken = "{\u{201C}a\u{201D} 1}"

        #expect(throws: (any Error).self) {
            try JSONFormatter.format(broken, style: .pretty)
        }
    }

    @Test("\\uXXXX 能还原成字符")
    func unicodeEscapesAreDecoded() {
        #expect(JSONFormatter.unescape(#"\u4e2d\u6587"#) == "中文")
    }

    @Test("不认识的转义原样留着，别吞掉用户的字符")
    func unknownEscapesAreKept() {
        #expect(JSONFormatter.unescape(#"a\qb"#) == #"a\qb"#)
        #expect(JSONFormatter.unescape(#"C:\Program\x"#) == #"C:\Program\x"#)
    }

    /// 没法解决的歧义，写成测试钉住现状：`\n` 一定是换行。
    /// 光看字符串没办法知道它原本是不是 Windows 路径里的 `\name`。
    @Test("\\n 永远当换行 —— 这条歧义没得选")
    func backslashNIsAlwaysANewline() {
        // 右边这个是普通字符串字面量，`\n` 在 Swift 里也是换行 —— 两边正好对上
        #expect(JSONFormatter.unescape(#"C:\name"#) == "C:\name")
    }

    @Test("转义再还原回得来")
    func escapeRoundTrips() {
        let original = "{\"s\":\"a\\nb\t\"}"

        #expect(JSONFormatter.unescape(JSONFormatter.javaLiteral(original)) == original)
    }

    // MARK: - 错误

    @Test("空输入和坏 JSON 是两种提示")
    func emptyAndInvalidAreDifferent() {
        #expect(throws: JSONFormatter.Failure.empty) {
            try JSONFormatter.format("  \n ", style: .pretty)
        }
        #expect(throws: (any Error).self) {
            try JSONFormatter.format(#"{"a" 1}"#, style: .pretty)
        }
    }

    @Test("坏 JSON 要指出坏在哪儿，不只是「格式不对」")
    func invalidJSONCarriesAnExcerpt() {
        do {
            _ = try JSONFormatter.format(#"{"name":"a","age" 32}"#, style: .pretty)
            Issue.record("这段 JSON 是坏的，不该解析成功")
        } catch let failure as JSONFormatter.Failure {
            #expect(failure.message.contains("column"))
            #expect(failure.excerpt?.contains("▶") == true)
            #expect(failure.excerpt?.contains("32") == true)
        } catch {
            Issue.record("类型不对：\(error)")
        }
    }

    @Test("多行 JSON 里出错，位置也要算对（行列要换算成全局偏移）")
    func multilineErrorsResolveTheRightSpot() {
        let broken = "{\n  \"a\": 1,\n  \"b\" 2\n}"
        do {
            _ = try JSONFormatter.format(broken, style: .pretty)
            Issue.record("这段 JSON 是坏的")
        } catch let failure as JSONFormatter.Failure {
            // ▶ 应该落在第三行那个漏了冒号的地方，而不是第一行
            #expect(failure.excerpt?.contains("\"b\"") == true)
        } catch {
            Issue.record("类型不对：\(error)")
        }
    }

    @Test("出错位置用 ▶ 标出来，前后各留一截")
    func excerptMarksThePosition() {
        let raw = #"{"name":"a","age" 32}"#
        let excerpt = JSONFormatter.excerpt(raw, around: 17, radius: 8)

        #expect(excerpt?.contains("▶") == true)
        #expect(excerpt?.contains("32") == true)
    }

    @Test("偏移落在汉字中间时退回字符边界，不切出乱码")
    func excerptSnapsToCharacterBoundaries() {
        let raw = "中文中文中文"
        // 4 落在第二个汉字的中间（每个汉字 3 字节）
        let excerpt = JSONFormatter.excerpt(raw, around: 4, radius: 6)

        #expect(excerpt?.contains("\u{FFFD}") == false)
    }

    @Test("中文不会被切成乱码 —— 按 UTF-8 边界退回去")
    func excerptRespectsUTF8Boundaries() {
        let raw = #"{"名字":"张三张三张三","年龄":30}"#
        // 12 落在某个汉字的中间
        let excerpt = JSONFormatter.excerpt(raw, around: 12, radius: 6)

        #expect(excerpt?.contains("\u{FFFD}") == false)
    }
}
