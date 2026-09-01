import Testing
@testable import AppCore

@Suite("场景动作")
@MainActor
struct SceneActionTests {

    @Test("必须是 Equatable，且按 title 比较 —— 不然会把窗口拖进约束死循环")
    func equalityIsByTitle() {
        // 视图 body 每求值一次就造一个新闭包。如果 SwiftUI 判断不出
        // 「这还是同一个动作」，它会认为焦点值每帧都在变，于是
        // invalidate → setNeedsUpdate → 约束更新 → 重新求值 body → 又一个新闭包。
        // AppKit 撑不住会抛「Update Constraints in Window passes 超过视图数」，
        // 整个窗口带着应用一起崩 —— 而且编译器一句话都不会说。
        let first = SceneAction("新建条目") {}
        let second = SceneAction("新建条目") { print("完全不同的闭包") }
        #expect(first == second, "同名动作必须相等，否则每帧都会被当成新值")

        #expect(SceneAction("新建条目") {} != SceneAction("添加文件") {})
    }

    @Test("Optional 的 nil / 非 nil 切换仍然区分得开")
    func optionalTransitionsStillWork() {
        // 「没选中东西就登记 nil」靠的就是这个：菜单项要能正确地灰掉再亮起来。
        let none: SceneAction? = nil
        let some: SceneAction? = SceneAction("删除条目") {}
        #expect(none != some)
        #expect(none == SceneAction?.none)
    }

    @Test("title 就是菜单显示的文案")
    func titleIsWhatMenusShow() {
        #expect(SceneAction("添加文件") {}.title == "添加文件")
    }

    @Test("callAsFunction 真的会调到 handler")
    func invokesHandler() {
        final class Box { var hit = false }
        let box = Box()
        let action = SceneAction("跑一下") { box.hit = true }
        action()
        #expect(box.hit)
    }
}
