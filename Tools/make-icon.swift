import AppKit

/// Draws the STyLer app icon and writes it as an .icns file: make-icon <out.icns>
func drawIcon(_ ctx: CGContext) {
    let rect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let body = CGPath(roundedRect: rect, cornerWidth: 184, cornerHeight: 184, transform: nil)
    ctx.saveGState()
    ctx.addPath(body)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [CGColor(red: 0.20, green: 0.26, blue: 0.38, alpha: 1), CGColor(red: 0.07, green: 0.09, blue: 0.16, alpha: 1)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()

    let cx: CGFloat = 512, cy: CGFloat = 540, s: CGFloat = 270, w = s * 0.866
    let top = CGPoint(x: cx, y: cy + s), bottom = CGPoint(x: cx, y: cy - s), mid = CGPoint(x: cx, y: cy)
    let ur = CGPoint(x: cx + w, y: cy + s / 2), lr = CGPoint(x: cx + w, y: cy - s / 2)
    let ul = CGPoint(x: cx - w, y: cy + s / 2), ll = CGPoint(x: cx - w, y: cy - s / 2)
    let faces: [([CGPoint], CGColor)] = [
        ([top, ur, mid, ul], CGColor(gray: 0.92, alpha: 1)),
        ([ul, mid, bottom, ll], CGColor(gray: 0.68, alpha: 1)),
        ([mid, ur, lr, bottom], CGColor(gray: 0.46, alpha: 1)),
    ]
    ctx.setLineJoin(.round)
    ctx.setLineWidth(10)
    for (points, color) in faces {
        ctx.setFillColor(color)
        ctx.setStrokeColor(color)
        ctx.addLines(between: points)
        ctx.closePath()
        ctx.drawPath(using: .fillStroke)
    }

    let pill = CGRect(x: 560, y: 190, width: 300, height: 150)
    ctx.setFillColor(CGColor(gray: 0.08, alpha: 0.9))
    ctx.addPath(CGPath(roundedRect: pill, cornerWidth: 75, cornerHeight: 75, transform: nil))
    ctx.fillPath()
    let label = NSAttributedString(string: "STL", attributes: [.font: NSFont.systemFont(ofSize: 100, weight: .bold), .foregroundColor: NSColor.white])
    let size = label.size()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    label.draw(at: CGPoint(x: pill.midX - size.width / 2, y: pill.midY - size.height / 2))
    NSGraphicsContext.restoreGraphicsState()
}

func png(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let g = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = g
    g.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    drawIcon(g.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

guard CommandLine.arguments.count == 2 else { print("usage: make-icon <out.icns>"); exit(1) }
let out = URL(fileURLWithPath: CommandLine.arguments[1])
let set = out.deletingPathExtension().appendingPathExtension("iconset")
try FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128), ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    try png(pixels: px).write(to: set.appendingPathComponent("icon_\(name).png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", set.path, "-o", out.path]
try p.run()
p.waitUntilExit()
try? FileManager.default.removeItem(at: set)
exit(p.terminationStatus)
