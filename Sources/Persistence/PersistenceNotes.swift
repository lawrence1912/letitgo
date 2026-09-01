// 接真实存储时的落点说明（这里只有注释，没有代码）。
//
// 现状：两个实现，都满足 `ItemRepository`：
//   - `FileItemRepository`  —— 正式运行用，JSON 落盘，重启后数据还在。
//   - `InMemoryItemRepository` —— 测试和 Preview 用，进程退出即清空。
// 谁上场只由 `LetItGo/App/AppDependencies.swift` 一行决定。
//
// 换成 SwiftData 的做法：
//   1. 建 `SwiftDataItemRepository.swift`，在里面定义 `@Model final class ItemRecord`
//      和 `Item` 之间的映射（领域模型不要直接标 `@Model`，否则存储技术会渗进 AppCore）。
//   2. 用 `ModelActor` 包住 `ModelContext`，实现 `ItemRepository`。
//   3. 在 `AppDependencies.live` 里把 `items:` 换成新实现。
//   4. 老用户的 items.json 需要迁移的话，在新实现的首次启动里读一次旧文件再导入。
//
// 注意：`@Model` / `@Query` 依赖 SwiftDataMacros 编译器插件，该插件只随
// Xcode 分发。当前机器只装了 Command Line Tools，所以 SwiftData 暂时编不过
// —— 这也是先用文件实现顶上的原因。换过去时上层一行都不用动，
// `FileItemRepositoryTests` 里那几条用例可以原样复制给新实现跑一遍。
