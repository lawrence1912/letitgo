import AppCore
import AppKit
import DesignSystem
import SwiftUI

/// 备忘板：一屏卡片，每张是一条备忘（标题 + 正文 + 写下的时间）。
///
/// **为什么是网格不是列表。** 备忘的正文是多行的，列表一行只放得下标题；
/// 而卡片是这个壳里唯一「内容本身就是要读的」的分区 —— 版面得让内容占地方。
/// 顺带一件事：详情区里的 `List` 拿不到键盘焦点（`DecryptView` 那边也记了这条），
/// 所以留在 `List` 里换来的方向键其实一直是不生效的，换成网格没丢东西。
///
/// 选中的语汇自己实现（单击选中、⌘ 点多选），和侧边栏、分段控件用的是同一套：
/// 真 `Button` + `.isSelected` + 悬停三态。删除仍然走界面外的 ⌘⌫ ——
/// 那条路读的是这里登记的 `deleteSelectionAction`。
///
/// `State(initialValue:)` 只在视图第一次创建时求值，后续重绘不会重建 Model，
/// 所以可以安全地在 `DetailView` 里直接 `HomeView(repository:now:)`。
public struct HomeView: View {
    @State private var model: HomeModel
    @State private var selection: Set<Item.ID> = []
    @State private var isPresentingNew = false
    /// 正在读全文的那条。双击卡片打开，`nil` 表示没开。
    @State private var reading: Item?

    /// 可选：模块不强制要求宿主提供 `AppState`（Preview 和测试里就没有），
    /// 拿不到就退化成「只在界面内显示错误」，不会崩。
    @Environment(AppState.self) private var appState: AppState?

    /// 卡片最窄 200：再窄一行放不下十个汉字，正文预览就变成一列断词。
    /// 上不封顶 —— 窗口拉宽时列数自己会涨，不会出现一张横跨全屏的巨卡。
    private let columns = [GridItem(.adaptive(minimum: 200), spacing: Theme.Spacing.md)]

    @MainActor
    public init(
        repository: any ItemRepository,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        _model = State(initialValue: HomeModel(repository: repository, now: now))
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // 不画自己的背景：底是壳的事（`DetailView` 那层玻璃）。
            // 功能模块再叠一层薄膜的话，两层半透明合成出来就不透了。
            .task {
                await model.load()
                publishStatus()
            }
            // 登记「本界面能做的事」，界面外的入口（侧边栏 + / 标题栏按钮 / ⌘N /
            // 文件菜单的 ⌘⌫）都读这两个值。见 AppCore/FocusedValues+Actions.swift。
            .focusedSceneValue(\.newItemAction, SceneAction("新建备忘") { isPresentingNew = true })
            // 没选中东西就登记 nil —— ⌘⌫ 自动变灰，这里不用写任何判断。
            .focusedSceneValue(
                \.deleteSelectionAction,
                deletableIDs.isEmpty ? nil : SceneAction("删除备忘") { delete(ids: deletableIDs) }
            )
            .sheet(isPresented: $isPresentingNew) {
                NewMemoSheet { title, content in
                    perform {
                        let item = try await model.create(title: title, content: content)
                        selection = [item.id]
                        appState?.statusMessage = "已新建「\(item.title)」"
                    }
                }
            }
            .sheet(item: $reading) { MemoReaderSheet(item: $0) }
            // 离开分区时把状态栏交还给下一个界面。
            .onDisappear { appState?.statusMessage = nil }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = model.error {
            // 读失败就地显示 —— 整个界面本来就没内容，不值得再弹一个 alert。
            // 写失败走的是另一条路（perform → AppState 弹 alert）。
            EmptyStateView(
                systemImage: "exclamationmark.triangle",
                title: "载入失败",
                message: error.errorDescription,
                tone: .danger,
                action: .init(title: "重试") {
                    Task {
                        await model.load()
                        publishStatus()
                    }
                }
            )
        } else if model.items.isEmpty {
            EmptyStateView(
                systemImage: "note.text",
                title: "还没有备忘",
                message: "写一条试试 —— 它会写进磁盘，下次启动还在。",
                action: .init(title: "新建备忘") { isPresentingNew = true }
            )
        } else {
            board
        }
    }

    private var board: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(memos) { item in
                    MemoCard(
                        item: item,
                        isSelected: selection.contains(item.id),
                        onSelect: { select(item.id) },
                        onOpen: { reading = item }
                    )
                    // 右键点在没选中的卡上时，菜单里的操作只针对那一张 ——
                    // 访达就是这样，选中的那几条不会被顺手一起删掉。
                    .contextMenu {
                        Button("查看全文") { reading = item }
                        Button("拷贝正文") { copy(item) }
                            .disabled(item.content.isEmpty)
                        Divider()
                        Button("删除", role: .destructive) { delete(ids: targets(of: item)) }
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        // 内容要从页头和状态栏的玻璃底下滚过去，中间垫一层不透明的底
        // 就什么都模糊不到了。
        .scrollContentBackground(.hidden)
        // 点卡片之间的空白处取消选中。垫在网格**后面**，所以卡片自己的
        // 单击不会被它抢走。
        .background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { selection.removeAll() }
        }
    }

    // MARK: - 动作

    /// 最新的排最前。仓库按写入时间升序给（那是存储的顺序），
    /// 但在备忘板上，人找的永远是刚写下的那条。
    private var memos: [Item] {
        model.items.reversed()
    }

    /// 选中项里真正还存在的那些。仓库可能在别处被改过，
    /// 直接拿 `selection` 去删会撞上已经不存在的 id。
    private var deletableIDs: Set<Item.ID> {
        selection.intersection(model.items.map(\.id))
    }

    /// 单击选中，⌘ 点切换 —— 和访达、系统备忘录里的多选是同一套手势。
    ///
    /// 修饰键得问 AppKit：SwiftUI 的 `Button` 动作里拿不到当前按着哪个键，
    /// 换成 `.onTapGesture` 一样拿不到，还会把整张卡的键盘可达性一起赔进去。
    @MainActor
    private func select(_ id: Item.ID) {
        guard NSEvent.modifierFlags.contains(.command) else {
            selection = [id]
            return
        }
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    /// 右键菜单真正针对的那几条：点在选中项上就是整批，
    /// 点在没选中的卡上就只有它自己。
    private func targets(of item: Item) -> Set<Item.ID> {
        selection.contains(item.id) ? deletableIDs : [item.id]
    }

    @MainActor
    private func copy(_ item: Item) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
        appState?.statusMessage = "已拷贝「\(item.title)」的正文"
    }

    @MainActor
    private func delete(ids: Set<Item.ID>) {
        perform {
            try await model.delete(ids: ids)
            selection.subtract(ids)
            appState?.statusMessage = "已删除 \(ids.count) 条备忘"
        }
    }

    /// 写操作的统一收口：失败一律上抛到 `AppState`，由壳弹全局 alert。
    /// 每个功能模块照抄这一小段，错误就不会有人忘了处理。
    @MainActor
    private func perform(_ operation: @escaping @MainActor () async throws -> Void) {
        Task {
            do {
                try await operation()
            } catch let error as AppError {
                appState?.presentedError = error
            } catch {
                appState?.presentedError = .unexpected(error.localizedDescription)
            }
        }
    }

    @MainActor
    private func publishStatus() {
        guard model.error == nil else { return }
        appState?.statusMessage = model.items.isEmpty ? "还没有备忘" : "\(model.items.count) 条备忘"
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
