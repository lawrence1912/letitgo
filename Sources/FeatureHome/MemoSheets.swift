import AppCore
import AppKit
import DesignSystem
import SwiftUI

/// 写一条新备忘。macOS 惯例：按钮在右下角，esc 取消。
///
/// 标题一行、正文一块 —— 和卡片上的排布一一对应，
/// 写的时候看到的层次就是之后在板上看到的层次。
struct NewMemoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""
    @FocusState private var focus: Field?

    let onCreate: (String, String) -> Void

    private enum Field: Hashable {
        case title
        case content
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("新建备忘")
                .font(Theme.Typo.title)
                .tracking(Theme.Typo.titleTracking)
                .foregroundStyle(Theme.Ink.primary)

            // 输入控件本身还是原生的（输入法、撤销、拖放、VoiceOver 全靠它们），
            // 只把外框换掉：`.plain` 去掉系统边框，焦点态自己画一圈强调色。
            TextField("标题", text: $title)
                .textFieldStyle(.plain)
                .font(Theme.Typo.body)
                .padding(.horizontal, Theme.Spacing.sm)
                .frame(height: 30)
                .panel(
                    .well,
                    radius: Theme.Radius.control,
                    rim: focus == .title ? Theme.Brand.accent : nil
                )
                .focused($focus, equals: .title)
                // ⏎ 在标题里是「写完了，去写正文」，不是「建」——
                // 一条只有标题的备忘按右下角的按钮建，路径同样只有一步。
                .onSubmit { focus = .content }
                // placeholder 不等于 label：空框时 VoiceOver 念的是占位文字，
                // 用户一输入内容占位就消失，控件随即变成无名的「文本栏」。
                .accessibilityLabel("标题")

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                TextEditor(text: $content)
                    .font(Theme.Typo.body)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, Theme.Spacing.xs)
                    .padding(.vertical, 6)
                    .frame(height: 132)
                    .panel(
                        .well,
                        radius: Theme.Radius.control,
                        rim: focus == .content ? Theme.Brand.accent : nil
                    )
                    .focused($focus, equals: .content)
                    .accessibilityLabel("正文")

                Text("正文可以不写 —— 一行标题也是一条备忘。")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.Ink.tertiary)
            }

            HStack(spacing: Theme.Spacing.sm) {
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(.secondaryAction)
                    .keyboardShortcut(.cancelAction)
                Button("新建", action: create)
                    .buttonStyle(.primaryAction)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedTitle.isEmpty)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(width: 380)
        // sheet 是独立窗口，自己带一份氛围底 + 浮层档的玻璃。
        .glassBackground(.floating)
        .ambientBackdrop()
        // 出现即聚焦标题，用户不用先点一下。
        .onAppear { focus = .title }
    }

    private func create() {
        guard !trimmedTitle.isEmpty else { return }
        onCreate(trimmedTitle, content)
        dismiss()
    }
}

/// 读一条备忘的全文。
///
/// 卡片上的正文是**截断**的（四行），所以必须有一个地方能看到完整内容 ——
/// 否则第五行往后的字等于写进去就丢了。双击卡片来这儿。
///
/// 只读：这个分区目前只能新建和删除，没有编辑。文字仍然可以选中复制，
/// 所以「读完把其中一段拿走」这条路是通的。
struct MemoReaderSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// 正文量出来的高度。初值给一个常见的两三行的高度，
    /// 免得 sheet 一出现就先跳一下。
    @State private var contentHeight: CGFloat = 96

    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(item.title)
                    .font(Theme.Typo.title)
                    .tracking(Theme.Typo.titleTracking)
                    .foregroundStyle(Theme.Ink.primary)
                    .textSelection(.enabled)

                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "clock")
                        .font(.system(size: 10, weight: .medium))
                        .accessibilityHidden(true)
                    Text(MemoDate.label(for: item.createdAt))
                        .font(Theme.Typo.numeric)
                }
                .foregroundStyle(Theme.Ink.secondary)
            }

            // 短备忘不撑高，长备忘滚动。
            //
            // `ScrollView` 会**吃掉给它的全部高度** —— 只写 `maxHeight: 320`
            // 的话，三行字也会撑出一个 320 高的空框。所以量一次正文的高度，
            // 框跟着它长，到 320 封顶之后才开始滚。
            ScrollView {
                Text(item.content.isEmpty ? "没有正文" : item.content)
                    .font(Theme.Typo.body)
                    .foregroundStyle(item.content.isEmpty ? Theme.Ink.tertiary : Theme.Ink.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.sm)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .frame(height: min(max(contentHeight, 72), 320))
            .panel(.well, radius: Theme.Radius.control)

            HStack(spacing: Theme.Spacing.sm) {
                Spacer()
                Button("拷贝", action: copy)
                    .buttonStyle(.secondaryAction)
                    .disabled(item.content.isEmpty)
                Button("关闭") { dismiss() }
                    .buttonStyle(.primaryAction)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(width: 420)
        .glassBackground(.floating)
        .ambientBackdrop()
    }

    /// 拷贝正文，不带标题 —— 拿走的一般是内容本身，标题是这个界面的事。
    private func copy() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
    }
}
