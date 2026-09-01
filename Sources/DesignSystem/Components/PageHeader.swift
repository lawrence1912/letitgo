import SwiftUI

/// 详情区顶部的标题栏。
///
/// 替掉 `navigationTitle` + `toolbar` 那一套：系统工具栏只能放控件，放不下
/// 「这个分区是干什么的」那一行说明，而在一个装着好几个工具的外壳里，
/// 那一行恰恰是用户切过来第一眼要看的。
///
/// 高度固定，底部一条发丝线 —— 内容区滚动时标题不会跟着动。
public struct PageHeader<Actions: View>: View {
    private let title: String
    private let subtitle: String?
    private let actions: Actions

    public init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actions = actions()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Theme.Typo.display)
                    .tracking(Theme.Typo.displayTracking)
                    .foregroundStyle(Theme.Ink.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Typo.caption)
                        .foregroundStyle(Theme.Ink.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            actions
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .frame(height: Theme.Size.headerHeight)
        .frame(maxWidth: .infinity)
        // 外壳档的玻璃 + 真模糊：薄膜比内容区薄一点，所以页头会稍微沉一档；
        // 底下滚过去的内容被模糊掉 —— 标题这一条始终读得清。
        .glassBackground(.frosted)
        .hairline(.bottom)
        .accessibilityElement(children: .contain)
    }
}

extension PageHeader where Actions == EmptyView {
    public init(_ title: String, subtitle: String? = nil) {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }
}
