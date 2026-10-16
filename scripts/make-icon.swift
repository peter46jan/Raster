// Tekent het app-icoon van Raster (1024×1024) naar het opgegeven PNG-pad: een groenblauw lichaam met een raster
// van 2 × 2 vakken, waarvan het vak linksboven helder wit is.
// Gebruik: swift scripts/make-icon.swift <uit.png>
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.dropFirst().first ?? "icon.png"

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(
    data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0, space: space,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
// Tekenen met y omlaag: bovenkant = y 0.
ctx.translateBy(x: 0, y: size)
ctx.scaleBy(x: 1, y: -1)

// macOS-raster: het lichaam is 824×824 met 100 px marge.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = roundedRect(body, radius: 185)

// Schaduw onder het icoon.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 14), blur: 28, color: color(0x000000, 0.35))
ctx.addPath(bodyPath)
ctx.setFillColor(color(0x0A4F55))
ctx.fillPath()
ctx.restoreGState()

// Achtergrond: van licht groenblauw linksboven naar diep petrol rechtsonder.
ctx.saveGState()
ctx.addPath(bodyPath)
ctx.clip()
let background = CGGradient(
    colorsSpace: space, colors: [color(0x23A39C), color(0x0D7A7A), color(0x08474F)] as CFArray,
    locations: [0, 0.5, 1])!
ctx.drawLinearGradient(background, start: CGPoint(x: 180, y: 100), end: CGPoint(x: 844, y: 924),
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
// Zacht licht van boven.
let glow = CGGradient(
    colorsSpace: space, colors: [color(0xFFFFFF, 0.22), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(
    glow, startCenter: CGPoint(x: 512, y: 80), startRadius: 0, endCenter: CGPoint(x: 512, y: 80), endRadius: 640,
    options: [])
ctx.restoreGState()

// Het raster: 2 × 2 afgeronde vakken met een smalle voeg.
let grid = CGRect(x: 232, y: 262, width: 560, height: 500)
let gap: CGFloat = 36
let tile = CGSize(width: (grid.width - gap) / 2, height: (grid.height - gap) / 2)
let tileRadius: CGFloat = 52

func tileRect(column: Int, row: Int) -> CGRect {
    CGRect(x: grid.minX + CGFloat(column) * (tile.width + gap), y: grid.minY + CGFloat(row) * (tile.height + gap),
           width: tile.width, height: tile.height)
}

// De drie lege vakken: doorzichtig wit met een lichte rand.
for (column, row) in [(1, 0), (0, 1), (1, 1)] {
    let path = roundedRect(tileRect(column: column, row: row), radius: tileRadius)
    ctx.addPath(path)
    ctx.setFillColor(color(0xFFFFFF, 0.2))
    ctx.fillPath()
    ctx.addPath(path)
    ctx.setStrokeColor(color(0xFFFFFF, 0.35))
    ctx.setLineWidth(6)
    ctx.strokePath()
}

// Het gevulde vak linksboven: helder wit met een zachte schaduw.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 12), blur: 30, color: color(0x032A2E, 0.45))
ctx.addPath(roundedRect(tileRect(column: 0, row: 0), radius: tileRadius))
ctx.setFillColor(color(0xFFFFFF))
ctx.fillPath()
ctx.restoreGState()

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print(output)
