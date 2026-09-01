# LetItGo

macOS 应用骨架 + 装在里面的工具。架构、构建、测试全部接通。

- **概览** —— 各个分区的入口页：能用的分区摊成卡片，带彩色图标、说明和键盘编号。
  留白分区不列 —— 点进去只有「功能还没接」的卡片不是入口，是死路。

**工作区**

- **备忘** —— 卡片式的备忘板：标题、正文、写下的时间。也是从界面一路打通到磁盘的模板竖切面，新功能照它抄。
- 活动 —— 刻意留空的占位分区。

**工具**（写 Java 时天天要用的那几个）

- **编解码** —— Base64（标准 / URL-safe）、URL 百分号、十六进制。解码宽进：
  少了 `=`、两套字母表混用、带换行或 `0x` 前缀，全都收。
- **时间戳** —— epoch ↔ 日期。**秒还是毫秒按量级自动判断**，并且把判断结果
  写在界面上（「按毫秒读」）—— 猜错三个数量级，日期会落到 1970 年而且看着还挺像。
- **哈希** —— MD5 / SHA-1 / SHA-256 / SHA-512 一次全算，UTF-8 取字节。
- **随机串** —— 密码 / 密钥 / 测试数据。**一次生成 10 个**，逐行复制或者一次拿走全部；
  长度、大小写、数字、符号可选，随机源是 CSPRNG（对应 Java 的 `SecureRandom`，不是 `Math.random()`）。
- **JSON** —— 格式化 / 压缩 / 转成 Java 字面量。转义过的 JSON（引号是 `\"`）
  和中文引号（`“ ”`）都会自动认出来并修好，**修了什么会逐条写在界面上**；
  坏在哪儿用 ▶ 指出来。字符串**里面**的全角逗号一个字不动 ——
  那是内容不是语法，换掉它 JSON 依然合法但数据被悄悄改了。
- **JWT** —— 拆开看 header / payload，`exp` `iat` 换算成能读的时间并标出过期没过期，
  HS256/384/512 可验签。**整段在本机跑**——生产 token 粘进网页版工具等于把凭证交出去。
- **RSA** —— 生成密钥对、加解密。麻烦的从来不是加解密，是密钥格式：
  Apple 只认 PKCS#1，Java 给的是 X.509 / PKCS#8，中间那层 DER 壳子这里自己拆自己包，
  **收进来和吐出去的都是 Java 直接能用的 PEM**。

技术栈：SwiftUI · Swift 6 严格并发 · `@Observable` · SwiftPM 多模块 · swift-testing

---

## 快速开始

```bash
make run      # 编译 → 打包成 .app → 启动
make test     # 跑单元测试
make help     # 看全部命令
```

首次 `make run` 后会在 `build/LetItGo.app` 得到一个可双击的应用：
三栏窗口、菜单栏命令、⌘, 设置窗口都已就位。侧边栏左下角有外观切换
（跟随系统 / 浅色 / 深色），设置窗口里是同一个控件、同一份状态。

「备忘」分区能真的用：⌘N 新建（标题 + 正文）、单击选中 / ⌘ 点多选、双击读全文、
⌘⌫ 与右键菜单删除，数据落在
`~/Library/Application Support/com.lawrence.LetItGo/items.json`，重启还在。

「活动」是刻意留白，不是没做完 ——
`SidebarItem.isPlaceholder` 把这件事写成了代码，概览的入口页据此跳过它，
加新分区时编译器会逼你表态。

「工具」那一组是纯函数工具：没有网络、不碰磁盘、没有依赖，所以逻辑层整个是可测的 ——
测试全打在 `Codec` / `TimeConversion` / `Digest` / `RandomString` / `JSONFormatter` /
`JWT` / `RSA` 这七个 enum 上，界面层只负责摆。

