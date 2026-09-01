import Foundation
import Observation

/// 时间戳工具的状态。
@MainActor
@Observable
public final class TimestampModel {

    public enum ZoneChoice: String, CaseIterable, Identifiable, Hashable, Sendable {
        case local
        case utc

        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .local: "本地"
            case .utc: "UTC"
            }
        }
    }

    public var input: String
    public var unit: TimeConversion.Unit = .auto
    public var zoneChoice: ZoneChoice = .local

    private let now: @Sendable () -> Date

    /// 一进来就填上当前毫秒数。空着的页面要用户先想「我该输入什么」，
    /// 填好的页面直接就是个答案 —— 而「现在几点的时间戳」本身就是最常问的一个。
    public init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
        self.input = String(Int(now().timeIntervalSince1970 * 1000))
    }

    public var zone: TimeZone {
        switch zoneChoice {
        case .local: .current
        case .utc: .gmt
        }
    }

    public var parsed: Result<TimeConversion.Parsed, TimeConversion.Failure> {
        do {
            return .success(try TimeConversion.parse(input, unit: unit, zone: zone))
        } catch let failure as TimeConversion.Failure {
            return .failure(failure)
        } catch {
            return .failure(.unrecognized)
        }
    }

    public var rows: [TimeConversion.Row] {
        guard case .success(let parsed) = parsed else { return [] }
        return TimeConversion.rows(for: parsed.date, zone: zone, now: now())
    }

    public func fillWithNow() {
        input = String(Int(now().timeIntervalSince1970 * 1000))
        unit = .auto
    }
}
