import SwiftUI

/// 通用空态。骨架阶段每个界面都是空的，所以这个组件会被反复用到；
/// 真实功能上线后它依然是「没有数据 / 没有搜索结果」的标准展示。
///
/// 空态要教会用户这个界面是干什么的，不是写一句「暂无数据」。
/// 所以三段固定：图标底板（这是什么）、标题（现在是什么状态）、
/// 说明（接下来能做什么），能给按钮就给按钮。
public struct EmptyStateView: View {
    private let systemImage: String
    private let title: String
    private let message: String?
    private let tone: Tone
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
        tone: Tone = .neutral,
        action: Action? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.tone = tone
        self.action = action
    }

    public var body: some View {
        VStack(spacing: 0) {
            IconTile(systemImage, tone: tone, size: 52)
                .padding(.bottom, Theme.Spacing.lg)

            Text(title)
                .font(Theme.Typo.title)
                .tracking(Theme.Typo.titleTracking)
                .foregroundStyle(Theme.Ink.primary)

            if let message {
                Text(message)
                    .font(Theme.Typo.body)
                    .foregroundStyle(Theme.Ink.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .frame(maxWidth: 340)
                    .padding(.top, Theme.Spacing.xs)
            }

            if let action {
                Button(action.title, action: action.handler)
                    .buttonStyle(.primaryAction(size: .large))
                    .padding(.top, Theme.Spacing.lg)
            }
        }
        .padding(Theme.Spacing.xl)
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
        message: "这里会显示内容列表。现在功能还没接上。",
        action: .init(title: "新建", handler: {})
    )
    .frame(width: 520, height: 360)
}
#endif
