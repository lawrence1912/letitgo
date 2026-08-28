import SwiftUI

// 依赖容器通过 SwiftUI Environment 往下传，视图侧写:
//
//     @Environment(\.dependencies) private var dependencies
//
// 注：Xcode 里可以用 `@Entry` 宏一行搞定这段样板，但 SwiftUIMacros
// 插件只随 Xcode 分发，纯 Command Line Tools 环境下用不了，
// 所以这里手写 EnvironmentKey（行为完全一致）。
private struct DependenciesKey: EnvironmentKey {
    static let defaultValue = Dependencies.preview
}

extension EnvironmentValues {
    public var dependencies: Dependencies {
        get { self[DependenciesKey.self] }
        set { self[DependenciesKey.self] = newValue }
    }
}
