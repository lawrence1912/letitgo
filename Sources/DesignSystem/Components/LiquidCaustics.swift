import SwiftUI

/// 同一入射光下的弯曲光带：上方白光、左下青色、下沿紫色，右下少量暖色。
/// 变化只影响曲率和长度，不改变光源方向；中心留给正文。
struct LiquidCaustics: View {
    var seed: UInt64 = 0
    var compact = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let bend = Double(seed % 7) / 6
            let depth = min(h * 0.13, compact ? 3 : 9)
            let light = LinearGradient(stops: [
                .init(color: .white.opacity(0.9), location: 0),
                .init(color: .cyan.opacity(0.75), location: 0.25),
                .init(color: Color(red: 0.55, green: 0.4, blue: 1).opacity(0.7), location: 0.72),
                .init(color: (seed % 3 == 0 ? Color.orange : Color.blue).opacity(0.45), location: 1),
            ], startPoint: .leading, endPoint: .trailing)
            let ribbon = Path { p in
                p.move(to: CGPoint(x: 4, y: h * 0.26))
                p.addCurve(to: CGPoint(x: w * (0.42 + bend * 0.22), y: 3),
                           control1: CGPoint(x: 3, y: -5),
                           control2: CGPoint(x: w * 0.24, y: depth))
                p.move(to: CGPoint(x: 5, y: h * 0.73))
                p.addCurve(to: CGPoint(x: w * 0.35, y: h - depth),
                           control1: CGPoint(x: 10, y: h + 2),
                           control2: CGPoint(x: w * 0.18, y: h - depth * 1.8))
                p.addCurve(to: CGPoint(x: w - 5, y: h * (0.62 + bend * 0.14)),
                           control1: CGPoint(x: w * 0.66, y: h + depth),
                           control2: CGPoint(x: w - 8, y: h - depth * 0.4))
            }
            ZStack {
                ribbon.stroke(light, style: StrokeStyle(lineWidth: compact ? 3 : 6, lineCap: .round))
                    .blur(radius: compact ? 1.5 : 3).opacity(0.38)
                ribbon.stroke(light, style: StrokeStyle(lineWidth: compact ? 0.6 : 1.1, lineCap: .round))
                ribbon.stroke(light, lineWidth: 0.5).offset(x: 1, y: -2).opacity(0.24)
            }
            .mask {
                LinearGradient(stops: [
                    .init(color: .white, location: 0),
                    .init(color: .white.opacity(0.75), location: 0.16),
                    .init(color: .white.opacity(0.08), location: 0.42),
                    .init(color: .white.opacity(0.35), location: 0.68),
                    .init(color: .white, location: 0.91),
                ], startPoint: .leading, endPoint: .trailing)
            }
            .opacity(scheme == .dark ? 0.95 : 0.75)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
