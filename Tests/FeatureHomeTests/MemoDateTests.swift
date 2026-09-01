import Foundation
import Testing
@testable import FeatureHome

/// 卡片页脚那行时间的用例。
///
/// 「今天」是相对的，所以 `now` 和日历都从外面给 —— 这几条才不会
/// 跑到明天就红，也不会因为跑在别的时区上而红。
@Suite("备忘时间")
struct MemoDateTests {

    /// 固定时区，跟本机设置无关。
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!   // UTC+8，无夏令时
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        )!
    }

    private func label(_ date: Date, now: Date) -> String {
        MemoDate.label(for: date, now: now, calendar: calendar)
    }

    @Test("今天写的显示「今天 时:分」")
    func today() {
        let now = date(2026, 8, 30, 20, 0)
        #expect(label(date(2026, 8, 30, 9, 5), now: now) == "今天 09:05")
    }

    @Test("昨天写的显示「昨天 时:分」，跨月也算得对")
    func yesterday() {
        #expect(
            label(date(2026, 8, 29, 23, 59), now: date(2026, 8, 30, 20, 0)) == "昨天 23:59"
        )
        // 8 月 31 日 → 9 月 1 日：减一天不能靠「日期数字减一」。
        #expect(
            label(date(2026, 8, 31, 23, 50), now: date(2026, 9, 1, 0, 30)) == "昨天 23:50"
        )
    }

    @Test("同一年里的旧备忘显示「月日 时:分」")
    func earlierThisYear() {
        let now = date(2026, 8, 30, 20, 0)
        #expect(label(date(2026, 8, 1, 7, 0), now: now) == "8月1日 07:00")
    }

    @Test("跨年的备忘只到日 —— 隔了一年，几点写的已经没意义了")
    func previousYear() {
        let now = date(2026, 8, 30, 20, 0)
        #expect(label(date(2025, 12, 31, 23, 30), now: now) == "2025年12月31日")
    }

    @Test("时分补零，一列卡片的时间才对得齐")
    func padsClock() {
        let now = date(2026, 8, 30, 20, 0)
        #expect(label(date(2026, 8, 30, 0, 0), now: now) == "今天 00:00")
    }
}
