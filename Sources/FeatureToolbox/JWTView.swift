import DesignSystem
import SwiftUI

/// JWT 拆解与验签。
public struct JWTView: View {
    @State private var model = JWTModel()

    public init() {}

    public var body: some View {
        @Bindable var model = model

        ToolPage {
            ToolInput(
                title: "Token",
                placeholder: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.… —— 开头带 Bearer 也行",
                text: $model.token,
                minHeight: 88
            )

            ToolNote("整段在本机跑，不发任何请求 —— 生产环境的 access token 粘网页版工具里，等于把一份还没过期的凭证交出去了")

            switch model.decoded {
            case nil:
                EmptyStateView(
                    systemImage: "key.horizontal",
                    title: "上面粘一个 token",
                    message: "会拆成 header / payload，并把 exp、iat 换算成能读的时间。"
                )
                .frame(minHeight: 140)

            case .failure(let failure):
                NoticeView(.danger, title: "拆不开", message: failure.message)

            case .success(let decoded):
                summary(decoded)
                ToolOutput(title: "Header", value: decoded.header, minHeight: 72)
                ToolOutput(title: "Payload", value: decoded.payload, minHeight: 140)
                times(decoded)
                signature(decoded)
            }
        }
    }

    /// 算法和有效期。有效期是这个工具最常被用来回答的那个问题
    /// （「这个 token 是不是已经过期了」），所以摆在最上面。
    private func summary(_ decoded: JWT.Decoded) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            if let algorithm = decoded.algorithm {
                Badge(algorithm, tone: .neutral, systemImage: "signature", size: .compact)
            }
            if let type = decoded.type {
                Badge(type, tone: .neutral, size: .compact)
            }
            if let validity = model.validity {
                Badge(
                    validityTitle(validity),
                    tone: validityTone(validity),
                    systemImage: validityIcon(validity),
                    size: .compact
                )
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func times(_ decoded: JWT.Decoded) -> some View {
        let rows = model.rows(for: decoded)
        if !rows.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.claim.id) { index, row in
                    if index > 0 { Hairline() }
                    ResultRow(
                        label: row.claim.name,
                        value: "\(row.absolute)   \(row.relative)",
                        detail: row.claim.meaning
                    )
                }
            }
            .panel()
        }
    }

    private func signature(_ decoded: JWT.Decoded) -> some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text("签名")
                    .font(Theme.Typo.label)
                    .foregroundStyle(Theme.Ink.secondary)
                Spacer()
                if let verification = model.verification {
                    Badge(
                        verification.message,
                        tone: verificationTone(verification),
                        systemImage: verificationIcon(verification),
                        size: .compact
                    )
                }
            }

            SecureField("HMAC 密钥", text: $model.secret)
                .textFieldStyle(.plain)
                .font(Theme.Typo.mono)
                .foregroundStyle(Theme.Ink.primary)
                .padding(.horizontal, Theme.Spacing.sm)
                .frame(height: 30)
                .panel(.well, radius: Theme.Radius.control)
                // placeholder 不算 label —— 一输入内容它就没了。
                .accessibilityLabel("HMAC 密钥")
        }
    }

    // MARK: - 状态映射

    private func validityTitle(_ validity: JWT.Validity) -> String {
        switch validity {
        case .noExpiry: "没有 exp"
        case .valid(let remaining): "还有 \(duration(remaining))"
        case .expired(let ago): "已过期 \(duration(ago))"
        case .notYetValid(let interval): "\(duration(interval))后才生效"
        }
    }

    private func validityTone(_ validity: JWT.Validity) -> Tone {
        switch validity {
        case .noExpiry: .neutral
        case .valid: .success
        case .expired: .danger
        case .notYetValid: .accent
        }
    }

    private func validityIcon(_ validity: JWT.Validity) -> String {
        switch validity {
        case .noExpiry: "infinity"
        case .valid: "checkmark"
        case .expired: "exclamationmark.triangle"
        case .notYetValid: "clock"
        }
    }

    private func verificationTone(_ verification: JWT.Verification) -> Tone {
        switch verification {
        case .noSecret, .unsupported: .neutral
        case .valid: .success
        case .invalid: .danger
        }
    }

    private func verificationIcon(_ verification: JWT.Verification) -> String {
        switch verification {
        case .noSecret: "key"
        case .unsupported: "questionmark.circle"
        case .valid: "checkmark.seal"
        case .invalid: "xmark.seal"
        }
    }

    /// 「3 天」「4 小时」这种量级就够了 —— 秒级精度对判断过期没用。
    private func duration(_ interval: TimeInterval) -> String {
        let seconds = Int(interval.rounded())
        return switch seconds {
        case ..<60: "\(seconds) 秒"
        case ..<3600: "\(seconds / 60) 分钟"
        case ..<86400: "\(seconds / 3600) 小时"
        default: "\(seconds / 86400) 天"
        }
    }
}
