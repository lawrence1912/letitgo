// swift-tools-version: 6.0
import PackageDescription

// 分层依赖（单向，不允许反向引用）:
//
//   LetItGo (app shell)
//        │
//        ├──> FeatureHome ──┐
//        ├──> Persistence ──┤
//        ├──> DesignSystem ─┤
//        └──────────────────┴──> AppCore   (领域模型 / 状态 / DI 契约)
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
        .executableTarget(
            name: "LetItGo",
            dependencies: ["AppCore", "DesignSystem", "Persistence", "FeatureHome"],
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
    ]
)
