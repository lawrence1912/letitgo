import Foundation
import Observation

/// JWT 工具的状态。
@MainActor
@Observable
public final class JWTModel {
    public var token = ""
    public var secret = ""

    private let now: @Sendable () -> Date

    public init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
    }

    public var decoded: Result<JWT.Decoded, JWT.Failure>? {
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        do {
            return .success(try JWT.decode(token))
        } catch let failure as JWT.Failure {
            return .failure(failure)
        } catch {
            return .failure(.empty)
        }
    }

    public var validity: JWT.Validity? {
        guard case .success(let decoded) = decoded else { return nil }
        return JWT.validity(of: decoded, now: now())
    }

    public var verification: JWT.Verification? {
        guard case .success(let decoded) = decoded else { return nil }
        return JWT.verify(decoded, secret: secret)
    }

    /// 时间声明配上「距现在多久」。JWT 里全是 epoch 秒，光看数字没人算得出来。
    public func rows(for decoded: JWT.Decoded) -> [(claim: JWT.TimeClaim, absolute: String, relative: String)] {
        decoded.times.map { claim in
            let rows = TimeConversion.rows(for: claim.date, zone: .current, now: now())
            return (
                claim,
                rows.first { $0.label == "本地" }?.value
                    ?? rows.first { $0.label == "UTC" }?.value
                    ?? "",
                rows.first { $0.label == "距现在" }?.value ?? ""
            )
        }
    }
}
