import SwiftUI

/// 固定绘制的控件表面，避免系统交互玻璃在切换、悬停时改变颜色与透明度。
@MainActor
enum ControlLighting {
    static var isPrism: Bool { PaletteStore.shared.theme == .prism }

    static let blueTop = Color(red: 0.08, green: 0.30, blue: 0.69)
    static let blueBottom = Color(red: 0.09, green: 0.11, blue: 0.36)

    static func foreground(emphasized: Bool) -> Color {
        emphasized && isPrism ? .white : Theme.Ink.primary
    }

    static func faceColors(emphasized: Bool, scheme: ColorScheme) -> [Color] {
        let colors: [Color]
        if emphasized && isPrism {
            colors = [blueTop, Color(red: 0.045, green: 0.15, blue: 0.43), blueBottom]
        } else if emphasized {
            colors = [Theme.Brand.accentSoft, Theme.Surface.well]
        } else if isPrism && scheme == .dark {
            colors = [Color(red: 0.045, green: 0.085, blue: 0.15),
                      Color(red: 0.025, green: 0.045, blue: 0.085)]
        } else {
            colors = [Theme.Surface.well, Theme.Field.backdrop]
        }
        return colors
    }

    static func face(emphasized: Bool, scheme: ColorScheme) -> LinearGradient {
        LinearGradient(colors: faceColors(emphasized: emphasized, scheme: scheme),
                       startPoint: .top, endPoint: .bottom)
    }
}

private struct RaisedControlSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    let emphasized: Bool
    let pressed: Bool
    let hovered: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled
    @State private var pointer: CGPoint?

    private var opaque: Bool { reduceTransparency || contrast == .increased }

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    if emphasized || opaque {
                        shape.fill(Theme.Surface.well)
                        shape.fill(ControlLighting.face(emphasized: emphasized, scheme: scheme))
                    } else {
                        shape.fill(.clear)
                            .glassEffect(.clear.tint(scheme == .dark ? Color.blue.opacity(0.10) : .white.opacity(0.12)), in: shape)
                        shape.fill(LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.025 : 0.18), .clear],
                                                  startPoint: .top, endPoint: .bottom))
                    }
                    shape.strokeBorder(
                        LinearGradient(colors: [.white.opacity(hovered ? 0.95 : 0.75),
                                                Theme.Brand.info.opacity(0.18), Theme.Brand.info.opacity(0.60)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: contrast == .increased ? 1.5 : 0.8
                    )
                    if !opaque {
                        shape.inset(by: 2).strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.35), .clear, .cyan.opacity(0.25)],
                                           startPoint: .top, endPoint: .bottom), lineWidth: 0.6
                        )
                        LiquidCaustics(seed: 1, compact: true).opacity(emphasized ? 0.8 : 0.4).clipShape(shape)
                        GeometryReader { proxy in
                            let point = reduceMotion ? nil : pointer
                            shape.strokeBorder(RadialGradient(
                                colors: [.white.opacity(hovered ? 0.75 : 0.2), .clear],
                                center: UnitPoint(x: (point?.x ?? 10) / max(proxy.size.width, 1),
                                                  y: (point?.y ?? 0) / max(proxy.size.height, 1)),
                                startRadius: 0, endRadius: 35
                            ), lineWidth: 1.2)
                        }
                    }
                }
                .shadow(color: .black.opacity(scheme == .dark ? 0.30 : 0.10), radius: pressed ? 2 : 5, y: pressed ? 1 : 3)
                .shadow(color: emphasized && !opaque ? .blue.opacity(scheme == .dark ? 0.25 : 0.10) : .clear,
                        radius: 4, y: 2)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .offset(y: pressed && !reduceMotion ? 1 : 0)
            .onContinuousHover { phase in
                guard enabled && !reduceMotion && !opaque else { pointer = nil; return }
                switch phase {
                case .active(let location): pointer = location
                case .ended: pointer = nil
                }
            }
            .transaction { $0.animation = nil }
    }
}

extension View {
    func raisedControl<S: InsettableShape>(
        in shape: S, emphasized: Bool = false, pressed: Bool = false, hovered: Bool = false
    ) -> some View {
        modifier(RaisedControlSurface(shape: shape, emphasized: emphasized, pressed: pressed, hovered: hovered))
    }
}
