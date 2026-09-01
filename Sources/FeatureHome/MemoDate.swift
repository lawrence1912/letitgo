import Foundation

/// 卡片页脚上的那行时间。
///
/// 为什么不用 `Date.FormatStyle`：它跟着系统区域设置走，同一条备忘在别人
/// 机器上会长成 `8/30/26` 或 `30.08.2026`，而这个界面其余每一个字都是写死的中文
/// —— 混在一起更难读，也写不了用例。这里自己拼，拼出来的东西在哪台机器上都一样。
///
/// 「今天 / 昨天」不是装饰：备忘绝大多数是今天写的，一屏卡片上如果全是
/// `8月30日`，日期这一列就等于没有信息 —— 眼睛真正要区分的是「刚写的」和「以前写的」。
enum MemoDate {

    /// - Parameters:
    ///   - date: 备忘写下的时间。
    ///   - now: 「今天」是哪天由调用方给 —— 测试里才能把时间钉死。
    ///   - calendar: 同上，用例里换成固定时区的日历。
    static func label(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let time = clock(date, calendar)

        if calendar.isDate(date, inSameDayAs: now) {
            return "今天 \(time)"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "昨天 \(time)"
        }

        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else {
            return time
        }
        // 跨年的备忘不显示时分：隔了一年再看，「几点写的」已经没有意义，
        // 而年份有。省下来的宽度留给标题。
        guard year == calendar.component(.year, from: now) else {
            return "\(year)年\(month)月\(day)日"
        }
        return "\(month)月\(day)日 \(time)"
    }

    /// 24 小时制、补零。配等宽数字用 —— 一列卡片的时间要对得齐，
    /// `9:05` 和 `09:05` 混排会看着像没对齐的表格。
    private static func clock(_ date: Date, _ calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
}
