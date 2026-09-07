import AppCore
import AppKit
import Observation
import SwiftUI
import Synchronization
import Testing

@testable import DesignSystem

@Suite("主题更新", .serialized)
@MainActor
struct ThemeObservationTests {
    @Test("切换主题会通知颜色消费者，并重新解析整套颜色")
    func themeChangesInvalidateColors() {
        let original = PaletteStore.shared.theme
        defer { Theme.apply(original) }

        let readers: [() -> Color] = [
            { Theme.Field.backdrop },
            { Theme.Ink.primary },
            { Theme.Brand.accentFill },
            { Theme.Surface.well },
            { Theme.Line.strong },
            { Tone.info.tint },
            { IconTint.neutral.tint },
        ]
        for read in readers {
            Theme.apply(.prism)
            let changed = Mutex(false)
            _ = withObservationTracking {
                read()
            } onChange: {
                changed.withLock { $0 = true }
            }
            Theme.apply(.nebula)
            #expect(changed.withLock { $0 })
        }

        for theme in AppTheme.allCases {
            Theme.apply(theme)
            for token in ColorToken.allCases {
                let appearance = NSAppearance(named: .darkAqua)!
                appearance.performAsCurrentDrawingAppearance {
                    let actual = token.nsColor.usingColorSpace(.sRGB)
                    let expected = Palette.of(theme).ramp(for: token).nsColor(for: appearance)
                    #expect(actual == expected.usingColorSpace(.sRGB))
                }
            }
        }
    }
}
