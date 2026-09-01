import Foundation
import Observation

/// 编解码工具的状态。逻辑全在 `Codec` 里（纯函数、可测），
/// 这里只管「用户选了什么」和「结果该怎么摆」。
@MainActor
@Observable
public final class CodecModel {

    public enum Direction: String, CaseIterable, Identifiable, Hashable, Sendable {
        case encode
        case decode

        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .encode: "编码"
            case .decode: "解码"
            }
        }
    }

    /// 结果的四种形态。**「解出来不是文本」不是错误** ——
    /// Base64 里装着图片或密文是再正常不过的事，那时候要给的是十六进制预览，
    /// 不是一屏问号，更不是一句「解码失败」。
    public enum Output: Equatable {
        case empty
        case text(String)
        case binary(Data)
        case failure(String)
    }

    public var input = ""
    public var direction: Direction = .encode
    public var format: Codec.Format = .base64

    public init() {}

    public var output: Output {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .empty }
        switch direction {
        case .encode:
            return .text(Codec.encode(input, as: format))
        case .decode:
            do {
                let decoded = try Codec.decode(input, from: format)
                if let text = decoded.text { return .text(text) }
                return .binary(decoded.bytes)
            } catch let failure as Codec.Failure {
                return .failure(failure.message)
            } catch {
                return .failure("解码失败。")
            }
        }
    }

    /// 把结果灌回输入并反转方向。
    /// 「编码完想验一下能不能解回来」是这个工具最常见的第二步。
    public func swapDirection() {
        if case .text(let value) = output { input = value }
        direction = direction == .encode ? .decode : .encode
    }
}
