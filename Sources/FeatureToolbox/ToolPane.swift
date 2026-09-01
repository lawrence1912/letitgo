import AppKit
import DesignSystem
import SwiftUI

// 三个工具共用的骨架：一条选项栏 + 一个输入区 + 一片结果。
// 拆成三个模块的话这套东西要抄三遍，所以它们同住一个模块。

/// 工具页的外框：统一的内边距，内容超长时能滚。
struct ToolPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                content
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
    }
}

/// 选项栏下面那行小字：说清楚这个选项**和 Java 那边的差别在哪**。
///
/// 这行字是这几个工具真正的价值。转换本身谁都会写，
/// 「URLEncoder 把空格编成 +」这种事才是每次都要重新查一遍的。
struct ToolNote: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(Theme.Typo.caption)
            .foregroundStyle(Theme.Ink.tertiary)
            .textSelection(.enabled)
    }
}

/// 可输入的文本区。
///
/// 用原生 `TextEditor`，只换外框 —— 输入法、撤销、拖放、VoiceOver 全在它本体里，
/// 自绘一个要连这些一起重做，大概率漏掉其中一样。
struct ToolInput: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 96

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(title)
                    .font(Theme.Typo.label)
                    .foregroundStyle(Theme.Ink.secondary)
                Spacer()
                if !text.isEmpty {
                    Text("\(text.count) 字符 · \(Data(text.utf8).count) 字节")
                        .font(Theme.Typo.caption)
                        .foregroundStyle(Theme.Ink.tertiary)
                    Button("清空") { text = "" }
                        .buttonStyle(.ghostAction(size: .compact))
                }
            }

            TextEditor(text: $text)
                .font(Theme.Typo.mono)
                .foregroundStyle(Theme.Ink.primary)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, Theme.Spacing.xs)
                .padding(.vertical, Theme.Spacing.xs)
                .frame(minHeight: minHeight)
                .panel(.well, radius: Theme.Radius.control, rim: isFocused ? Theme.Brand.accent : nil)
                .overlay(alignment: .topLeading) {
                    // `TextEditor` 没有 placeholder，自己叠一层。
                    // 它不接受点击，否则会挡住第一次点进去的那一下。
                    if text.isEmpty {
                        Text(placeholder)
                            .font(Theme.Typo.mono)
                            .foregroundStyle(Theme.Ink.tertiary)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, Theme.Spacing.sm)
                            .allowsHitTesting(false)
                    }
                }
                .focused($isFocused)
                // placeholder 不算 label：用户一输入内容它就没了，
                // 控件随即变成无名的「文本栏」。
                .accessibilityLabel(title)
        }
    }
}

/// 只读的结果区。用 `Text` 而不是禁用的 `TextEditor` ——
/// 后者会显示一个不能动的光标，读起来像「这里本来能输入但坏了」。
struct ToolOutput: View {
    let title: String
    let value: String
    var caption: String?
    var minHeight: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(title)
                    .font(Theme.Typo.label)
                    .foregroundStyle(Theme.Ink.secondary)
                if let caption {
                    Text(caption)
                        .font(Theme.Typo.caption)
                        .foregroundStyle(Theme.Ink.tertiary)
                }
                Spacer()
                CopyButton(value)
            }

            ScrollView {
                Text(value)
                    .font(Theme.Typo.mono)
                    .foregroundStyle(Theme.Ink.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.sm)
            }
            .frame(minHeight: minHeight)
            .panel(.well, radius: Theme.Radius.control)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title)：\(value)")
        }
    }
}

/// 结果表里的一行：左边名字，右边等宽的值，末尾一个复制。
struct ResultRow: View {
    let label: String
    let value: String
    /// 副标题：时区的完整标识符、算法的「别拿来防篡改」提醒之类。
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(Theme.Typo.label)
                    .foregroundStyle(Theme.Ink.secondary)
                if let detail {
                    Text(detail)
                        .font(Theme.Typo.caption)
                        .foregroundStyle(Theme.Ink.tertiary)
                }
            }
            .frame(width: 116, alignment: .leading)

            Text(value)
                .font(Theme.Typo.mono)
                .foregroundStyle(Theme.Ink.primary)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            CopyButton(value)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

/// 复制按钮。按下去之后变成对勾停两秒 ——
/// 剪贴板是没有反馈的，不给个回执用户会怀疑自己没点上，然后再点一次。
///
/// 两种形态：默认是纯图标（结果行末尾那种，一列排下来不能太吵）；
/// 给了 `title` 就是带字的幽灵按钮 —— 一排图标里混着一个「复制全部」时，
/// 光靠图标分不出哪个是哪个。
struct CopyButton: View {
    private let value: String
    private let title: String?
    @State private var justCopied = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ value: String, title: String? = nil) {
        self.value = value
        self.title = title
    }

    var body: some View {
        Group {
            if let title {
                Button(action: copy) {
                    Label(justCopied ? "已复制" : title, systemImage: symbol)
                }
                .buttonStyle(.ghostAction(size: .compact))
            } else {
                Button(action: copy) {
                    Image(systemName: symbol)
                }
                .buttonStyle(.icon(size: 22, tone: justCopied ? .success : .neutral))
            }
        }
        .disabled(value.isEmpty)
        .animation(Theme.Motion.fast(reduceMotion: reduceMotion), value: justCopied)
        // 纯图标按钮必须显式给名字。状态也要念出来 —— 对勾对 VoiceOver 不存在。
        .accessibilityLabel(justCopied ? "已复制" : (title ?? "复制"))
        .help(title ?? "复制")
    }

    private var symbol: String {
        justCopied ? "checkmark" : "doc.on.doc"
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        justCopied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            justCopied = false
        }
    }
}
