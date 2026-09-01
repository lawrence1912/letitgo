# LetItGo · 百宝箱

一个 macOS 百宝箱：把每天零碎要用的小工具收进同一个窗口。

转个 Base64、确认那串数字是秒还是毫秒、把 JWT 拆开看一眼过期没有、
生成一串够长的密码、把 Java 那边给的 PEM 换成 Apple 认的格式 ——
这些事单独拿出来，一件都不值得开一个网页，更不值得各装一个应用。
它们的共同点是**打断**：正写着代码，为了三秒钟的换算跳出去一趟。

所以有了这个箱子。⌘1–⌘9 直达，⌘, 调设置，用完 ⌘W 关掉。

**所有计算都在本机跑，一个字节都不往外发。** ——
生产环境的 token 粘进在线解析工具，等于把凭证交给了别人的服务器。

技术栈：SwiftUI · Swift 6 严格并发 · `@Observable` · SwiftPM 多模块 · swift-testing。
162 条用例，`make run` 一条命令出 `.app`。

---

## 箱子里装了什么

| | 分区 | 它替你省掉的那件事 |
|---|---|---|
| ⌘1 | **概览** | 能用的分区摊成入口卡片，带说明和键盘编号。留白分区不列 —— 点进去只有「功能还没接」的卡片不是入口，是死路 |
| ⌘2 | **备忘** | 卡片式备忘板：标题、正文、写下的时间。⌘N 新建、双击读全文、⌘⌫ 删除，落盘 JSON，重启还在 |
| ⌘3 | **编解码** | Base64（标准 / URL-safe）、URL 百分号、十六进制。**解码宽进**：少了 `=`、两套字母表混用、带换行或 `0x` 前缀，全都收 |
| ⌘4 | **时间戳** | epoch ↔ 日期。**秒还是毫秒按量级自动判断**，并且把判断结果写在界面上（「按毫秒读」）—— 猜错三个数量级，日期会落到 1970 年，而且看着还挺像 |
| ⌘5 | **哈希** | MD5 / SHA-1 / SHA-256 / SHA-512 一次全算，UTF-8 取字节 |
| ⌘6 | **随机串** | 密码 / 密钥 / 测试数据，**一次给 10 个**（挑一个顺眼的，逐行复制或整批拿走）。随机源是 CSPRNG，对应 Java 的 `SecureRandom`，不是 `Math.random()` |
| ⌘7 | **JSON** | 格式化 / 压缩 / 转成 Java 字面量。转义过的 JSON（引号是 `\"`）和中文引号都会自动认出来并修好，**修了什么逐条写在界面上** |
| ⌘8 | **JWT** | 拆开看 header / payload，`exp` `iat` 换算成能读的时间并标出过期没过期，HS256/384/512 可验签 |
| ⌘9 | **RSA** | 生成密钥对、加解密。麻烦的从来不是加解密，是密钥格式：Apple 只认 PKCS#1，Java 给的是 X.509 / PKCS#8 —— 中间那层 DER 壳子这里自己拆自己包，**进出都是 Java 直接能用的 PEM** |

「活动」那格是刻意留白，不是没做完 —— `SidebarItem.isPlaceholder` 把这件事
写成了代码，概览页据此跳过它，加新分区时编译器会逼你表态。

### 三个不肯将就的地方

- **宽进严出。** 粘进来的东西是从聊天窗口、日志、PPT 里捞出来的，带着换行、
  中文引号、多余的前缀。工具的职责是认出它们，不是让你先手动清理一遍。
- **把判断说出来。** 自动判断很方便，猜错了很致命。所以「按毫秒读」「修好了
  什么」这类话直接写在界面上 —— **悄悄帮你修好是最难查的一类行为**。
- **不动内容，只动语法。** JSON 里字符串**内部**的全角逗号一个字不换：
  那是数据不是语法，换掉它 JSON 依然合法，但你的数据被悄悄改了。

---

## 长什么样

不是一个默认的 AppKit 窗口：无标题栏三栏窗口，侧边栏、按钮、分段控件、
列表行都是自己画的，压在一层氛围底上的玻璃薄膜里。

