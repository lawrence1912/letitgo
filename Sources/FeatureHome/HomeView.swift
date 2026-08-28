import AppCore
import DesignSystem
import SwiftUI

/// 功能模块的视图模板：自己持有 Model，父级只负责把依赖递进来。
///
/// `State(initialValue:)` 只在视图第一次创建时求值，后续重绘不会重建 Model，
/// 所以可以安全地在 `DetailView` 里直接 `HomeView(repository:)`。
public struct HomeView: View {
    @State private var model: HomeModel

    @MainActor
    public init(repository: any ItemRepository) {
        _model = State(initialValue: HomeModel(repository: repository))
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task { await model.load() }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = model.error {
            EmptyStateView(
                systemImage: "exclamationmark.triangle",
                title: "载入失败",
                message: error.errorDescription
            )
        } else if model.items.isEmpty {
            EmptyStateView(
                systemImage: "tray",
                title: "还没有条目",
                message: "数据链路已经接通（View → Model → Repository），\n只是仓库里现在是空的。"
            )
        } else {
            List(model.items) { item in
                LabeledContent(item.title) {
                    Text(item.createdAt, format: .dateTime.year().month().day())
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                }
            }
            .listStyle(.inset)
        }
    }
}

// Preview 需要 Xcode 的 PreviewsMacros 插件，纯 Command Line Tools 编不过。
// ENABLE_PREVIEWS 只由 Xcode 工程（project.yml）定义，`swift build` 下自动跳过。
#if ENABLE_PREVIEWS
#Preview {
    HomeView(repository: EmptyItemRepository())
        .frame(width: 600, height: 400)
}
#endif
