import DesignSystem
import SwiftUI

/// JSON 格式化 / 压缩 / 转义。
public struct JSONView: View {
    @State private var model = JSONModel()

    public init() {}

    public var body: some View {
        @Bindable var model = model

        ToolPage {
            HStack(spacing: Theme.Spacing.md) {
                SegmentedPicker(
                    "输出",
                    options: JSONFormatter.Style.allCases,
                    selection: $model.style,
                    title: \.title
                )
                Toggle("按键排序", isOn: $model.sortKeys)
                    .toggleStyle(.checkbox)
                    .font(Theme.Typo.body)
                    .foregroundStyle(Theme.Ink.primary)
                Spacer(minLength: Theme.Spacing.sm)
            }

            ToolNote("转义过的 JSON（引号是 \\\"）和中文引号（“ ”）都会自动认出来并修好，修了什么会写在输入框上面；「Java 字面量」是反过来那一步，改完直接粘回代码")

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                // 为了能解析而动过的地方，一条条摆出来 ——
                // 悄悄「帮你修好」是最难查的一类行为：用户会以为原始数据是好的，
                // 直到它在别处又炸一次。
                if case .success(let formatted) = model.result, !formatted.repairs.isEmpty {
                    HStack(spacing: Theme.Spacing.xs) {
                        ForEach(formatted.repairs, id: \.self) { repair in
                            Badge(repair.title, tone: .info, systemImage: "wand.and.stars", size: .compact)
                        }
                        Spacer(minLength: 0)
                    }
                }
                ToolInput(
                    title: "输入",
                    placeholder: #"{"name":"张三"} —— 带 \" 或者中文引号的也直接粘"#,
                    text: $model.input,
                    minHeight: 120
                )
            }

            output
        }
    }

    @ViewBuilder
    private var output: some View {
        if model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            EmptyStateView(
                systemImage: "curlybraces",
                title: "上面粘一段 JSON",
                message: "格式化是实时的，不用点按钮。"
            )
            .frame(minHeight: 140)
        } else {
            switch model.result {
            case .success(let formatted):
                ToolOutput(
                    title: model.style.title,
                    value: formatted.text,
                    caption: "\(Data(formatted.text.utf8).count) 字节",
                    minHeight: 160
                )

            case .failure(let failure):
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    NoticeView(.danger, title: "解析不了", message: failure.message)
                    if let excerpt = failure.excerpt {
                        // ▶ 指着出错的位置。等宽字体，前后各留一截上下文。
                        Text(excerpt)
                            .font(Theme.Typo.mono)
                            .foregroundStyle(Theme.Ink.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Theme.Spacing.sm)
                            .panel(.well, radius: Theme.Radius.control)
                    }
                }
            }
        }
    }
}
