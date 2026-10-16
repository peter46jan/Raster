import AppKit
import SwiftUI

/// Hulpjes om interface offscreen naar PNG te tekenen (sRGB, standaard @2x) in `directory`.
@MainActor
enum Render {
    /// Map voor de PNG's (het argument van `raster-render`).
    static var directory = ""

    /// Een SwiftUI-view op een vaste maat, licht of donker; bestand `<name>.png` of `<name>-dark.png`.
    static func view<V: View>(_ view: V, size: CGSize, name: String, dark: Bool = false, scale: CGFloat = 2) throws {
        let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        host.frame = CGRect(origin: .zero, size: size)
        try self.view(host, name: name, dark: dark, scale: scale)
    }

    /// Een AppKit-view op zijn huidige maat, licht of donker.
    static func view(_ view: NSView, name: String, dark: Bool = false, scale: CGFloat = 2) throws {
        view.appearance = appearance(dark: dark)
        try write(view, name: fileName(name, dark: dark), scale: scale)
    }

    /// Een afbeelding zoals hij is (zonder inkleuren, transparante achtergrond) op `scale`; voor iconen die op hun
    /// alfaraster vergeleken worden. `name` mag een submap bevatten.
    static func image(_ image: NSImage, name: String, scale: CGFloat = 2) throws {
        let size = image.size
        guard let blank = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int((size.width * scale).rounded()),
                                           pixelsHigh: Int((size.height * scale).rounded()),
                                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                           colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let rep = blank.retagging(with: .sRGB) else { throw RenderError.encoding }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: CGRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        guard let png = rep.representation(using: .png, properties: [:]) else { throw RenderError.encoding }
        let file = URL(fileURLWithPath: directory).appending(path: name + ".png")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try png.write(to: file)
    }

    /// Een heel venster inclusief titelbalk (het kader om de contentView), licht of donker. Offscreen is een
    /// venster nooit key; gebruik `Render.Window` om het actief te tekenen.
    static func window(_ window: NSWindow, name: String, dark: Bool = false, scale: CGFloat = 2) throws {
        window.appearance = appearance(dark: dark)
        guard let frame = window.contentView?.superview else { throw RenderError.noFrameView }
        try write(frame, name: fileName(name, dark: dark), scale: scale)
    }

    /// Venster dat er offscreen uitziet als het actieve venster zolang `isActive` waar is: verkeerslichten in kleur,
    /// SwiftUI's `controlActiveState` `.key` en bedieningselementen in de accentkleur. Offscreen is een venster nooit
    /// key; AppKit vraagt voor de weergave `hasKeyAppearance` (privé selector, alleen in `raster-render` gebruikt).
    final class Window: NSWindow {
        var isActive = true
        @objc func hasKeyAppearance() -> Bool { isActive }
    }

    enum RenderError: Error { case noFrameView, encoding }

    private static func appearance(dark: Bool) -> NSAppearance? { NSAppearance(named: dark ? .darkAqua : .aqua) }

    private static func fileName(_ name: String, dark: Bool) -> String { dark ? name + "-dark" : name }

    /// Tekent de view in een sRGB-bitmap op `scale` en schrijft die als PNG. sRGB en niet deviceRGB, zodat de
    /// pixelwaarden gelijk zijn aan de kleurwaarden in de code (geen omzetting naar het profiel van het scherm).
    private static func write(_ view: NSView, name: String, scale: CGFloat) throws {
        view.layoutSubtreeIfNeeded()
        let bounds = view.bounds
        guard let blank = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int((bounds.width * scale).rounded()),
                                           pixelsHigh: Int((bounds.height * scale).rounded()),
                                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                           colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let rep = blank.retagging(with: .sRGB) else { throw RenderError.encoding }
        rep.size = bounds.size
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            view.cacheDisplay(in: bounds, to: rep)
        }
        guard let png = rep.representation(using: .png, properties: [:]) else { throw RenderError.encoding }
        let folder = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try png.write(to: folder.appending(path: name + ".png"))
    }
}
