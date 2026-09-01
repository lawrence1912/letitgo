import AppCore
import Foundation
import Testing

@testable import DesignSystem

/// 把 DESIGN.md 里「对比度是算过的」那句话变成会失败的东西。
///
/// 玻璃让这件事没法靠眼睛判断：一段文字的实际底色是**合成**出来的 ——
/// 氛围底（可能还压着一团光晕）→ 每一层薄膜 → 它自己。手算一遍要几十格，
/// 换一次色值就得重算一遍，靠人是守不住的。
///
/// 所以这里把整个合成过程照着绘制时的顺序跑一遍，对**每个「文字 × 表面」组合**
/// 取最差的一格，逐条比底线。加新主题时这套测试自动覆盖它
/// （`arguments: AppTheme.allCases`）。
@Suite("色板对比度")
struct PaletteContrastTests {

    // MARK: - 正文

    @Test("正文级文字在任何表面上都 ≥ 4.5:1", arguments: AppTheme.allCases)
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

    @Test("装饰级文字 ≥ 3:1（它只配大号 / 装饰性文字）", arguments: AppTheme.allCases)
    func decorativeTextClearsItsLowerFloor(theme: AppTheme) {
        for slot in Slot.normal {
            let sheet = Composite(theme: theme, slot: slot)
            let (surface, ratio) = sheet.worstSurface(for: .inkTertiary)
            #expect(ratio >= 3.0, "\(theme.rawValue)/\(slot) 的三级文字压在 \(surface.rawValue) 上只有 \(ratio)")
        }
    }

    // MARK: - 色调块
    //
    // 徽章 / 提示条 / 选中项：色调文字压在**同色调的浅底**上，
    // 而那块浅底本身也是半透明的 —— 底下是什么，结果就偏向什么。

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

    @Test("彩色图标在任何表面上都 ≥ 4.5:1", arguments: AppTheme.allCases)
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

    // MARK: - 主按钮
    //
    // 唯一一处实心填充。它不参与玻璃合成（本来就不透明），
    // 但它是全屏最响的一块，压在上面的字必须最稳。

    @Test("主按钮的字压在实心强调色上 ≥ 7:1", arguments: AppTheme.allCases)
    func primaryButtonLabelIsSolid(theme: AppTheme) {
        for slot in Slot.all {
            let sheet = Composite(theme: theme, slot: slot)
            let ratio = sheet.contrast(sheet.flat(.onAccent), sheet.flat(.accentFill))
            #expect(ratio >= 7.0, "\(theme.rawValue)/\(slot) 的主按钮只有 \(ratio):1")
        }
    }

    // MARK: - 增强对比度
    //
    // 这两档外观下薄膜的 alpha 是 1（玻璃整套让位），所以合成结果就是实心色阶本身，
    // 门槛也高一档：正文 ≥ 7:1。

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

    @Test("增强对比度下薄膜必须是不透明的", arguments: AppTheme.allCases)
    func highContrastDropsTheGlass(theme: AppTheme) {
        let palette = Palette.of(theme)
        for token in ColorToken.films {
            for slot in Slot.highContrast {
                #expect(
                    palette.ramp(for: token).value(slot).alpha == 1,
                    "\(theme.rawValue) 的 \(token.rawValue) 在 \(slot) 下还是半透明的"
                )
            }
        }
    }

    // MARK: - 层次

    @Test("四层表面的明暗关系每套主题都一致", arguments: AppTheme.allCases)
    func surfaceHierarchyHoldsInBothAppearances(theme: AppTheme) {
        for slot in Slot.normal {
            let sheet = Composite(theme: theme, slot: slot)
            // 外壳比内容暗一档；面板浮在内容之上；槽陷进内容之下。
            #expect(sheet.luminance(.canvasSurface) < sheet.luminance(.contentSurface))
            #expect(sheet.luminance(.contentSurface) < sheet.luminance(.raisedSurface))
            #expect(sheet.luminance(.sunkenSurface) < sheet.luminance(.contentSurface))
        }
    }
}
