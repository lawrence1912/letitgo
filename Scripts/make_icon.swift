// LetItGo 标志生成器 —— 标志即代码，可重复生成。
//
//   xcrun swift Scripts/make_icon.swift
//
// 产出：Resources/AppIcon.icns、Resources/Logo/{mark,icon}.svg
//
// 造型：字母 L 沿 45° 裂开一道缝，竖笔【垂直于缝】平移 —— 沿着缝平移
// 会重新粘合，这是第一版失败的原因。所有终端切口都平行于那道缝，
// 统一 45°，不留方切口。
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let C: CGFloat = 1024
let CONTAINER: CGFloat = 824      // Apple macOS 图标规范：容器占 824/1024，四周留白
typealias Poly = [CGPoint]
func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

func cleave(_ poly: Poly, _ c: CGFloat) -> (Poly, Poly) {
    func s(_ q: CGPoint) -> CGFloat { q.y - q.x - c }
    var lo: Poly = [], hi: Poly = []
    for i in 0..<poly.count {
        let a = poly[i], b = poly[(i + 1) % poly.count], sa = s(a), sb = s(b)
        if sa <= 0 { lo.append(a) }
        if sa >= 0 { hi.append(a) }
        if (sa < 0 && sb > 0) || (sa > 0 && sb < 0) {
            let t = sa / (sa - sb)
            let ix = p(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
            lo.append(ix); hi.append(ix)
        }
    }
    return (lo, hi)
}

/// 标志的两块多边形，居中缩放到 target
func markPolys(target: CGFloat) -> [Poly] {
    var base: Poly = [p(300, 744), p(478, 744), p(478, 430), p(770, 430), p(770, 280), p(300, 280)]
    base = cleave(base, 300).0        // 竖笔顶端 45° 斜切
    base = cleave(base, -320).1       // 横笔末端 45° 斜切
    let (foot, stem) = cleave(base, -20)              // 缝，正好穿过外角
    let d = 110 / 2.0.squareRoot()                    // 垂直于缝的位移分量
    var polys = [foot, stem.map { p($0.x - d, $0.y + d) }]
    let all = polys.flatMap { $0 }
    let (mnX, mxX) = (all.map(\.x).min()!, all.map(\.x).max()!)
    let (mnY, mxY) = (all.map(\.y).min()!, all.map(\.y).max()!)
    let s = target / max(mxX - mnX, mxY - mnY)
    let cx = (mnX + mxX) / 2, cy = (mnY + mxY) / 2
    polys = polys.map { $0.map { p(($0.x - cx) * s + C / 2, ($0.y - cy) * s + C / 2) } }
    return polys
}

func squirclePoints(size: CGFloat, n: CGFloat = 5, steps: Int = 360) -> Poly {
    let a = size / 2, c = C / 2
    return (0..<steps).map { i in
        let th = CGFloat(i) / CGFloat(steps) * 2 * .pi, ct = cos(th), st = sin(th)
        return p(c + a * (ct < 0 ? -1 : 1) * pow(abs(ct), 2 / n),
                 c + a * (st < 0 ? -1 : 1) * pow(abs(st), 2 / n))
    }
}
func cgPath(_ ps: [Poly]) -> CGPath {
    let pa = CGMutablePath()
    for poly in ps where poly.count > 2 {
        pa.move(to: poly[0]); for q in poly.dropFirst() { pa.addLine(to: q) }; pa.closeSubpath()
    }
    return pa
}

let glyph = markPolys(target: 475)       // 475/824 ≈ 0.58，与 Apple 模板的字形占比一致
let container = squirclePoints(size: CONTAINER)

func renderPNG(size: Int, to url: URL) {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: CGFloat(size) / C, y: CGFloat(size) / C)
    ctx.addPath(cgPath([container]))
    ctx.setFillColor(CGColor(red: 0.055, green: 0.055, blue: 0.066, alpha: 1))
    ctx.fillPath()
    ctx.addPath(cgPath(glyph))
    ctx.setFillColor(CGColor(red: 0.97, green: 0.97, blue: 0.975, alpha: 1))
    ctx.fillPath()
    let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(d)
}

// SVG 的 y 轴向下，翻转
func svgPoints(_ poly: Poly, ox: CGFloat = 0, oy: CGFloat = 0) -> String {
    poly.map { String(format: "%.1f,%.1f", $0.x - ox, C - $0.y - oy) }.joined(separator: " ")
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let logoDir = root.appendingPathComponent("Resources/Logo")
try? FileManager.default.createDirectory(at: logoDir, withIntermediateDirectories: true)

// mark.svg —— 只有字形，紧凑 viewBox，fill 用 currentColor，随处可用
let all = glyph.flatMap { $0 }
let (mnX, mxX) = (all.map(\.x).min()!, all.map(\.x).max()!)
let (mnY, mxY) = (all.map(\.y).min()!, all.map(\.y).max()!)
let vw = mxX - mnX, vh = mxY - mnY
let markSVG = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(String(format: "%.1f", vw)) \(String(format: "%.1f", vh))" fill="currentColor" role="img" aria-label="LetItGo">
\(glyph.map { "  <polygon points=\"\(svgPoints($0, ox: mnX, oy: C - mxY))\"/>" }.joined(separator: "\n"))
</svg>
"""
try markSVG.write(to: logoDir.appendingPathComponent("mark.svg"), atomically: true, encoding: .utf8)

// icon.svg —— 容器 + 字形，等同 .icns 的构图
let iconSVG = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="LetItGo app icon">
  <polygon fill="#0e0e11" points="\(svgPoints(container))"/>
\(glyph.map { "  <polygon fill=\"#f7f7f9\" points=\"\(svgPoints($0))\"/>" }.joined(separator: "\n"))
</svg>
"""
try iconSVG.write(to: logoDir.appendingPathComponent("icon.svg"), atomically: true, encoding: .utf8)

// iconset -> .icns
let iconset = root.appendingPathComponent("Resources/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for (base, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
    renderPNG(size: base * scale, to: iconset.appendingPathComponent(name))
}
print("生成完成：Resources/Logo/{mark,icon}.svg 与 Resources/AppIcon.iconset")