两个把「不好测的东西」做成参数的例子：随机串把**随机源**做成参数
（生产传 `SystemRandomNumberGenerator`，测试传定种子的），于是「每类至少一个」
「洗过牌」这些性质可以真的断言；时间相关的一律把 `now` 做成参数，
于是「已过期 4 小时」这种判断不依赖测试跑在哪一天。

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
  FeatureHome  FeatureToolbox  Persistence  DesignSystem  AppCore
       │            │               │            │           ▲
       └────────────┴───────────────┴────────────┴───────────┘
                          依赖单向，都指向 AppCore
```

| 模块 | 职责 | 不该放什么 |
|---|---|---|
| **AppCore** | 领域模型、`AppState`、导航枚举、依赖容器、Repository **协议** | 具体存储实现、界面 |
| **DesignSystem** | 设计令牌（间距/圆角/色阶/字号/动效）、可复用组件、按钮样式 | 业务逻辑 |
| **Persistence** | `ItemRepository` 的**实现**（落盘 JSON + 内存两个 actor） | 界面、领域规则 |
| **FeatureHome** | 一个功能模块的模板：`HomeModel` + `HomeView` | 别的功能的东西 |
| **FeatureToolbox** | 编解码 / 时间戳 / 哈希 / 随机串 / JSON / JWT / RSA。七个工具一个模块 —— 它们共用同一套「输入 → 选项 → 结果」骨架 | 别的功能的东西 |
| **LetItGo** | 入口、Scene、侧边栏/详情路由、菜单、组合根 | 任何业务逻辑 |

依赖图写在 `Package.swift` 里，**编译器强制**单向：`AppCore` 引用不到任何人。

视觉规范单独写在 [`DESIGN.md`](DESIGN.md)：三套 OKLCH 色板（莫兰迪 / 雾青 / 素白，
设置里可切换，各给四种外观一组值，对比度有测试兜着）、毛玻璃的六个层级、
强调色的用量、排版、密度、组件、动效、无障碍，
以及**哪些控件换了皮、哪些没换**那条线。文末四个 SwiftUI 坑里有两个能把整个窗口
搞崩 —— **动界面之前先看那四条**。

### 五条贯穿全项目的约定

1. **状态用 `@Observable`，不用 `ObservableObject`。**
   视图只因为真正读到的属性变化而重绘，不是整个对象一变全屏刷新。

2. **依赖从 init 注入，不用单例。**
   `Dependencies` 是个 `Sendable` struct，唯一 new 具体实现的地方是
   `Sources/LetItGo/App/AppDependencies.swift`。测试里换掉某一项即可，
   见 `Tests/FeatureHomeTests` 里的 `FailingItemRepository`。

3. **跨界面共享的状态才进 `AppState`。**
   单个界面自己的状态属于那个界面的 Model。

4. **读吞错，写抛错。**
   `load()` 把错误收进自己的 `error` 属性，界面就地显示错误态 —— 反正整屏没内容，
   再弹个 alert 只是让用户多点一次「好」。`create` / `delete` 把错误**抛出去**，
   调用方塞进 `AppState.presentedError`，壳统一弹全局 alert：写操作是用户主动
   发起的，失败必须打断他。

5. **界面外的入口，走 focused value，不走全局状态。**
   「新建」在三个地方能点（侧边栏 `+`、工具栏 `+`、⌘N），它们都不在 `HomeView`
   里。界面用 `.focusedSceneValue` 登记自己能做什么，入口用 `@FocusedValue` 读
   （见 `AppCore/FocusedValues+Actions.swift`）。**没人登记时值是 nil**，于是入口
   自动变灰 —— 「⌘N 在概览分区变灰」「⌘⌫ 没选中时变灰」这两条行为，
   代码里没有任何一处 if 在判断分区或选中数。

### 已接通的那条竖切面

`备忘` 分区是唯一走通的完整链路，作为新功能的抄写模板。它把一个功能模块
会遇到的每个问题都演示了一遍 —— 抄的时候不用重新做决定：

```
读:  SidebarView (选中 .items)
       └─> AppState.selection
             └─> DetailView 路由
                   └─> HomeView(repository:now:)
                         └─> HomeModel.load()            ← 失败 → 界面内错误态
                               └─> any ItemRepository    ← 协议
                                     └─> FileItemRepository (actor) → items.json

