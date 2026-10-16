import AppKit
import RasterCore

/// Toont tijdens het slepen de sleepzones van het scherm onder de cursor ("Highlight activation areas").
@MainActor
final class ActivationOverlay {
    struct Style: Equatable {
        var appearance: ZoneAppearance = .automatic
        var color: RasterCore.RGBColor = .blue
        var outline: CGFloat = 1
    }

    var style = Style()

    private let panel: NSPanel
    private let zonesView = ZonesView()

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        // Net onder het voorbeeld (`SnapPreview` op `.statusBar`), zodat dat erboven ligt.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.canHide = false
        panel.contentView = zonesView
    }

    /// `axRects` in AX-coördinaten; leeg = verbergen.
    func show(_ axRects: [CGRect]) {
        guard !axRects.isEmpty, let mainHeight = NSScreen.screens.first?.frame.height else {
            panel.orderOut(nil)
            return
        }
        let rects = axRects.map { ScreenGeometry.flip($0, mainScreenHeight: mainHeight) }
        let frame = rects.dropFirst().reduce(rects[0]) { $0.union($1) }
        panel.setFrame(frame, display: false)
        zonesView.rects = rects.map { $0.offsetBy(dx: -frame.minX, dy: -frame.minY) }
        zonesView.color = style.appearance == .custom
            ? NSColor(srgbRed: style.color.red, green: style.color.green, blue: style.color.blue, alpha: 1)
            : .controlAccentColor
        zonesView.outline = style.outline
        zonesView.needsDisplay = true
        panel.orderFrontRegardless()
    }

    /// Tekent de zones: vulling 15 %, rand 60 %.
    private final class ZonesView: NSView {
        var rects: [CGRect] = []
        var color: NSColor = .controlAccentColor
        var outline: CGFloat = 1

        override func draw(_ dirtyRect: NSRect) {
            for rect in rects {
                color.withAlphaComponent(0.15).setFill()
                // Bedekken (niet vervangen), zodat overlappende zones elkaars rand niet wissen.
                rect.fill(using: .sourceOver)
                guard outline > 0 else { continue }
                let path = NSBezierPath(rect: rect.insetBy(dx: outline / 2, dy: outline / 2))
                path.lineWidth = outline
                color.withAlphaComponent(0.6).setStroke()
                path.stroke()
            }
        }
    }
}
