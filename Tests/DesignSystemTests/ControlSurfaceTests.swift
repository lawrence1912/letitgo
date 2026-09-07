import AppCore
import AppKit
import SwiftUI
import Testing
@testable import DesignSystem

@Suite("固定控件配色")
@MainActor
struct ControlSurfaceTests {
    @Test("主按钮与选中按钮的文字在各主题浅深外观均可读", arguments: AppTheme.allCases)
    func controlTextContrast(theme: AppTheme) throws {
        let original = PaletteStore.shared.theme
        defer { Theme.apply(original) }
        Theme.apply(theme)
        for (scheme, appearanceName) in [(ColorScheme.dark, NSAppearance.Name.darkAqua), (.light, .aqua)] {
            let appearance = try #require(NSAppearance(named: appearanceName))
            appearance.performAsCurrentDrawingAppearance {
                let emphasized = true
                let foreground = rgb(ControlLighting.foreground(emphasized: emphasized))
                let underlay = rgb(Theme.Surface.well)
                for face in ControlLighting.faceColors(emphasized: emphasized, scheme: scheme) {
                    let background = Composite.over(rgb(face), underlay)
                    let ratio = Composite(theme: theme, slot: scheme == .dark ? .dark : .light)
                        .contrast(foreground, background)
                    #expect(ratio >= 4.5, "\(theme)/\(scheme)/\(emphasized) 控件文字对比度为 \(ratio)")
                }
            }
        }
    }

    private func rgb(_ color: Color) -> RGB {
        let resolved = NSColor(color).usingColorSpace(.sRGB)!
        return RGB(r: resolved.redComponent, g: resolved.greenComponent,
                   b: resolved.blueComponent, a: resolved.alphaComponent)
    }
}
