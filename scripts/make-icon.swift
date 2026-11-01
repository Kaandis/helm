// Draws Helm's app icon: a ship's helm, the wheel Helm opens under the
// pointer. On the cream squircle the Harbor apps share.
// Usage: swift scripts/make-icon.swift <output-dir>
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-out")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func color(_ hex: Int, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).cgPath
}

func draw(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    let cg = context.cgContext
    cg.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)

    // Body.
    let body = rounded(CGRect(x: 100, y: 100, width: 824, height: 824), 185)
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0x000000, 0.22))
    cg.addPath(body)
    cg.setFillColor(color(0xf6e7d6))
    cg.fillPath()
    cg.restoreGState()
    cg.saveGState()
    cg.addPath(body)
    cg.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [color(0xfdf3e8), color(0xf1dfc8)] as CFArray, locations: [0, 1])!
    cg.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // The helm: eight spokes with turned handles past a thick rim, around
    // a hub in harbour teal.
    let center = CGPoint(x: 512, y: 512)
    let ink = color(0x231f1c)
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -10), blur: 22, color: color(0x3a2a1c, 0.28))
    cg.beginTransparencyLayer(auxiliaryInfo: nil)
    cg.setStrokeColor(ink)
    cg.setLineCap(.round)
    for index in 0..<8 {
        let angle = CGFloat(index) * .pi / 4 + .pi / 2
        let direction = CGPoint(x: cos(angle), y: sin(angle))
        func point(_ r: CGFloat) -> CGPoint { CGPoint(x: center.x + direction.x * r, y: center.y + direction.y * r) }
        cg.setLineWidth(30)
        cg.move(to: point(60)); cg.addLine(to: point(250)); cg.strokePath()
        cg.setLineWidth(50)
        cg.move(to: point(262)); cg.addLine(to: point(318)); cg.strokePath()
    }
    cg.setLineWidth(46)
    cg.strokeEllipse(in: CGRect(x: center.x - 200, y: center.y - 200, width: 400, height: 400))
    cg.setFillColor(ink)
    cg.fillEllipse(in: CGRect(x: center.x - 84, y: center.y - 84, width: 168, height: 168))
    cg.endTransparencyLayer()
    cg.restoreGState()
    cg.setFillColor(color(0x6cc3cf))
    cg.fillEllipse(in: CGRect(x: center.x - 44, y: center.y - 44, width: 88, height: 88))
    cg.restoreGState()

    context.flushGraphics()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = out.appendingPathComponent("AppIcon.appiconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
var images: [[String: String]] = []
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(base)x\(base)@\(scale)x.png"
        try! draw(size: base * scale).write(to: iconset.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(base)x\(base)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: iconset.appendingPathComponent("Contents.json"))
try! draw(size: 512).write(to: out.appendingPathComponent("icon.png"))
try! draw(size: 180).write(to: out.appendingPathComponent("apple-touch-icon.png"))
try! draw(size: 64).write(to: out.appendingPathComponent("favicon.png"))
print("wrote \(out.path)")
