// Generates Resources/AppIcon.icns: a timer glyph on a rounded-rect gradient.
// Run from the repo root: swift scripts/icon.swift
import AppKit

func render(_ pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // macOS icon canvas: content squircle inset ~10% on each side
    let s = CGFloat(pixels)
    let inset = s * 100 / 1024
    let rect = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 232 / 824, yRadius: rect.width * 232 / 824)
    let top = NSColor(calibratedRed: 0.62, green: 0.42, blue: 0.95, alpha: 1)
    let bottom = NSColor(calibratedRed: 0.38, green: 0.16, blue: 0.72, alpha: 1)
    NSGradient(starting: top, ending: bottom)!.draw(in: path, angle: -90)

    // White timer symbol centered on the squircle
    let config = NSImage.SymbolConfiguration(pointSize: rect.width * 0.5, weight: .medium)
    if let symbol = NSImage(systemSymbolName: "timer", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let tinted = NSImage(size: symbol.size)
        tinted.lockFocus()
        symbol.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
        NSColor.white.set()
        NSRect(origin: .zero, size: symbol.size).fill(using: .sourceAtop)
        tinted.unlockFocus()
        let target = rect.width * 0.58
        let scale = target / max(symbol.size.width, symbol.size.height)
        let w = symbol.size.width * scale, h = symbol.size.height * scale
        tinted.draw(in: NSRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h),
                    from: .zero, operation: .sourceOver, fraction: 1)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let iconset = URL(fileURLWithPath: "/tmp/Timely.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        let png = render(size * scale).representation(using: .png, properties: [:])!
        try! png.write(to: iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try! task.run()
task.waitUntilExit()
print(task.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
