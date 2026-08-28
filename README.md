# LetItGo

macOS 应用骨架。架构、构建、测试全部接通，**业务功能一律留空**。

技术栈：SwiftUI · Swift 6 严格并发 · `@Observable` · SwiftPM 多模块 · swift-testing

---

## 快速开始

```bash
make run      # 编译 → 打包成 .app → 启动
make test     # 跑单元测试
make help     # 看全部命令
```

首次 `make run` 后会在 `build/LetItGo.app` 得到一个可双击的应用：
三栏窗口、菜单栏命令、⌘, 设置窗口都已就位，每个界面显示空态。
侧边栏左下角有外观切换（跟随系统 / 浅色 / 深色），设置窗口里是同一个控件、同一份状态。

---

## 架构

```
                    LetItGo (app shell)
                   ┌────────┴─────────┐
                   │  Scene / 路由 /   │   ← 只做接线，不写业务
                   │  菜单 / 组合根     │
                   └────────┬─────────┘
          ┌─────────┬───────┴───────┬──────────┐
          ▼         ▼               ▼          ▼
     FeatureHome  Persistence  DesignSystem  AppCore
          │         │               │          ▲
          └─────────┴───────────────┴──────────┘
                    依赖单向，都指向 AppCore
```

| 模块 | 职责 | 不该放什么 |
|---|---|---|
| **AppCore** | 领域模型、`AppState`、导航枚举、依赖容器、Repository **协议** | 具体存储实现、界面 |
| **DesignSystem** | 设计令牌（间距/圆角/语义色）、可复用组件 | 业务逻辑 |
| **Persistence** | Repository 的**实现**（当前是内存版 actor） | 界面、领域规则 |
| **FeatureHome** | 一个功能模块的模板：`HomeModel` + `HomeView` | 别的功能的东西 |
| **LetItGo** | 入口、Scene、侧边栏/详情路由、菜单、组合根 | 任何业务逻辑 |

依赖图写在 `Package.swift` 里，**编译器强制**单向：`AppCore` 引用不到任何人。

### 三条贯穿全项目的约定

1. **状态用 `@Observable`，不用 `ObservableObject`。**
   视图只因为真正读到的属性变化而重绘，不是整个对象一变全屏刷新。

2. **依赖从 init 注入，不用单例。**
   `Dependencies` 是个 `Sendable` struct，唯一 new 具体实现的地方是
   `Sources/LetItGo/App/AppDependencies.swift`。测试里换掉某一项即可，
   见 `Tests/FeatureHomeTests` 里的 `FailingItemRepository`。

3. **跨界面共享的状态才进 `AppState`。**
   单个界面自己的状态属于那个界面的 Model。

### 已接通的那条竖切面

`条目` 分区是唯一走通的完整链路，作为新功能的抄写模板：

```
SidebarView (选中 .items)
  └─> AppState.selection
        └─> DetailView 路由
              └─> HomeView(repository: dependencies.items)
                    └─> HomeModel.load()
                          └─> any ItemRepository   ← 协议
                                └─> InMemoryItemRepository (actor)
```

仓库是空的，所以界面显示「还没有条目」—— 这个空态本身就是链路通了的证据。

---

## 加一个新功能模块

1. 建 `Sources/FeatureFoo/`，写 `FooModel.swift`（`@MainActor @Observable`）
   和 `FooView.swift`，照 `FeatureHome` 抄。
2. `Package.swift` 里加一个 `.target(name: "FeatureFoo", dependencies: ["AppCore", "DesignSystem"])`，
   并加进 `LetItGo` 的 dependencies。
3. `AppCore/Navigation.swift` 的 `SidebarItem` 加一个 case。
4. 编译 —— `DetailView` 的 switch 是穷尽的，编译器会**报错提醒你**把新界面接上。

第 4 步是故意的：不会出现「加了菜单但点进去是空白」的情况。

换掉存储实现只需要改 `AppDependencies.live()` 一行，上层一个字都不用动。

---

## 常用命令

| 命令 | 作用 |
|---|---|
| `make build` | 编译（debug） |
| `make run` | 打包 + 启动 |
| `make app` | 只打包到 `build/LetItGo.app` |
| `make app-release` | release 版 .app |
| `make test` | 跑测试 |
| `make clean` | 清产物 |
| `make xcode` | 生成 `.xcodeproj`（需 Xcode + xcodegen） |

带 App Sandbox 打包：`SANDBOX=1 make app`（会创建
`~/Library/Containers/com.lawrence.LetItGo`）。

---

## 当前环境的限制

这台机器只装了 **Command Line Tools，没有装 Xcode**。三个编译器宏插件
（`SwiftUIMacros` / `SwiftDataMacros` / `PreviewsMacros`）只随 Xcode 分发，
所以骨架做了对应处理：

| 用不了 | 骨架里的替代 | 装 Xcode 后 |
|---|---|---|
| `@Entry` | 手写 `EnvironmentKey`（`EnvironmentValues+Dependencies.swift`） | 可换成 `@Entry`，行为一致 |
| `@Model`（SwiftData） | Repository 协议 + 内存 actor 实现 | 见 `Persistence/PersistenceNotes.swift` |
| `#Preview` | 用 `#if ENABLE_PREVIEWS` 包起来 | Xcode 工程会定义这个宏，预览自动生效 |

另外 `actool` 也属于 Xcode，所以暂时没有资源目录（`.xcassets`）和应用图标。
颜色全部走系统语义色（自动跟随浅色/深色），不依赖资源目录。
要加图标：放一个 `Resources/AppIcon.icns`，`Scripts/bundle.sh` 会自动带上。

### 装上 Xcode 之后

```bash
sudo xcode-select -s /Applications/Xcode.app
brew install xcodegen
make xcode          # 生成 LetItGo.xcodeproj
```

`Makefile` 会自动检测 developer dir：切到完整 Xcode 后，`make test` 里那些
给 swift-testing 补搜索路径的参数会自动消失。

> `project.yml` 尚未在真机验证过（本机没有 Xcode 装不了 xcodegen）。
> SwiftPM 这条路是完整跑通并验证过的。

---

## 目录

```
letitgo/
├── Package.swift            # 模块依赖图
├── Makefile                 # 命令入口
├── project.yml              # XcodeGen 配置（可选路径）
├── Sources/
│   ├── AppCore/             # 领域 + 状态 + DI 契约
│   ├── DesignSystem/        # 令牌 + 组件
│   ├── Persistence/         # Repository 实现
│   ├── FeatureHome/         # 功能模块模板
│   └── LetItGo/             # 应用壳
│       ├── App/             #   入口 / delegate / 菜单 / 组合根
│       ├── Root/            #   三栏 + 状态栏
│       └── Settings/        #   ⌘, 设置窗口
├── Tests/
├── Resources/               # Info.plist / entitlements
└── Scripts/bundle.sh        # SwiftPM 产物 → .app
```
