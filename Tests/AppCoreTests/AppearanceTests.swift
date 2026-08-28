import Testing
import AppCore

@Suite("外观")
struct AppearanceTests {

    @Test("rawValue 是持久化契约，不能随便改")
    func rawValuesArePinned() {
        // 这三个字符串会写进 UserDefaults。改动 = 老用户的设置静默失效，
        // 且不会有任何编译错误提醒你。所以钉死在测试里。
        #expect(Appearance.system.rawValue == "system")
        #expect(Appearance.light.rawValue == "light")
        #expect(Appearance.dark.rawValue == "dark")
        #expect(Appearance.storageKey == "appearance")
    }

    @Test("分段控件的顺序是 跟随系统 → 浅色 → 深色")
    func caseOrderMatchesControlLayout() {
        // allCases 的顺序直接决定分段控件里三个图标的左右次序。
        #expect(Appearance.allCases == [.system, .light, .dark])
    }

    @Test("每个选项都有标题和图标")
    func everyCaseIsPresentable() {
        for option in Appearance.allCases {
            // 图标按钮靠 title 提供 VoiceOver 名称，空字符串会变成无名控件。
            #expect(!option.title.isEmpty)
            #expect(!option.systemImage.isEmpty)
        }
    }

    @Test("能从存进去的字符串还原")
    func roundTripsThroughRawValue() {
        for option in Appearance.allCases {
            #expect(Appearance(rawValue: option.rawValue) == option)
        }
    }

    @Test("读到无法识别的值时返回 nil，由调用方回落到默认")
    func rejectsUnknownRawValue() {
        #expect(Appearance(rawValue: "sepia") == nil)
    }
}
