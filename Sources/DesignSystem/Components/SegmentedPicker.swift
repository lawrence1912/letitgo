import SwiftUI

/// 通用分段控件：一组互斥选项，选中的那个浮起来。
///
/// ## 选中态为什么不是强调色填充
///
/// `AppearancePicker` 的滑块是实心强调色，这里**刻意不是** —— 它是一块
/// 浮起来的玻璃（`panel` 薄膜 + 强一档的边）。
///
/// 理由是密度：外观切换在整个应用里只有一个实例，而工具页上一屏可能同时站着
/// 四五组选项（方向、格式、单位、时区、大小写…）。全填强调色就等于没有强调色 ——
/// 而那个名额得留给「重新生成」那种真正的主操作。
///
/// **规矩：强调色填充只给应用级 chrome 的开关；功能内部的选项走安静的浮起滑块。**
///
/// 交互和原生 `.segmented` Picker 一样都不少：三个都是真 `Button`，
/// Tab 能到、⏎ / 空格能按，VoiceOver 报 `.isSelected`，未选中项悬停出底色，
/// 减弱动态时滑块直接跳过去。
public struct SegmentedPicker<Option: Hashable & Identifiable>: View {
    @Binding private var selection: Option
    private let options: [Option]
    private let title: (Option) -> String
    private let label: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var pill

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
        HStack(spacing: 2) {
            ForEach(options) { option in
                Segment(
                    title: title(option),
                    isSelected: selection == option,
                    namespace: pill
                ) {
                    selection = option
                }
            }
        }
        .padding(2)
        .panel(.well, radius: Theme.Radius.pill)
        .animation(Theme.Motion.spring(reduceMotion: reduceMotion), value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    private struct Segment: View {
        let title: String
        let isSelected: Bool
        let namespace: Namespace.ID
        let action: () -> Void

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var isHovering = false

        private var shape: Capsule { Capsule(style: .continuous) }

        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(Theme.Typo.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.Ink.primary : Theme.Ink.secondary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .frame(height: 20)
                    .background {
                        if isSelected {
                            // 一块滑块在几个位置之间移动，而不是几块各自淡入淡出。
                            shape
                                .fill(Theme.Glass.panel)
                                .overlay(shape.strokeBorder(Theme.Glass.rimStrong, lineWidth: 1))
                                .matchedGeometryEffect(id: "selection", in: namespace)
                        } else if isHovering {
                            shape.fill(Theme.Glass.hover)
                        }
                    }
                    .contentShape(shape)
                    .contentShape(.focusEffect, shape)
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
            .animation(Theme.Motion.fast(reduceMotion: reduceMotion), value: isHovering)
            .accessibilityLabel(title)
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        }
    }
}
