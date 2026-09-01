// swift-tools-version: 6.0
import PackageDescription

// 分层依赖（单向，不允许反向引用）:
//
//   LetItGo (app shell)
//        │
//        ├──> FeatureHome ────┐   功能模块
//        ├──> FeatureToolbox ─┤
//        ├──> Persistence ────┤   实现（存储）
//        ├──> DesignSystem ───┤
//        └────────────────────┴──> AppCore   (领域模型 / 状态 / DI 契约)
//
// 新增功能模块时: 在 Sources/Feature<Name> 建目录，加一个 .target，
// 依赖 AppCore + DesignSystem，然后只在 app shell 里接线。

let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),          // Swift 6 严格并发
    .enableUpcomingFeature("ExistentialAny"),
]

let package = Package(
    name: "LetItGo",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AppCore", targets: ["AppCore"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "FeatureHome", targets: ["FeatureHome"]),
        .library(name: "FeatureToolbox", targets: ["FeatureToolbox"]),
    ],
    targets: [
        .target(
            name: "AppCore",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "DesignSystem",
            dependencies: ["AppCore"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "Persistence",
            dependencies: ["AppCore"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "FeatureHome",
            dependencies: ["AppCore", "DesignSystem"],
            swiftSettings: swiftSettings
        ),
        // 开发者日常小工具（编解码 / 时间戳 / 哈希）。三个工具一个模块：
        // 它们共用同一套「输入 → 选项 → 结果」的骨架，拆成三个模块只会把
        // 那套骨架抄三遍。
        .target(
            name: "FeatureToolbox",
            dependencies: ["AppCore", "DesignSystem"],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "LetItGo",
            dependencies: [
                "AppCore", "DesignSystem",
                "Persistence",
                "FeatureHome", "FeatureToolbox",
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "DesignSystemTests",
            dependencies: ["DesignSystem"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "AppCoreTests",
            dependencies: ["AppCore", "Persistence"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "FeatureHomeTests",
            dependencies: ["FeatureHome", "Persistence"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "FeatureToolboxTests",
            dependencies: ["FeatureToolbox"],
            swiftSettings: swiftSettings
        ),
    ]
)
