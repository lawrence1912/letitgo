import AppCore
import Foundation

/// `ItemRepository` 的落盘实现：一个 JSON 文件，进程退出后数据还在。
///
/// 为什么不是 SwiftData：`@Model` 依赖只随 Xcode 分发的编译器插件，本机装不了
/// （见 `PersistenceNotes.swift`）。但「重启后数据还在」是骨架必须演示的一环 ——
/// 少了它，`ItemRepository` 这个抽象就没被真正检验过。所以先用文件顶上，
/// 换 SwiftData 时只需再写一个实现同一协议的类型。
///
/// 做成 `actor`：读改写这一串必须串行，否则两次并发 `insert` 会互相覆盖。
/// 编译器保证这一点，不用手写锁。
public actor FileItemRepository: ItemRepository {

    /// 路径的求值推迟到第一次访问 —— 这样 `init` 不会抛，
    /// 「应用支持目录取不到」这种错就会走和其他存储错误**同一条**上抛路径，
    /// 变成界面里的错误态，而不是启动时的崩溃或静默降级。
    private let locate: @Sendable () throws -> URL

    /// `nil` 表示还没读过磁盘。读进来之后全在内存里改，每次写完整盘落一次。
    /// 骨架量级（几百条）下这样最简单；数据大了再换增量写入。
    private var cache: [Item.ID: Item]?

    /// 正式运行用：`~/Library/Application Support/<bundle id>/<fileName>`。
    /// 开了 App Sandbox 时这个路径会自动落到容器里，代码不用改。
    public init(fileName: String = "items.json") {
        self.locate = { try Self.applicationSupportURL(fileName: fileName) }
    }

    /// 测试用：直接指定文件位置。
    public init(fileURL: URL) {
        self.locate = { fileURL }
    }

    // MARK: - ItemRepository

    public func fetchAll() async throws -> [Item] {
        try loadIfNeeded().values.sorted { $0.createdAt < $1.createdAt }
    }

    public func insert(_ item: Item) async throws {
        var items = try loadIfNeeded()
        items[item.id] = item
        try persist(items)
    }

    public func delete(id: Item.ID) async throws {
        var items = try loadIfNeeded()
        guard items.removeValue(forKey: id) != nil else {
            throw AppError.notFound
        }
        try persist(items)
    }

    // MARK: - 磁盘

    @discardableResult
    private func loadIfNeeded() throws -> [Item.ID: Item] {
        if let cache { return cache }

        let url = try resolveURL()
        // 文件不存在 = 还没存过东西，不是错误。
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            cache = [:]
            return [:]
        }

        do {
            let items = try Self.decoder.decode([Item].self, from: Data(contentsOf: url))
            let loaded = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
            cache = loaded
            Log.data.debug("从磁盘读入 \(loaded.count, privacy: .public) 条")
            return loaded
        } catch {
            throw AppError.storage("读不了 \(url.lastPathComponent)：\(error.localizedDescription)")
        }
    }

    private func persist(_ items: [Item.ID: Item]) throws {
        let url = try resolveURL()
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let sorted = items.values.sorted { $0.createdAt < $1.createdAt }
            // .atomic：先写临时文件再整体换名。中途断电顶多丢这一次写入，
            // 不会留下半个 JSON 让下次启动直接读失败。
            try Self.encoder.encode(sorted).write(to: url, options: .atomic)
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.storage("写不进 \(url.lastPathComponent)：\(error.localizedDescription)")
        }
        // 只有真的落盘成功才更新缓存，否则内存和磁盘会悄悄对不上。
        cache = items
    }

    private var resolvedURL: URL?

    private func resolveURL() throws -> URL {
        if let resolvedURL { return resolvedURL }
        let url = try locate()
        resolvedURL = url
        return url
    }

    private static func applicationSupportURL(fileName: String) throws -> URL {
        do {
            let base = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let folder = Bundle.main.bundleIdentifier ?? Log.subsystem
            return base.appending(path: folder).appending(path: fileName)
        } catch {
            throw AppError.storage("找不到应用支持目录：\(error.localizedDescription)")
        }
    }

    // 日期用 ISO 8601、键排序 + 缩进：文件用 git diff 或肉眼看都读得懂，
    // 排查问题时不用另外写工具。
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
