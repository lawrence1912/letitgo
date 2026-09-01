import SwiftUI

/// 应用标志：字母 L 沿 45° 裂开一道缝，竖笔垂直于缝平移。
///
/// 多边形和 `Scripts/make_icon.swift` 生成的 `Resources/Logo/mark.svg` 是同一份 ——
/// 那边产出 .icns（Dock 图标），这里是界面里的矢量版。**改造型要两边一起改**，
/// 否则 Dock 上的图标和侧边栏里的标志会长得不一样。
public struct BrandMark: Shape {

    /// mark.svg 的 viewBox。
    private static let viewBox = CGSize(width: 462.7, height: 475.0)

    private static let polygons: [[CGPoint]] = [
        [
            CGPoint(x: 224.3, y: 318.9), CGPoint(x: 224.3, y: 343.5),
            CGPoint(x: 462.7, y: 343.5), CGPoint(x: 331.2, y: 475.0),
            CGPoint(x: 68.2, y: 475.0),
        ],
        [
            CGPoint(x: 126.3, y: 0.0), CGPoint(x: 156.1, y: 0.0),
            CGPoint(x: 156.1, y: 250.7), CGPoint(x: 0.0, y: 406.8),
            CGPoint(x: 0.0, y: 126.3),
        ],
    ]

    public init() {}

    public func path(in rect: CGRect) -> Path {
        let scale = min(rect.width / Self.viewBox.width, rect.height / Self.viewBox.height)
        let size = CGSize(width: Self.viewBox.width * scale, height: Self.viewBox.height * scale)
        let origin = CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)

        func place(_ point: CGPoint) -> CGPoint {
            CGPoint(x: origin.x + point.x * scale, y: origin.y + point.y * scale)
        }

        var path = Path()
        for polygon in Self.polygons {
            guard let first = polygon.first else { continue }
            path.move(to: place(first))
            for point in polygon.dropFirst() { path.addLine(to: place(point)) }
            path.closeSubpath()
        }
        return path
    }
}
