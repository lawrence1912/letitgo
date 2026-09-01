import Foundation
import Testing

@testable import FeatureToolbox

@Suite("时间戳")
struct TimeConversionTests {
    private let utc = TimeZone.gmt
    /// 2023-11-14 22:13:20 UTC
    private let reference = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - 秒还是毫秒

    @Test("十位当秒读，十三位当毫秒读 —— 两者指向同一时刻")
    func autoDetectionMapsBothFormsToTheSameInstant() throws {
        let seconds = try TimeConversion.parse("1700000000", unit: .auto, zone: utc)
        let millis = try TimeConversion.parse("1700000000000", unit: .auto, zone: utc)

        #expect(seconds.source == .epochSeconds)
        #expect(millis.source == .epochMilliseconds)
        #expect(seconds.date == millis.date)
        #expect(seconds.date == reference)
    }

    @Test("量级判断的两侧都要对：阈值之下算秒，之上算毫秒")
    func thresholdSplitsSecondsFromMilliseconds() throws {
        let below = String(Int(TimeConversion.millisecondThreshold) - 1)
        let above = String(Int(TimeConversion.millisecondThreshold))

        #expect(try TimeConversion.parse(below, unit: .auto, zone: utc).source == .epochSeconds)
        #expect(try TimeConversion.parse(above, unit: .auto, zone: utc).source == .epochMilliseconds)
    }

    @Test("1970 年之前的负时间戳不会被位数骗过去")
    func negativeTimestampsAreStillSeconds() throws {
        let parsed = try TimeConversion.parse("-86400", unit: .auto, zone: utc)

        #expect(parsed.source == .epochSeconds)
        #expect(parsed.date == Date(timeIntervalSince1970: -86_400))
    }

    @Test("手动指定单位时不再猜")
    func explicitUnitOverridesDetection() throws {
        let asMillis = try TimeConversion.parse("1700000000", unit: .milliseconds, zone: utc)
        let asSeconds = try TimeConversion.parse("1700000000000", unit: .seconds, zone: utc)

        #expect(asMillis.source == .epochMilliseconds)
        #expect(asMillis.date == Date(timeIntervalSince1970: 1_700_000))
        #expect(asSeconds.source == .epochSeconds)
    }

    // MARK: - 日期字符串

    @Test("常见的几种日期写法都认")
    func recognisesTheUsualDateShapes() throws {
        for text in [
            "2023-11-14T22:13:20Z",
            "2023-11-14 22:13:20",
            "2023/11/14 22:13:20",
        ] {
            let parsed = try TimeConversion.parse(text, unit: .auto, zone: utc)
            #expect(parsed.date == reference, "\(text) 解出来不对")
        }
    }

    @Test("串里自带偏移时，以它为准，不看选中的时区")
    func explicitOffsetWinsOverTheSelectedZone() throws {
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        let parsed = try TimeConversion.parse("2023-11-14T22:13:20Z", unit: .auto, zone: tokyo)

        #expect(parsed.date == reference)
    }

    @Test("串里没有偏移时，按选中的时区读 —— 这正是 ZoneId 忘了指定的那个坑")
    func zonelessTextIsReadInTheSelectedZone() throws {
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!   // UTC+9，无夏令时
        let inUTC = try TimeConversion.parse("2023-11-14 22:13:20", unit: .auto, zone: utc)
        let inTokyo = try TimeConversion.parse("2023-11-14 22:13:20", unit: .auto, zone: tokyo)

        #expect(inUTC.date.timeIntervalSince(inTokyo.date) == 9 * 3600)
    }

    @Test("空输入和认不出来是两种提示")
    func emptyAndUnrecognisedAreDifferentFailures() {
        #expect(throws: TimeConversion.Failure.empty) {
            try TimeConversion.parse("   ", unit: .auto, zone: utc)
        }
        #expect(throws: TimeConversion.Failure.unrecognized) {
            try TimeConversion.parse("下午三点", unit: .auto, zone: utc)
        }
    }

    // MARK: - 输出

    @Test("秒和毫秒两行必须互相对得上")
    func secondsAndMillisecondsRowsAgree() {
        let rows = TimeConversion.rows(for: reference, zone: utc, now: reference)
        let seconds = rows.first { $0.label == "epoch 秒" }?.value
        let millis = rows.first { $0.label == "epoch 毫秒" }?.value

        #expect(seconds == "1700000000")
        #expect(millis == "1700000000000")
    }

    @Test("UTC 那一行永远是 UTC，本地那一行带完整时区标识")
    func utcRowIgnoresTheSelectedZone() {
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        let rows = TimeConversion.rows(for: reference, zone: tokyo, now: reference)
        let local = rows.first { $0.label == "本地" }

        #expect(rows.first { $0.label == "UTC" }?.value == "2023-11-14 22:13:20")
        #expect(local?.value == "2023-11-15 07:13:20")
        #expect(local?.detail == "Asia/Tokyo")
    }

    @Test("选中的就是 UTC 时不重复列一行本地时间")
    func utcSelectionDoesNotDuplicateTheLocalRow() {
        let rows = TimeConversion.rows(for: reference, zone: utc, now: reference)

        #expect(rows.contains { $0.label == "UTC" })
        #expect(!rows.contains { $0.label == "本地" })
    }
}
