import AppCore
import Persistence

/// 组合根（composition root）：整个 App 里唯一 new 具体实现的地方。
///
/// 换存储、加网络层、接第三方 SDK —— 都只改这个文件。
/// 其他模块只认 `AppCore` 里的协议，永远不知道背后是谁。
enum AppDependencies {
    /// 正式运行时用的依赖。
    static func live() -> Dependencies {
        Dependencies(
            items: InMemoryItemRepository()
        )
    }
}
