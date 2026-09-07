import AppCore
import AppKit
import SwiftUI

/// 主题切换控件：一格一套色板，选中的那格亮起来。
///
/// ## 为什么不再是分段控件
///
/// 上一版和外观切换共用一套分段零件。那在三套主题的时候还行，
/// 六套之后就不行了 —— 六个带色卡的分段挤在一条胶囊里，每一格窄到
/// 只剩「莫…」。而且分段控件表达的是**互斥的开关**（浅色 / 深色），
/// 主题不是开关，是**从一柜子里挑一件**：用户要比较的是六个样子，
/// 不是在两三个词之间切换。
///
/// 所以它改成一片卡。每格是一块玻璃，装着那套主题的色卡和名字；
/// 选中的那格垫一块 `SelectionSurface`。
/// **不包 `GlassEffectContainer`** —— 那个容器会把相邻的玻璃合并渲染，
/// 相邻格的内容会渗进对方的面里（概览那边踩过，见 `OverviewView`）。
///
/// **选中态是「当前选中」，不是「主操作」** —— 和侧边栏的分区选中同级，
/// 就该长得一样（两处都是 `GlassTone.accent`）。一屏最多一个响亮的东西，
/// 那个名额不给设置里的选择器。
public struct ThemePicker: View {
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .fallback

    private let columns = [GridItem(.adaptive(minimum: 132), spacing: Theme.Spacing.sm)]

    public init() {}

    public var body: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                ForEach(AppTheme.allCases) { option in
                    ThemeOption(theme: option, isSelected: theme == option) {
                        theme = option
                    }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("主题")
    }
}

private struct ThemeOption: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                ThemeSwatch(theme)

                VStack(alignment: .leading, spacing: 1) {
                    Text(theme.title)
                        .font(Theme.Typo.label.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(Theme.Ink.primary)
                    Text(theme.subtitle)
                        .font(Theme.Typo.caption)
                        .foregroundStyle(Theme.Ink.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            // 选中那块底垫在**内容和玻璃之间**，走的是和边栏、待办卡同一个
            // `SelectionSurface`，选中状态立即更新。
            .background { SelectionSurface(isSelected: isSelected, radius: Theme.Radius.md) }
            .referenceGlassPanel(accent: Theme.Brand.info, radius: Theme.Radius.md)
            .contentShape(.focusEffect, RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }
        .buttonStyle(CardButtonStyle())
        .accessibilityLabel(theme.title)
        .accessibilityHint(theme.subtitle)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// 一套主题的三点色卡：氛围底 / 主操作 / 信息态。
///
/// 它必须能画**别的**主题的颜色 —— 用户是靠这三个点决定要不要换过去的，
/// 全都按当前主题解析的话，六个选项会长得一模一样。所以这里绕开
/// `Theme.*`（那些查的是「当前」色板），直接问某一套色板要色值。
///
/// 仍然跟着**外观**走：`nsColor(for:)` 在绘制时拿到当前外观，
/// 所以深色模式下的色卡是那套主题的深色版，不是浅色版缩略图。
struct ThemeSwatch: View {
    private let theme: AppTheme

    init(_ theme: AppTheme) {
        self.theme = theme
    }

    /// 三个样本：底 / 主操作 / 信息态。
    private static let tokens: [ColorToken] = [.backdrop, .accentFill, .info]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Self.tokens, id: \.self) { token in
                Circle()
                    .fill(color(token))
                    .frame(width: 9, height: 9)
                    .overlay(Circle().strokeBorder(Theme.Line.hairline, lineWidth: 0.5))
            }
        }
        // 三个点是同一件事的三个样本，VoiceOver 念「莫兰迪」就够了，
        // 色卡本身不承担信息。
        .accessibilityHidden(true)
    }

    private func color(_ token: ColorToken) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            Palette.of(theme).ramp(for: token).nsColor(for: appearance)
        })
    }
}
