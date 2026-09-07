import AppCore
import AppKit
import DesignSystem
import SwiftUI

/// 待办板：最上面一行输入框，下面两列卡片 —— 左边「待办」，右边「已完成」。
///
/// **操作只有三个**，每个都是一步：
///   - 加：在输入框里打字，回车。没有 sheet、没有「标题 / 正文」两栏，
///     连着记三件事就是打字、回车、打字、回车。
///   - 做完：把卡片拖到右边那列，或者点卡上的方框。
///   - 删掉：点卡片右下角的 ×，或者选中几张按 ⌘⌫。
///
/// **拖放不是唯一的路。** 打勾这件事同时有方框和右键菜单两条单指针路径 ——
/// WCAG 2.2 的「Dragging Movements」要的就是这个：拖动可以是**最快**的那条路，
/// 但不能是**唯一**的那条。
///
/// 输入框常驻在顶上，不是按 ⌘N 才出现的浮层 —— 待办是随手记的东西，
/// 「先想起要记，再去把入口找出来」这一步本身就会让人放弃记。
/// ⌘N / 页头的 + 仍然有用：它们把光标送进这个框。
///
/// 板最宽 900：两列各 ~430，再宽下去一行字会长到眼睛回不到行首。
///
/// `State(initialValue:)` 只在视图第一次创建时求值，后续重绘不会重建 Model，
/// 所以可以安全地在 `DetailView` 里直接 `HomeView(repository:now:)`。
public struct HomeView: View {
    @State private var model: HomeModel
    @State private var selection: Set<Item.ID> = []
    /// 输入框里还没提交的那行字。写失败时它**不会**被清掉。
    @State private var draft = ""
    @FocusState private var isComposing: Bool

    /// 可选：模块不强制要求宿主提供 `AppState`（Preview 和测试里就没有），
    /// 拿不到就退化成「只在界面内显示错误」，不会崩。
    @Environment(AppState.self) private var appState: AppState?

    private static let boardWidth: CGFloat = 900

    @MainActor
    public init(
        repository: any ItemRepository,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        _model = State(initialValue: HomeModel(repository: repository, now: now))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 载入中和读失败的时候不给输入框：前者还不知道已经有什么，
            // 后者连写进去能不能存住都不知道。
            if !model.isLoading && model.error == nil {
                composer
            }
            content
        }
        .frame(maxWidth: Self.boardWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 不画自己的背景：底是壳的事（`DetailView` 那层玻璃）。
        // 功能模块再叠一层薄膜的话，两层半透明合成出来就不透了。
        .task {
            await model.load()
            publishStatus()
        }
        // 登记「本界面能做的事」，界面外的入口（侧边栏 + / 标题栏按钮 / ⌘N /
        // 文件菜单的 ⌘⌫）都读这两个值。见 AppCore/FocusedValues+Actions.swift。
        .focusedSceneValue(\.newItemAction, SceneAction("新建待办") { isComposing = true })
        // 没选中东西就登记 nil —— ⌘⌫ 自动变灰，这里不用写任何判断。
        .focusedSceneValue(
            \.deleteSelectionAction,
            deletableIDs.isEmpty ? nil : SceneAction("删除待办") { delete(ids: deletableIDs) }
        )
        // 离开分区时把状态栏交还给下一个界面。
        .onDisappear { appState?.statusMessage = nil }
    }

    // MARK: - 输入框