写:  ⌘N / 侧边栏 + / 工具栏 +
       └─> FocusedValues.newItemAction   ← 界面登记，入口触发
             └─> NewMemoSheet
                   └─> HomeModel.create(title:content:)  ← 失败 → 抛出
                         └─> repository.insert → 落盘 → 重新 fetchAll
                               └─> AppState.statusMessage / presentedError
```

删除同理，走 `FocusedValues.deleteSelectionAction`（⌘⌫ 和右键菜单）。

换掉存储实现只需要改 `AppDependencies.live()` 一行，上层一个字都不用动 ——
`Tests/AppCoreTests/FileItemRepositoryTests.swift` 里那几条用例是写给**协议**的，
换实现时原样复用就能验证新实现。

---

## 加一个新功能模块

1. 建 `Sources/FeatureFoo/`，写 `FooModel.swift`（`@MainActor @Observable`）
   和 `FooView.swift`，照 `FeatureHome` 抄。
2. `Package.swift` 里加一个 `.target(name: "FeatureFoo", dependencies: ["AppCore", "DesignSystem"])`，
   并加进 `LetItGo` 的 dependencies。
3. `AppCore/Navigation.swift` 的 `SidebarItem` 加一个 case。
4. 编译 —— `DetailView` 的 switch 是穷尽的，编译器会**报错提醒你**把新界面接上。
5. 新界面如果有「主操作」，在它上面 `.focusedSceneValue(\.newItemAction, …)`
   登记一下，侧边栏 / 工具栏 / ⌘N 三个入口立刻对它生效，不用改壳
   （文案由 `SceneAction` 的 title 决定，比如备忘分区显示「新建备忘」）。

第 4 步是故意的：不会出现「加了菜单但点进去是空白」的情况。

---

## 标志

`Resources/Logo/mark.svg` 是标志本体（纯字形，`fill="currentColor"`，随处可用）。
应用图标 `Resources/AppIcon.icns` 由 `Scripts/make_icon.swift` 生成 ——
**标志即代码**，改造型只需改脚本里的几何参数再重跑：

```bash
xcrun swift Scripts/make_icon.swift .
iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
rm -rf Resources/AppIcon.iconset
```

`Scripts/bundle.sh` 会自动把 `AppIcon.icns` 装进 .app 并写好 `CFBundleIconFile`。

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
| `@Model`（SwiftData） | Repository 协议 + 落盘 JSON actor | 见 `Persistence/PersistenceNotes.swift` |
| `#Preview` | 用 `#if ENABLE_PREVIEWS` 包起来 | Xcode 工程会定义这个宏，预览自动生效 |

另外 `actool` 也属于 Xcode，所以没有资源目录（`.xcassets`）。
色板写在代码里（OKLCH → sRGB，四种外观由 `dynamicProvider` 挑），不依赖资源目录；
代价是系统强调色改不了 —— 所以边栏选中态是自绘的主题强调色，不是系统的蓝条；
应用图标绕开了 `actool` —— 由 `Scripts/make_icon.swift` 直接画出 `.icns`（见「标志」一节）。

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
├── DESIGN.md                # 视觉规范（颜色 / 密度 / 组件 / 动效）
├── Package.swift            # 模块依赖图
├── Makefile                 # 命令入口
├── project.yml              # XcodeGen 配置（可选路径）
├── Sources/
│   ├── AppCore/             # 领域 + 状态 + DI 契约
│   ├── DesignSystem/        # 令牌 + 组件
│   ├── Persistence/         # ItemRepository 实现
│   ├── FeatureHome/         # 功能模块模板
│   ├── FeatureToolbox/      # 编解码 / 时间戳 / 哈希 / 随机串 / JSON / JWT / RSA
│   └── LetItGo/             # 应用壳
│       ├── App/             #   入口 / delegate / 菜单 / 组合根
│       ├── Root/            #   三栏 + 状态栏
│       └── Settings/        #   ⌘, 设置窗口
├── Tests/
├── Resources/               # Info.plist / entitlements
└── Scripts/bundle.sh        # SwiftPM 产物 → .app
```
