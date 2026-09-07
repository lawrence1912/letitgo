import AppKit
import SwiftUI
import Testing

@testable import DesignSystem

@Suite("光纹资源")
@MainActor
struct CausticContrastTests {
    @Test("打包光纹可读取，浅深外观正文对比度均不低于 4.5")
    func imageKeepsTextReadable() throws {
        let image = try #require(AmbientBackdrop.resourceBundle.image(forResource: "CausticEnvironment"))
        let bitmap = try #require(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        for (slot, opacity) in [(Slot.dark, AmbientBackdrop.darkTextureOpacity), (.light, AmbientBackdrop.lightTextureOpacity)] {
            let composite = Composite(theme: .prism, slot: slot)
            let base = composite.flat(.backdrop)
            let inks = [ColorToken.ink, .inkSecondary, .inkTertiary].map(composite.flat)
            var minimum = Double.infinity
            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide {
                    let pixel = try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                    let background = Composite.over(
                        RGB(r: pixel.redComponent, g: pixel.greenComponent, b: pixel.blueComponent, a: opacity),
                        base
                    )
                    for ink in inks {
                        minimum = min(minimum, composite.contrast(ink, background))
                    }
                }
            }
            #expect(minimum >= 4.5, "\(slot) 光纹最亮处的正文对比度仅 \(minimum)")
        }
    }
}
