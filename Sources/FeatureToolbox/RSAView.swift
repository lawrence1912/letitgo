import DesignSystem
import SwiftUI

/// RSA 加解密。
public struct RSAView: View {
    @State private var model = RSAModel()

    public init() {}

    public var body: some View {
        @Bindable var model = model

        ToolPage {
            HStack(spacing: Theme.Spacing.md) {
                SegmentedPicker(
                    "方向",
                    options: RSAModel.Mode.allCases,
                    selection: $model.options.mode,
                    title: \.title
                )
                SegmentedPicker(
                    "填充",
                    options: RSA.Padding.allCases,
                    selection: $model.options.padding,
                    title: \.title
                )
                Spacer(minLength: Theme.Spacing.sm)
            }

            ToolNote(model.options.padding.note)

            ToolInput(
                title: model.options.mode.keyTitle,
                placeholder: "-----BEGIN PUBLIC KEY-----  —— openssl 和 Java 吐出来的那种，直接粘",
                text: $model.options.key,
                minHeight: 104
            )

            // 生成器**紧跟着密钥框**，不放页面底部：手上没有密钥是打开这一页时
            // 最常见的状态，而放在底下会被上面的空态推到折叠线以下 ——
            // 需要它的人恰恰是看不到它的人。
            generator

            ToolInput(
                title: model.options.mode.inputTitle,
                placeholder: model.options.mode == .encrypt ? "要加密的文本" : "Base64 密文，带换行也没关系",
                text: $model.options.input,
                minHeight: 88
            )

            output
        }
        .onChange(of: model.options) { model.run() }
    }

    @ViewBuilder
    private var output: some View {
        switch model.output {
        case nil where model.options.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty:
            // 手上没密钥时，这一页真正的主操作是「生成一对」——
            // 空态里那个大按钮就是它。一屏只留一个响亮的按钮。
            EmptyStateView(
                systemImage: "lock.shield",
                title: "先要有一把密钥",
                message: "把 openssl 或 Java 那边的 PEM 粘到上面，或者直接生成一对来试。",
                action: .init(title: "生成一对密钥") {
                    Task { await model.generateKeyPair() }
                }
            )
            .frame(minHeight: 140)

        case nil:
            EmptyStateView(
                systemImage: "lock.shield",
                title: "再填上要处理的内容",
                message: "密钥有了。上面填好内容就会自动跑，不用点按钮。"
            )
            .frame(minHeight: 120)

        case .success(let text):
            ToolOutput(
                title: model.options.mode == .encrypt ? "密文（Base64）" : "明文",
                value: text,
                caption: "\(Data(text.utf8).count) 字节",
                minHeight: 96
            )

        case .failure(let failure):
            NoticeView(.danger, title: "跑不通", message: failure.message)
        }
    }

    private var generator: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.md) {
                SegmentedPicker(
                    "位数",
                    options: RSA.KeySize.allCases,
                    selection: $model.keySize,
                    title: \.title
                )

                Text("位")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Ink.tertiary)

                // 次要样式：主操作的名额给空态里那个大按钮。
                Button(model.generated == nil ? "生成一对" : "重新生成") {
                    Task { await model.generateKeyPair() }
                }
                .buttonStyle(.secondaryAction(size: .compact))
                .disabled(model.isGenerating)
                .help("生成 X.509 / PKCS#8 格式的密钥对 —— Java 那边直接能用")

                if model.isGenerating {
                    ProgressView().controlSize(.small)
                }

                Spacer(minLength: 0)
            }

            if let counterpart = model.counterpartKey {
                // 配套的那一半：加密时给对方私钥去解，解密时给对方公钥去加。
                // 生成完就摆在这儿，不用去别处找。
                ToolOutput(title: counterpart.title, value: counterpart.value, minHeight: 88)
            }
        }
    }
}