- **三套色板**（莫兰迪 / 雾青 / 素白），设置里随时切；每个色写成 OKLCH 的
  四组值（浅 / 深 / 增强对比度浅 / 深），绘制时按当前外观挑。
- **对比度是算过的，不是估的**：正文四种外观全部 ≥ 4.5:1，增强对比度那两组 ≥ 7:1，
  有测试兜着。
- **无障碍四项全要**：减弱动态、减弱透明度、增强对比度、完整键盘 + VoiceOver。
  自绘的每一处都要把原生白送的东西一件件补回来 —— 补不齐就不换。

完整规范见 [`DESIGN.md`](DESIGN.md)，产品原则见 [`PRODUCT.md`](PRODUCT.md)。
DESIGN.md 文末记了六个踩过的 SwiftUI 坑，前三条都是「编译通过、看不出错、
就是不工作」那种，其中两条能把整个窗口搞坏 —— **动界面之前先看那几条**。

---

## 上手

```bash
make run      # 编译 → 打包成 .app → 启动
make test     # 跑测试
make help     # 看全部命令
```

要求 macOS 15+ 和 Swift 6 工具链。**只装 Command Line Tools 也能跑**，
不需要完整 Xcode（代价见文末）。

产物在 `build/LetItGo.app`，可以直接双击。备忘的数据落在
`~/Library/Application Support/com.lawrence.LetItGo/items.json`。

---

## 往箱子里再放一件工具

这个箱子的重点不是现在装了七件，是**再装一件不用重新做决定**：

1. 建 `Sources/FeatureFoo/`，写 `FooModel.swift`（`@MainActor @Observable`）
   和 `FooView.swift`，照 `FeatureHome`（有存储）或 `FeatureToolbox`（纯函数）抄。
2. `Package.swift` 加一个 target，挂到 `LetItGo` 的 dependencies 上。
3. `AppCore/Navigation.swift` 的 `SidebarItem` 加一个 case。
4. 编译 —— `DetailView` 的 switch 是穷尽的，**编译器会报错提醒你**把新界面接上。
   这一步是故意的：不会出现「加了菜单但点进去是空白」。
5. 新界面如果有「主操作」，用 `.focusedSceneValue(\.newItemAction, …)` 登记一下，
   侧边栏 `+`、工具栏 `+`、⌘N 三个入口立刻对它生效，不用改壳。

「工具」那一组的逻辑层是纯函数：没有网络、不碰磁盘、没有依赖，所以整个可测 ——
测试全打在 `Codec` / `TimeConversion` / `Digest` / `RandomString` / `JSONFormatter` /
`JWT` / `RSA` 这七个 enum 上，界面层只负责摆。不好测的东西一律做成参数：
随机串把**随机源**做成参数（测试传定种子的），时间相关的一律把 `now` 做成参数 ——
于是「每类至少一个」「已过期 4 小时」这些性质可以真的断言。

---

## 里面怎么搭的

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
| **DesignSystem** | 设计令牌（间距 / 圆角 / 色阶 / 字号 / 动效）、组件、按钮样式 | 业务逻辑 |
| **Persistence** | `ItemRepository` 的**实现**（落盘 JSON + 内存两个 actor） | 界面、领域规则 |
| **FeatureHome** | 备忘板：`HomeModel` + `HomeView` + 卡片。有存储的功能照它抄 | 别的功能的东西 |
| **FeatureToolbox** | 七个工具一个模块 —— 它们共用同一套「输入 → 选项 → 结果」骨架 | 别的功能的东西 |
| **LetItGo** | 入口、Scene、侧边栏 / 详情路由、菜单、组合根 | 任何业务逻辑 |

依赖图写在 `Package.swift` 里，**编译器强制**单向：`AppCore` 引用不到任何人。

### 五条贯穿全项目的约定

1. **状态用 `@Observable`**，不用 `ObservableObject` —— 视图只因真正读到的属性重绘。
2. **依赖从 init 注入**，唯一 new 具体实现的地方是 `App/AppDependencies.swift`；
   测试里换掉某一项即可（见 `Tests/FeatureHomeTests` 的 `FailingItemRepository`）。
