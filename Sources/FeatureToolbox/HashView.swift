import DesignSystem
import SwiftUI

/// MD5 / SHA-1 / SHA-256 / SHA-512。
public struct HashView: View {
    @State private var model = HashModel()

    public init() {}

    public var body: some View {
        ToolPage {
            options
            ToolNote("文本按 UTF-8 取字节。Java 那边 s.getBytes() 用平台默认字符集（中文 Windows 上是 GBK），要写 getBytes(StandardCharsets.UTF_8) 才对得上")
            ToolInput(title: "输入", placeholder: "要算摘要的文本", text: $model.input)
            results
        }
    }

    private var options: some View {
        HStack(spacing: Theme.Spacing.md) {
            SegmentedPicker(
                "大小写",
                options: HashModel.HexCase.allCases,
                selection: $model.hexCase,
                title: \.title
            )
            Spacer(minLength: Theme.Spacing.sm)
            Text("UTF-8 · \(model.byteCount) 字节")
                .font(Theme.Typo.numeric)
                .foregroundStyle(Theme.Ink.tertiary)
        }
    }

    @ViewBuilder
    private var results: some View {
        if model.input.isEmpty {
            // 空输入也是有摘要的（d41d8c… 那串），但摆出来只会让人以为
            // 自己已经输入过了。空态更诚实。
            EmptyStateView(
                systemImage: "number",
                title: "上面输入点什么",
                message: "四个算法会一次全算出来。"
            )
            .frame(minHeight: 140)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(model.digests.enumerated()), id: \.element.algorithm) { index, entry in
                    if index > 0 { Hairline() }
                    ResultRow(
                        label: entry.algorithm.title,
                        value: entry.hex,
                        detail: entry.algorithm.caution
                    )
                }
            }
            .panel()
        }
    }
}
