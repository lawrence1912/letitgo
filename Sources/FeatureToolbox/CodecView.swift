import DesignSystem
import SwiftUI

/// Base64 / URL / 十六进制的编解码。
public struct CodecView: View {
    @State private var model = CodecModel()

    public init() {}

    public var body: some View {
        ToolPage {
            options
            ToolNote(model.format.note)
            ToolInput(
                title: model.direction == .encode ? "原文" : "密文 / 编码后的串",
                placeholder: model.direction == .encode ? "要编码的文本" : "粘贴进来 —— 少了 = 或者带着换行都没关系",
                text: $model.input
            )
            output
        }
    }

    private var options: some View {
        HStack(spacing: Theme.Spacing.md) {
            SegmentedPicker(
                "方向",
                options: CodecModel.Direction.allCases,
                selection: $model.direction,
                title: \.title
            )
            SegmentedPicker(
                "格式",
                options: Codec.Format.allCases,
                selection: $model.format,
                title: \.title
            )
            Spacer(minLength: Theme.Spacing.sm)
            Button {
                model.swapDirection()
            } label: {
                Label("反向", systemImage: "arrow.up.arrow.down")
            }
            .buttonStyle(.secondaryAction(size: .compact))
            .help("把结果放回输入框，方向反过来 —— 用来验一遍能不能转回去")
        }
    }

    @ViewBuilder
    private var output: some View {
        switch model.output {
        case .empty:
            // 空态不摆一个空框：那看着像坏了。
            EmptyStateView(
                systemImage: "arrow.left.arrow.right",
                title: "上面输入点什么",
                message: "结果会实时出现在这里，不用点转换。"
            )
            .frame(minHeight: 140)

        case .text(let value):
            ToolOutput(
                title: model.direction == .encode ? "编码结果" : "解码结果",
                value: value,
                caption: "\(Data(value.utf8).count) 字节"
            )

        case .binary(let bytes):
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                NoticeView(
                    .info,
                    title: "解出来的不是 UTF-8 文本",
                    message: "共 \(bytes.count) 字节。这不一定是出错 —— Base64 里装图片、密文、序列化对象都很常见。下面是十六进制预览。"
                )
                ToolOutput(title: "十六进制", value: Codec.hexDump(bytes), minHeight: 140)
            }

        case .failure(let message):
            NoticeView(.danger, title: "解不开", message: message)
        }
    }
}
