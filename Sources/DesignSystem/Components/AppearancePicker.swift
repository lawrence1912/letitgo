import AppCore
import SwiftUI

/// 外观切换控件。侧边栏底栏和设置窗口用的是**同一个**组件 ——
/// 同一功能在两处长得不一样，必有一处是错的。
///
/// 和 `SegmentedPicker` 一样交还给了系统（理由见那个文件）。
/// 上一版这里是**整个应用里唯一一个强调色滑块**，用来说明「外观是应用级开关，
/// 不是功能内部的选项」。这一版没有这个区分了，也不需要 ——
/// 位置本来就在说这件事：它待在侧边栏底栏和设置窗口里，
/// 而功能内部的选项待在工具页上。用颜色再说一遍是多余的。
///
/// 状态存在 UserDefaults，`@AppStorage` 保证多处实例自动同步 ——
/// 在设置里改，侧边栏的分段会跟着动，反之亦然。
public struct AppearancePicker: View {
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .system

    public init() {}

    public var body: some View {
        SegmentTrack(label: "外观") {
            ForEach(Appearance.allCases) { option in
                SegmentItem(
                    name: option.title,
                    isSelected: appearance == option
                ) {
                    appearance = option
                } label: {
                    // 三个图标一样宽，切换时控件的宽度保持不变。
                    Image(systemName: option.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 18)
                }
                // 纯图标的项必须有 tooltip；VoiceOver 那边名字已经够了。
                .help(option.title)
            }
        }
        .help("外观：跟随系统 / 浅色 / 深色")
    }
}

// Preview 需要 Xcode 的 PreviewsMacros 插件，纯 Command Line Tools 编不过。
// ENABLE_PREVIEWS 只由 Xcode 工程（project.yml）定义，`swift build` 下自动跳过。
#if ENABLE_PREVIEWS
#Preview {
    AppearancePicker().padding(Theme.Spacing.xl)
}
#endif