    /// 加一条的唯一入口。回车提交，提交完光标留在框里 —— 一条接一条地记，
    /// 中间不用碰鼠标。
    ///
    /// 用 `.field()` 而不是 `.panel(.well)`：它是**能打字的地方**，
    /// 要有凹进去的样子和一个看得见的焦点环（见 DesignSystem/Surfaces.swift）。
    private var composer: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isComposing ? Theme.Brand.accent : Theme.Ink.tertiary)
                .accessibilityHidden(true)

            // 输入控件本身还是原生的（输入法、撤销、拖放、VoiceOver 全靠它们），
            // 只把外框换掉：`.plain` 去掉系统边框，焦点态自己画一圈强调色。
            TextField("要做点什么？写一行，回车加进来", text: $draft)
                .textFieldStyle(.plain)
                .font(Theme.Typo.body)
                .focused($isComposing)
                .onSubmit(add)
                // placeholder 不等于 label：空框时 VoiceOver 念的是占位文字，
                // 用户一输入内容占位就消失，控件随即变成无名的「文本栏」。
                .accessibilityLabel("新的待办")

            // 打了字才出现：这时候按回车才真的会发生一件事。
            // 空框上挂一句「回车加一条」是装饰，有字时它是**下一步**。
            if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Badge("回车加一条", tone: .accent, systemImage: "return", size: .compact)
                    .transition(.identity)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .frame(height: 36)
        .field(focused: isComposing)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.md)
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
            // 一条都没有的时候不摆两个空槽 —— 两块虚线框看着像界面坏了。
            // 空态不给按钮：要按的东西就在它正上方。
            EmptyStateView(
                systemImage: "checklist",
                title: "还没有待办",
                message: "在上面写一行，回车就加进来 —— 它会写进磁盘，下次启动还在。"
            )
        } else {
            board
        }
    }

    private var board: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            TodoColumn(
                title: "待办",
                systemImage: "circle",
                tone: .accent,
                items: model.pending,
                emptyHint: "都做完了 —— 上面写一行，新的会落在这儿",
                onDrop: { drop($0, isDone: false) },
                card: { card($0) }
            )

            TodoColumn(
                title: "已完成",
                systemImage: "checkmark.circle",
                tone: .success,
                items: model.completed,
                emptyHint: "把卡片拖到这里，或者点卡上的方框",
                onDrop: { drop($0, isDone: true) },
                card: { card($0) }
            )
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.lg)
        // 卡片换列时是**挪过去**，不是这边消失那边出现 —— 少了这行，
        // 拖放松手的那一瞬间会看到一次闪烁，人会怀疑自己拖丢了。
        // 点两列之外的空白处取消选中。
        .background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { selection.removeAll() }
        }
    }

    /// 一张卡 + 它的右键菜单 + 它能被拖走这件事。
    private func card(_ item: Item) -> some View {
        TodoCard(
            item: item,
            isSelected: selection.contains(item.id),
            onToggle: { toggle(item) },
            onSelect: { select(item.id) },
            onDelete: { delete(ids: [item.id]) }
        )
        // 负载是 id 的字符串形式。**一次只拖一张** —— `draggable` 是挂在
        // 单个视图上的，多选批量拖得自己接管整套拖放会话，不值得。
        .draggable(item.id.uuidString) { dragPreview(item) }
        // 右键点在没选中的卡上时，菜单里的操作只针对那一张 ——
        // 访达就是这样，选中的那几张不会被顺手一起删掉。
        .contextMenu {
            Button(item.isDone ? "移回待办" : "标为完成") { toggle(item) }
            Button("拷贝文本") { copy(item) }
            Divider()
            Button("删除", role: .destructive) { delete(ids: targets(of: item)) }
        }
    }

    /// 拖起来的时候跟着鼠标走的那一小块。
    ///
    /// 这块是 AppKit 单独截图画出来的，**背后没有氛围底** ——
    /// 所以它走实心的 `Surface.well`，不上玻璃。
    ///
    /// 换成系统 Liquid Glass 之后这条比原先更硬了：那层材质折射的是**背后的内容**，
    /// 而这一小块被拎出窗口之外，背后什么都没有 —— 它会折射出一块灰板。
    private func dragPreview(_ item: Item) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
        return Text(item.text)
            .font(Theme.Typo.body)
            .foregroundStyle(Theme.Ink.primary)
            .lineLimit(2)
            .frame(maxWidth: 240, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(shape.fill(Theme.Surface.well))
            .overlay { shape.strokeBorder(Theme.Line.hairline, lineWidth: 1) }
    }

    // MARK: - 动作

    /// 选中项里真正还存在的那些。仓库可能在别处被改过，
    /// 直接拿 `selection` 去删会撞上已经不存在的 id。
    private var deletableIDs: Set<Item.ID> {
        selection.intersection(model.items.map(\.id))
    }

    /// 空输入直接吞掉：一个人在空框上按回车不是想触发一个错误弹窗。
    /// （Model 里那道闸拦的是绕开这个界面的调用方。）
    @MainActor
    private func add() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        perform {
            try await model.create(text: text)
            // 只有真的写进去了才清空。写失败时用户打的那行字还在框里，
            // 弹窗点掉就能再按一次回车。
            draft = ""
            publishStatus()
        }
    }

    @MainActor
    private func toggle(_ item: Item) {
        perform {
            try await model.toggle(id: item.id)
            publishStatus()
        }
    }

    /// 一批卡片落在某一列上。
    ///
    /// 只认自己发出去的负载：从别的应用拖一段文字进来，`UUID(uuidString:)`
    /// 解不出，或者解出来的 id 这儿没有 —— 那就返回 false，卡片弹回去，
    /// 而不是凭空多出一条待办。落回原来那一列同样返回 false（`setDone` 那边
    /// 也是空操作），松手时不会有任何动静。
    @MainActor
    private func drop(_ payloads: [String], isDone: Bool) -> Bool {
        let ids = payloads
            .compactMap(UUID.init(uuidString:))
            .filter { id in model.items.contains { $0.id == id && $0.isDone != isDone } }
        guard !ids.isEmpty else { return false }

        perform {
            for id in ids {
                try await model.setDone(isDone, id: id)
            }
            publishStatus()
        }
        return true
    }

    /// 单击选中，⌘ 点切换 —— 和访达、系统备忘录里的多选是同一套手势。
    ///
    /// 修饰键得问 AppKit：SwiftUI 的手势回调里拿不到当前按着哪个键。
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

    /// 右键菜单真正针对的那几张：点在选中项上就是整批，
    /// 点在没选中的卡上就只有它自己。
    private func targets(of item: Item) -> Set<Item.ID> {
        selection.contains(item.id) ? deletableIDs : [item.id]
    }

    @MainActor
    private func copy(_ item: Item) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        appState?.statusMessage = "已拷贝这条待办"
    }

    @MainActor
    private func delete(ids: Set<Item.ID>) {
        perform {
            try await model.delete(ids: ids)
            selection.subtract(ids)
            publishStatus()
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

    /// 状态栏说的永远是同一件事：还剩几件。每次写完都重算一遍，
    /// 不用各个动作各写一句文案（「已新建」「已删除 2 条」那种话，
    /// 用户在界面上已经看见了）。
    @MainActor
    private func publishStatus() {
        guard model.error == nil else { return }
        if model.items.isEmpty {
            appState?.statusMessage = "还没有待办"
        } else if model.remaining == 0 {
            appState?.statusMessage = "\(model.items.count) 件，全做完了"
        } else {
            appState?.statusMessage = "还剩 \(model.remaining) 件 · 共 \(model.items.count) 件"
        }
    }
}

// Preview 需要 Xcode 的 PreviewsMacros 插件，纯 Command Line Tools 编不过。
// ENABLE_PREVIEWS 只由 Xcode 工程（project.yml）定义，`swift build` 下自动跳过。
#if ENABLE_PREVIEWS
#Preview {
    HomeView(repository: EmptyItemRepository())
        .frame(width: 900, height: 520)
}
#endif
