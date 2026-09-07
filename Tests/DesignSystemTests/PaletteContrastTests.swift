import AppCore
import Foundation
import Testing

@testable import DesignSystem

/// 把 DESIGN.md 里「对比度是算过的」那句话变成会失败的东西。
///
/// ## 这一版能算的东西少了，但每一条都还是真的
///
/// 换成系统 Liquid Glass 之后，「一段文字的实际底色」不再是我们能算出来的
/// 东西了 —— 系统材质怎么混是它自己的事。上一版那套「氛围底 → 六层薄膜 →
/// 文字」的合成链因此整个作废。
///
/// 于是这套测试退回到两块**还归自己画**的底（见 `Surface`）：
///
///   - **氛围场**：玻璃背后那一层。它是下界 —— 直接压在它上面都读得清的字，
///     隔着玻璃也读得清。
///   - **读写面**：代码框、结果区。不透明，能精确算，而且一屏上要逐字读的
///     东西全在这儿。
///
/// 少掉的那些（薄膜的浓度、斜光、宝石那三层、辉光）不是放宽了门槛，
/// 是那些层**不存在了**。
@Suite("色板对比度")
struct PaletteContrastTests {

    // MARK: - 正文

    @Test("正文级文字在两块底上都 ≥ 4.5:1", arguments: AppTheme.allCases)
    func bodyTextIsReadable(theme: AppTheme) {
        for slot in Slot.normal {
            let sheet = Composite(theme: theme, slot: slot)
            for text in ColorToken.bodyLevelText {
                let (surface, ratio) = sheet.worstSurface(for: text)
                #expect(
                    ratio >= 4.5,
                    "\(theme.rawValue)/\(slot) 的 \(text.rawValue) 压在 \(surface.rawValue) 上只有 \(round(ratio * 100) / 100):1"
                )
            }
        }
    }

    /// 最轻的那一档也得压住正文线 —— 它出现在 placeholder、单位、⌘ 编号上，
    /// 那些都是要读的字，不是花纹。
    @Test("最轻的一档文字也压得住正文", arguments: AppTheme.allCases)
    func lightestInkStillClearsBodyContrast(theme: AppTheme) {
        for slot in Slot.all {
            let sheet = Composite(theme: theme, slot: slot)
            // 增强对比度那两档要再高一截，否则「开了增强对比度」等于没开。
            let floor = Slot.highContrast.contains(slot) ? 6.0 : 4.5
            let (surface, ratio) = sheet.worstSurface(for: .inkTertiary)
            #expect(
                ratio >= floor,
                "\(theme.rawValue)/\(slot) 的三级文字压在 \(surface.rawValue) 上只有 \(ratio)"
            )
        }
    }

    // MARK: - 实色兜底面
    //
    // `Surface.well` 现在只剩一个用途：**被拎出窗口之外**的东西。
    // 拖动待办卡时跟着鼠标走的那一小块是 AppKit 单独截图画的，背后没有氛围场 ——
    // 玻璃在那儿会折射出一块灰板，所以它走实色。
    //
    // 「那一块必须是实色」是条设计约束。约束写在注释里会烂掉，写成测试就不会。

    @Test("实色兜底面必须是不透明的", arguments: AppTheme.allCases)
    func opaqueFallbackSurfaceIsOpaque(theme: AppTheme) {
        for slot in Slot.all {
            let alpha = Palette.of(theme).ramp(for: .well).value(slot).alpha
            #expect(alpha == 1, "\(theme.rawValue)/\(slot) 的兜底面 alpha 是 \(alpha)，拖拽预览会露底")
        }
    }

    // MARK: - 色调块
    //
    // 徽章 / 提示条：色调文字压在同色调的浅底上。那块浅底现在是**玻璃的 tint**，
    // 所以这里算的是个偏保守的近似（理由见 `Composite.worstToneFill`）。

    @Test("徽章 / 提示条上的色调文字 ≥ 4.5:1", arguments: AppTheme.allCases)
    func toneTextOnItsOwnSoftFillIsReadable(theme: AppTheme) {
        for slot in Slot.normal {
            let sheet = Composite(theme: theme, slot: slot)
            for (tint, soft) in ColorToken.tonePairs {
                let ratio = sheet.worstToneFill(tint: tint, soft: soft)
                #expect(ratio >= 4.5, "\(theme.rawValue)/\(slot) 的 \(tint.rawValue) 压在 \(soft.rawValue) 上只有 \(ratio)")
            }
        }
    }

    // MARK: - 彩色图标
    //
    // 图标色是**辨识**用的（哪一个分区），不是语义用的（成功 / 失败）。
    // 但它一样要读得清 —— 一枚看不见的图标不能帮你找到任何东西。

    @Test("彩色图标在两块底上都 ≥ 4.5:1", arguments: AppTheme.allCases)
    func iconTintsAreVisibleOnEverySurface(theme: AppTheme) {
        for slot in Slot.normal {
            let sheet = Composite(theme: theme, slot: slot)
            for tint in IconTint.allCases {
                let (surface, ratio) = sheet.worstSurface(forInk: sheet.icon(tint, .tint))
                #expect(
                    ratio >= 4.5,
                    "\(theme.rawValue)/\(slot) 的 \(tint.rawValue) 图标压在 \(surface.rawValue) 上只有 \(ratio)"
                )
            }
        }
    }

    @Test("图标压在自己那块底板上 ≥ 4.5:1", arguments: AppTheme.allCases)
    func iconTintsAreVisibleOnTheirOwnTile(theme: AppTheme) {
        for slot in Slot.normal {
            let sheet = Composite(theme: theme, slot: slot)
            for tint in IconTint.allCases {
                let ratio = sheet.worstToneFill(
                    ink: sheet.icon(tint, .tint),
                    fill: sheet.icon(tint, .soft)
                )
                #expect(ratio >= 4.5, "\(theme.rawValue)/\(slot) 的 \(tint.rawValue) 图标在自己底板上只有 \(ratio)")
            }
        }
    }

    @Test("增强对比度下彩色图标 ≥ 7:1", arguments: AppTheme.allCases)
    func iconTintsClearSevenToOneInHighContrast(theme: AppTheme) {
        for slot in Slot.highContrast {
            let sheet = Composite(theme: theme, slot: slot)
            for tint in IconTint.allCases {
                let (surface, ratio) = sheet.worstSurface(forInk: sheet.icon(tint, .tint))
                #expect(ratio >= 7.0, "\(theme.rawValue)/\(slot) 的 \(tint.rawValue) 压在 \(surface.rawValue) 上只有 \(ratio)")
            }
        }
    }

    // MARK: - 当前选中
    //
    // 「你现在在这儿」这一版是**一块上了色的玻璃**：边栏的选中行、
    // 主题选择器选中的那格、选中的待办卡，三处都是 `accentSoft` 当 tint。
    //
    // 上一版这里测的是「主按钮的字压在强调色渐变的两端上」。那条没了 ——
    // 主按钮改用系统的 `.glassProminent`，底色和前景色都由系统按 `.tint()`
    // 自己配，不再是我们画的一块渐变。
    //
    // 换上来的是这一条，而且它测的是**真正会出问题**的那件事：选中块上压的
    // 不是强调色的字，是**正文**（分区名、待办的内容）。浅底一浓，那行字就糊了。

    @Test("选中块上压的正文仍然读得清", arguments: AppTheme.allCases)
    func inkStaysReadableOnTheSelectionTint(theme: AppTheme) {
        for slot in Slot.normal {
            let sheet = Composite(theme: theme, slot: slot)
            for ink in [ColorToken.ink, .inkSecondary] {
                let ratio = sheet.worstToneFill(ink: sheet.flat(ink), fill: sheet.flat(.accentSoft))
                #expect(
                    ratio >= 4.5,
                    "\(theme.rawValue)/\(slot) 的 \(ink.rawValue) 压在选中块上只有 \(ratio)"
                )
            }
        }
    }

    // MARK: - 焦点

    /// 「光标在哪儿」是键盘用户唯一的方位信息，它读不出来就是个可用性 bug。
    ///
    /// 这一条现在是**精确**的：输入框的底是不透明的读写面（`field()` 就画在
    /// `Surface.well` 上），不再隔着一层算不准的薄膜。
    ///
    /// 门槛取 3:1 —— 非文字图形元素那一档，不是正文的 4.5。
    @Test("焦点环压在输入框自己那块底上 ≥ 3:1", arguments: AppTheme.allCases)
    func focusRingIsVisibleOnItsOwnField(theme: AppTheme) {
        for slot in Slot.all {
            let sheet = Composite(theme: theme, slot: slot)
            let ring = sheet.flat(.focusRing)
            let worst = sheet.samples(of: .well).map { sheet.contrast(ring, $0) }.min() ?? .infinity
            #expect(worst >= 3.0, "\(theme.rawValue)/\(slot) 的焦点环在输入框上只有 \(worst)")
        }
    }

    // MARK: - 增强对比度

    @Test("增强对比度下正文 ≥ 7:1", arguments: AppTheme.allCases)
    func highContrastAppearancesClearSevenToOne(theme: AppTheme) {
        for slot in Slot.highContrast {
            let sheet = Composite(theme: theme, slot: slot)
            for text in ColorToken.bodyLevelText {
                let (surface, ratio) = sheet.worstSurface(for: text)
                #expect(ratio >= 7.0, "\(theme.rawValue)/\(slot) 的 \(text.rawValue) 压在 \(surface.rawValue) 上只有 \(ratio)")
            }
        }
    }

    @Test("增强对比度下光晕和网格全部归零", arguments: AppTheme.allCases)
    func highContrastDropsEveryWash(theme: AppTheme) {
        let palette = Palette.of(theme)
        for token in ColorToken.ambientWashes {
            for slot in Slot.highContrast {
                #expect(
                    palette.ramp(for: token).value(slot).alpha == 0,
                    "\(theme.rawValue) 的 \(token.rawValue) 在 \(slot) 下还没归零"
                )
            }
        }
    }
}
