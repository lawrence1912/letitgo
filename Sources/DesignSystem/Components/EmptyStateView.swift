import SwiftUI

/// 通用空态。骨架阶段每个界面都是空的，所以这个组件会被反复用到；
/// 真实功能上线后它依然是「没有数据 / 没有搜索结果」的标准展示。
public struct EmptyStateView: View {
    private let systemImage: String
    private let title: String
    private let message: String?
    private let action: Action?

    public struct Action {
        public let title: String
        public let handler: () -> Void

        public init(title: String, handler: @escaping () -> Void) {
            self.title = title
            self.handler = handler
        }
    }

    public init(
        systemImage: String,
        title: String,
        message: String? = nil,
        action: Action? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.action = action
    }

    public var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(Theme.Palette.secondaryLabel)

            VStack(spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Theme.Palette.label)

                if let message {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
            }

            if let action {
                Button(action.title, action: action.handler)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, Theme.Spacing.xs)
            }
        }
        .padding(Theme.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

// Preview 需要 Xcode 的 PreviewsMacros 插件，纯 Command Line Tools 编不过。
// ENABLE_PREVIEWS 只由 Xcode 工程（project.yml）定义，`swift build` 下自动跳过。
#if ENABLE_PREVIEWS
#Preview {
    EmptyStateView(
        systemImage: "tray",
        title: "还没有内容",
        message: "这里会显示条目列表。现在功能还没接上。",
        action: .init(title: "新建", handler: {})
    )
    .frame(width: 520, height: 360)
}
#endif
