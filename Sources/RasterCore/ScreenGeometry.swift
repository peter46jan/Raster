import CoreGraphics

/// Een scherm in AX-coördinaten (oorsprong linksboven van het hoofdscherm, y omlaag).
public struct ScreenInfo: Equatable, Sendable {
    public var frame: CGRect
    public var visibleFrame: CGRect

    public init(frame: CGRect, visibleFrame: CGRect) {
        self.frame = frame
        self.visibleFrame = visibleFrame
    }
}

public enum ScreenGeometry {
    /// Strook linksboven in een venster waar de knoppen van de titelbalk staan (ruim genomen).
    public static let titleBarButtonStrip = CGSize(width: 90, height: 40)

    /// Ligt `point` in de knoppenstrook van een venster met dit frame? Beide in AX-coördinaten.
    public static func isInTitleBarButtons(_ point: CGPoint, windowFrame: CGRect) -> Bool {
        let strip = CGRect(origin: windowFrame.origin, size: titleBarButtonStrip).intersection(windowFrame)
        return !strip.isNull && point.x >= strip.minX && point.x <= strip.maxX && point.y >= strip.minY && point.y <= strip.maxY
    }

    /// Zet een rechthoek om tussen Cocoa (oorsprong linksonder) en AX (oorsprong linksboven).
    /// De omzetting is haar eigen omgekeerde.
    public static func flip(_ rect: CGRect, mainScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: mainScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Het scherm met de grootste overlap; zonder overlap het scherm met het dichtstbijzijnde midden.
    public static func screenIndex(for window: CGRect, in screens: [ScreenInfo]) -> Int? {
        guard !screens.isEmpty else { return nil }
        let overlaps = screens.map { screen -> CGFloat in
            let overlap = screen.frame.intersection(window)
            return overlap.isNull ? 0 : overlap.width * overlap.height
        }
        if let best = overlaps.indices.max(by: { overlaps[$0] < overlaps[$1] }), overlaps[best] > 0 {
            return best
        }
        func distance(_ screen: ScreenInfo) -> CGFloat {
            let dx = screen.frame.midX - window.midX, dy = screen.frame.midY - window.midY
            return dx * dx + dy * dy
        }
        return screens.indices.min(by: { distance(screens[$0]) < distance(screens[$1]) })
    }

    /// Volgend (`step` 1) of vorig (`step` -1) scherm, van links naar rechts en bij gelijke x
    /// van boven naar onder, met omloop.
    public static func neighbor(of index: Int, in screens: [ScreenInfo], step: Int) -> Int {
        let order = screens.indices.sorted { lhs, rhs in
            let l = screens[lhs].frame, r = screens[rhs].frame
            return l.minX != r.minX ? l.minX < r.minX : l.minY < r.minY
        }
        guard let position = order.firstIndex(of: index) else { return index }
        let count = order.count
        return order[((position + step) % count + count) % count]
    }

    /// Verplaatst een venster naar een ander scherm met dezelfde relatieve positie en grootte.
    public static func translate(_ frame: CGRect, from source: CGRect, to target: CGRect) -> CGRect {
        guard source.width > 0, source.height > 0 else { return clamp(frame, into: target) }
        let moved = CGRect(
            x: (target.minX + (frame.minX - source.minX) / source.width * target.width).rounded(),
            y: (target.minY + (frame.minY - source.minY) / source.height * target.height).rounded(),
            width: (frame.width / source.width * target.width).rounded(),
            height: (frame.height / source.height * target.height).rounded()
        )
        return clamp(moved, into: target)
    }

    /// Houdt de grootte (begrensd op `bounds`) en zet het venster in het midden.
    public static func centered(_ size: CGSize, in bounds: CGRect) -> CGRect {
        let width = min(size.width, bounds.width), height = min(size.height, bounds.height)
        return CGRect(
            x: (bounds.minX + (bounds.width - width) / 2).rounded(),
            y: (bounds.minY + (bounds.height - height) / 2).rounded(),
            width: width,
            height: height
        )
    }

    public static func clamp(_ rect: CGRect, into bounds: CGRect) -> CGRect {
        let width = min(rect.width, bounds.width), height = min(rect.height, bounds.height)
        return CGRect(
            x: min(max(rect.minX, bounds.minX), bounds.maxX - width),
            y: min(max(rect.minY, bounds.minY), bounds.maxY - height),
            width: width,
            height: height
        )
    }
}
