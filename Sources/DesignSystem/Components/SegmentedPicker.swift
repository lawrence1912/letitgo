import SwiftUI

/// 通用分段控件。选中状态立即切换，不对整组控件或页面做淡入淡出。
/// 每一项保留真实按钮、键盘操作及辅助功能的选中语义。
public struct SegmentedPicker<Option: Hashable & Identifiable>: View {
    @Binding private var selection: Option
    private let options: [Option]
    private let title: (Option) -> String
    private let label: String

    /// - Parameter label: 整组的名字，给 VoiceOver 用（「格式，Base64，已选中」）。
    public init(
        _ label: String,
        options: [Option],
        selection: Binding<Option>,
        title: @escaping (Option) -> String
    ) {
        self.label = label
        self.options = options
        self._selection = selection
        self.title = title
    }

    public var body: some View {
        SegmentTrack(label: label) {
            ForEach(options) { option in
                SegmentItem(
                    name: title(option),
                    isSelected: selection == option
                ) {
                    selection = option
                } label: {
                    Text(title(option))
                }
            }
        }
    }
}

// MARK: - 零件
//
// 槽、滑块、尺寸、动画、辅助功能结构都在这儿。应用里有两个分段控件
// （工具页的选项、外观切换），共用这一套 —— 上一版是各写各的，
// 结果是同屏两种高度、两种字号。

extension Theme.Size {
    /// 一个分段的高度。和 `ActionButtonStyle.Size.compact` 同高，
    /// 这样一行里并排放按钮和分段时上下沿是齐的。
    public static let segment: CGFloat = 26
    /// 槽和分段之间那圈内边距。滑块就在这圈里滑。
    public static let segmentInset: CGFloat = 3
}

/// 分段控件的槽：一条**凹进去**的胶囊，滑块在里面滑。
///
/// 槽使用稳定底色，分段按钮的下沿与投影负责表达高度。
public struct SegmentTrack<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    public init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: 2) { content }
            .padding(.horizontal, Theme.Size.segmentInset)
            .background {
                Capsule(style: .continuous)
                    .fill(Theme.Surface.well)
                    .frame(height: Theme.Size.segment + 2 * Theme.Size.segmentInset)
                    .overlay { Capsule().strokeBorder(Theme.Line.hairline, lineWidth: 1) }
                    .allowsHitTesting(false)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(label)
    }
}

/// 槽里的一个分段。真 `Button` —— 点击、Tab、⏎ / 空格、VoiceOver 的按钮角色
/// 全是系统给的，一样没丢。
public struct SegmentItem<Label: View>: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let label: Label

    @State private var isHovering = false

    public init(
        name: String,
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.name = name
        self.isSelected = isSelected
        self.action = action
        self.label = label()
    }

    public var body: some View {
        Button(action: action) {
            label
                .font(Theme.Typo.label.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? ControlLighting.foreground(emphasized: true) : Theme.Ink.secondary)
                .padding(.horizontal, Theme.Spacing.md)
                .frame(minWidth: Theme.Size.minimumHitTarget)
                .frame(height: Theme.Size.segment)
                .background {
                    // 每个分段的面始终存在，选中仅替换配色，不插入或删除材质层。
                    Capsule().fill(.clear)
                        .raisedControl(in: Capsule(), emphasized: isSelected)
                        .overlay { Capsule().strokeBorder(isHovering ? Theme.Line.strong : .clear, lineWidth: 1) }
                }
                .contentShape(.focusEffect, Capsule(style: .continuous))
                .frame(minHeight: Theme.Size.minimumHitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(CardButtonStyle())
        .onHover { isHovering = $0 }
        .transaction { $0.animation = nil }
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
