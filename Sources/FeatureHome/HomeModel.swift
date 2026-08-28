import AppCore
import Foundation
import Observation

/// 一个功能模块的 Model 长什么样 —— 这是给后续功能抄的模板。
///
/// 三条规矩:
///   1. `@MainActor`，UI 状态只在主线程改，不用到处 `await MainActor.run`。
///   2. 依赖从 init 注入（这里是 `any ItemRepository`），不在内部 new 单例，
///      测试里才能塞假实现。
///   3. 对外暴露 `private(set)`，状态只能由 Model 自己的方法改。
@MainActor
@Observable
public final class HomeModel {
    public private(set) var items: [Item] = []
    public private(set) var isLoading = false
    public private(set) var error: AppError?

    private let repository: any ItemRepository

    public init(repository: any ItemRepository) {
        self.repository = repository
    }

    public func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            items = try await repository.fetchAll()
            Log.data.debug("HomeModel 载入 \(self.items.count, privacy: .public) 条")
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .unexpected(error.localizedDescription)
        }
    }
}
