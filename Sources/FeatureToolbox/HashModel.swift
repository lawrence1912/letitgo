import Foundation
import Observation

/// 哈希工具的状态。四个算法一次全算 —— 它们都很快，
/// 而「我要的是哪一个」经常是看到结果才想起来的。
@MainActor
@Observable
public final class HashModel {

    public enum HexCase: String, CaseIterable, Identifiable, Hashable, Sendable {
        case lower
        case upper

        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .lower: "小写"
            case .upper: "大写"
            }
        }
    }

    public var input = ""
    public var hexCase: HexCase = .lower

    public init() {}

    public var byteCount: Int { Data(input.utf8).count }

    public var digests: [(algorithm: Digest.Algorithm, hex: String)] {
        Digest.Algorithm.allCases.map {
            ($0, Digest.hex(input, $0, uppercase: hexCase == .upper))
        }
    }
}
