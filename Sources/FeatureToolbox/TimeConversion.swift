import Foundation

/// 时间戳换算的纯函数。
///
/// ## 这个工具真正解决的问题
///
/// 不是「除以 1000」——是**你手上这串数字到底是秒还是毫秒**。
/// Java 里两种都天天出现：`System.currentTimeMillis()` 给毫秒，
/// `Instant.getEpochSecond()` / 数据库里的 `unix_timestamp` 给秒。
/// 猜错三个数量级，日期会落到 1970 年或者 5 万年后，而且看起来「像个日期」。
///
/// 所以默认按**量级**自动判断，并且把判断结果显式说出来（界面上写着
/// 「按毫秒读」），而不是默默转完了事。
public enum TimeConversion {

    public enum Unit: String, CaseIterable, Identifiable, Hashable, Sendable {
        case auto
        case seconds
        case milliseconds

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .auto: "自动"
            case .seconds: "秒"
            case .milliseconds: "毫秒"
            }
        }
    }

    /// 输入被当成什么读的。界面要把这个说出来。
    public enum Source: Equatable, Sendable {
        case epochSeconds
        case epochMilliseconds
        case text(String)

        public var label: String {
            switch self {
            case .epochSeconds: "按秒读"
            case .epochMilliseconds: "按毫秒读"
            case .text(let format): "按「\(format)」读"
            }
        }
    }

    public struct Parsed: Equatable, Sendable {
        public let date: Date
        public let source: Source
    }

    public enum Failure: Error, Equatable, Sendable {
        case empty
        case unrecognized

        public var message: String {
            switch self {
            case .empty: "输入点什么 —— 一个时间戳，或者一个日期。"
            case .unrecognized:
                "认不出来。数字会当成时间戳；日期支持 2026-08-30 14:30:00 / 2026-08-30T14:30:00Z 这类写法。"
            }
        }
    }

    /// 秒还是毫秒：按**量级**判断，不按位数 —— 位数对负数（1970 年之前）
    /// 和短时间戳都不成立。10^11 秒是公元 5138 年，10^11 毫秒是 1973 年，
    /// 这条线两边都安全。
    static let millisecondThreshold: Double = 1e11

    public static func parse(_ raw: String, unit: Unit, zone: TimeZone) throws -> Parsed {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw Failure.empty }

        // 纯数字（允许负号和一个小数点）→ 时间戳
        if let number = Double(trimmed), trimmed.allSatisfy({ $0.isNumber || $0 == "-" || $0 == "." }) {
            let treatAsMilliseconds = switch unit {
            case .auto: abs(number) >= millisecondThreshold
            case .seconds: false
            case .milliseconds: true
            }
            return Parsed(
                date: Date(timeIntervalSince1970: treatAsMilliseconds ? number / 1000 : number),
                source: treatAsMilliseconds ? .epochMilliseconds : .epochSeconds
            )
        }

        for (format, formatter) in textFormatters(zone: zone) {
            if let date = formatter.date(from: trimmed) {
                return Parsed(date: date, source: .text(format))
            }
        }
        throw Failure.unrecognized
    }

    /// 试过的写法，按「最可能」排序。带时区偏移的排在前面 ——
    /// 它自带答案，不需要靠选中的时区去猜。
    private static func textFormatters(zone: TimeZone) -> [(String, DateFormatter)] {
        [
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss.SSS",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy/MM/dd",
        ].map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = zone
            formatter.dateFormat = format
            return (format, formatter)
        }
    }

    // MARK: - 输出

    public struct Row: Identifiable, Equatable, Sendable {
        public let label: String
        public let value: String
        /// 副标题。时区那一行用它放完整标识符 —— `Asia/Kuala_Lumpur`
        /// 放进主标题会被截断成 `Asia/Kuala_Lu…`，那还不如不显示。
        public let detail: String?

        public init(label: String, value: String, detail: String? = nil) {
            self.label = label
            self.value = value
            self.detail = detail
        }

        public var id: String { label }
    }

    /// 一次把所有常用写法都摆出来 —— 用户来这儿就是为了拿其中某一个去粘贴，
    /// 让他再点一次「换成 ISO 格式」是多余的一步。
    public static func rows(for date: Date, zone: TimeZone, now: Date = Date()) -> [Row] {
        let seconds = date.timeIntervalSince1970
        var rows = [
            Row(label: "epoch 秒", value: String(Int(seconds.rounded(.down)))),
            Row(label: "epoch 毫秒", value: String(Int((seconds * 1000).rounded()))),
            Row(label: "ISO 8601", value: format(date, "yyyy-MM-dd'T'HH:mm:ssXXXXX", zone)),
        ]
        // 选中时区本身就是 UTC 时不重复列一行 —— 两行一模一样的值只会让人
        // 怀疑自己看错了。
        if zone.secondsFromGMT(for: date) != 0 {
            rows.append(
                Row(
                    label: "本地",
                    value: format(date, "yyyy-MM-dd HH:mm:ss", zone),
                    detail: zone.identifier
                )
            )
        }
        // UTC 永远占一行：跨时区对时间是这个工具最常被用到的场景，
        // 而 Java 那边 ZoneId 忘了指定就是默认时区，两头对不上的经典来源。
        rows.append(Row(label: "UTC", value: format(date, "yyyy-MM-dd HH:mm:ss", .gmt)))
        rows.append(Row(label: "距现在", value: relative(date, from: now)))
        return rows
    }

    private static func format(_ date: Date, _ pattern: String, _ zone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = zone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    private static func relative(_ date: Date, from now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }
}
