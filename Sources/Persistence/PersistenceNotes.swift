// 接真实存储时的落点说明（这里只有注释，没有代码）。
//
// 现状：`InMemoryItemRepository` 是唯一实现，进程退出即清空。
//
// 换成 SwiftData 的做法：
//   1. 建 `SwiftDataItemRepository.swift`，在里面定义 `@Model final class ItemRecord`
//      和 `Item` 之间的映射（领域模型不要直接标 `@Model`，否则存储技术会渗进 AppCore）。
//   2. 用 `ModelActor` 包住 `ModelContext`，实现 `ItemRepository`。
//   3. 在 `AppDependencies.live` 里把 `items:` 换成新实现。
//
// 注意：`@Model` / `@Query` 依赖 SwiftDataMacros 编译器插件，该插件只随
// Xcode 分发。当前机器只装了 Command Line Tools，所以 SwiftData 暂时编不过
// —— 这也是骨架先用内存实现的原因。装上 Xcode 后即可切换。