3. **只有跨界面共享的状态才进 `AppState`**，单个界面自己的状态属于它自己的 Model。
4. **读吞错，写抛错。** `load()` 失败就地显示错误态（反正整屏没内容，再弹个 alert
   只是让人多点一次「好」）；`create` / `delete` 失败**抛出去**，由壳弹全局 alert ——
   写操作是用户主动发起的，失败必须打断他。
5. **界面外的入口走 focused value，不走全局状态。** 界面用 `.focusedSceneValue`
   登记自己能做什么，侧边栏 / 工具栏 / 菜单用 `@FocusedValue` 读。**没人登记时是 nil**，
   入口自动变灰 —— 「⌘N 在概览变灰」「⌘⌫ 没选中时变灰」这两条行为，
   代码里没有任何一处 if 在判断分区或选中数。

换掉存储实现只需改 `AppDependencies.live()` 一行，上层一个字不动 ——
`Tests/AppCoreTests/FileItemRepositoryTests.swift` 那几条用例是写给**协议**的，
换实现时原样复用就能验证新实现。

---

## 常用命令

| 命令 | 作用 |
|---|---|
| `make build` | 编译（debug） |
| `make run` | 打包 + 启动 |
| `make app` | 只打包到 `build/LetItGo.app`（`SANDBOX=1` 带沙盒权限） |
| `make app-release` | release 版 `.app` |
| `make test` | 跑测试 |
| `make clean` | 清产物 |
| `make xcode` | 生成 `.xcodeproj`（需 Xcode + xcodegen） |

标志是**代码画的**：`Resources/Logo/mark.svg` 是本体，应用图标由
`Scripts/make_icon.swift` 生成（改造型只需改脚本里的几何参数再重跑），
`Scripts/bundle.sh` 会把它装进 `.app`。

---

## 当前环境的限制

开发这个项目的机器**只装了 Command Line Tools，没有 Xcode**。三个编译器宏插件
只随 Xcode 分发，所以做了对应处理 —— 装上 Xcode 后这些都可以换回标准写法：

| 用不了 | 这里的替代 | 装 Xcode 后 |
|---|---|---|
| `@Entry` | 手写 `EnvironmentKey` | 可换成 `@Entry`，行为一致 |
| `@Model`（SwiftData） | Repository 协议 + 落盘 JSON actor | 见 `Persistence/PersistenceNotes.swift` |
| `#Preview` | 用 `#if ENABLE_PREVIEWS` 包起来 | Xcode 工程会定义这个宏，预览自动生效 |
| `actool`（`.xcassets`） | 色板写在代码里；图标由脚本直接画成 `.icns` | 可以改用资源目录 |

`Makefile` 会自动检测 developer dir：切到完整 Xcode 之后，`make test` 里那几个
给 swift-testing 补搜索路径的参数会自动消失。

> `project.yml`（XcodeGen 那条路）尚未在真机验证过 —— 本机装不了 xcodegen。
> SwiftPM 这条路是完整跑通的。

---

## 目录

```
letitgo/
├── DESIGN.md                # 视觉规范（颜色 / 密度 / 组件 / 动效 / 六个坑）
├── PRODUCT.md               # 产品原则与无障碍要求
├── Package.swift            # 模块依赖图
├── Makefile                 # 命令入口
├── Sources/
│   ├── AppCore/             # 领域 + 状态 + DI 契约
│   ├── DesignSystem/        # 令牌 + 组件 + 三套色板
│   ├── Persistence/         # ItemRepository 实现
│   ├── FeatureHome/         # 备忘板
│   ├── FeatureToolbox/      # 编解码 / 时间戳 / 哈希 / 随机串 / JSON / JWT / RSA
│   └── LetItGo/             # 应用壳（入口 / 路由 / 菜单 / 设置）
├── Tests/                   # 162 条 swift-testing 用例
├── Resources/               # Info.plist / entitlements / 图标 / 标志
└── Scripts/                 # bundle.sh（→ .app）、make_icon.swift（→ .icns）
```
