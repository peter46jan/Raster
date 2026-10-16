import AppKit
import RasterCore

/// Doorzichtige afgeronde rechthoek die laat zien waar het gesleepte venster terechtkomt.
@MainActor
final class SnapPreview {
    struct Style: Equatable {
        var appearance: PreviewAppearance = .automatic
        var color: RasterCore.RGBColor = .blue
        var outline: CGFloat = 1
    }

    var style = Style()

    private let panel: NSPanel
    private var isShowing = false

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        // Raster verbergt zichzelf na het sluiten van een venster (focus teruggeven); het voorbeeld moet dan zichtbaar blijven.
        panel.canHide = false
        let view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 10
        panel.contentView = view
    }

    /// Vulling en rand bij het uiterlijk; "omgekeerd" is licht in donkere modus en andersom.
    private func colors(for appearance: PreviewAppearance) -> (fill: NSColor, border: NSColor) {
        switch appearance {
        case .automatic:
            return (NSColor.controlAccentColor.withAlphaComponent(0.25), .controlAccentColor)
        case .light:
            return (NSColor.white.withAlphaComponent(0.45), NSColor(white: 0.6, alpha: 1))
        case .dark:
            return (NSColor.black.withAlphaComponent(0.4), NSColor(white: 0.25, alpha: 1))
        case .inverse:
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return colors(for: isDark ? .light : .dark)
        case .custom:
            let color = NSColor(srgbRed: style.color.red, green: style.color.green, blue: style.color.blue, alpha: 1)
            return (color.withAlphaComponent(0.25), color)
        }
    }

    private func applyStyle() {
        guard let layer = panel.contentView?.layer else { return }
        let colors = colors(for: style.appearance)
        layer.backgroundColor = colors.fill.cgColor
        layer.borderColor = colors.border.cgColor
        layer.borderWidth = style.outline
    }

    /// `axFrame` in AX-coördinaten.
    func show(_ axFrame: CGRect) {
        guard let mainHeight = NSScreen.screens.first?.frame.height else { return }
        let frame = ScreenGeometry.flip(axFrame, mainScreenHeight: mainHeight)
        applyStyle()
        if isShowing {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().setFrame(frame, display: true)
                panel.animator().alphaValue = 1
            }
            return
        }
        isShowing = true
        panel.setFrame(frame, display: true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard isShowing else { return }
        isShowing = false
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.isShowing else { return }
                self.panel.orderOut(nil)
            }
        })
    }
}
