import CoreGraphics

/// Ruimte rond vensters ("Add margins around windows" en "Fit tightly to screen edges").
/// Kanten op de rand van het scherm krijgen de hele marge (of geen bij `fitTightly`), kanten binnenin
/// de helft (in hele punten), zodat twee buren samen precies één marge tussen zich hebben.
public struct WindowMargins: Equatable, Sendable {
    public static let none = WindowMargins(size: 0, fitTightly: false)

    public var size: CGFloat
    public var fitTightly: Bool

    public init(size: CGFloat, fitTightly: Bool) {
        self.size = size
        self.fitTightly = fitTightly
    }

    /// `rect` en `visible` in hetzelfde coördinatenstelsel. Blijft er niets over, dan `rect` ongewijzigd.
    public func apply(to rect: CGRect, in visible: CGRect) -> CGRect {
        guard size > 0 else { return rect }
        let outer = fitTightly ? 0 : size
        // Binnenin hele punten: links/boven naar beneden, rechts/onder naar boven afgerond, zodat twee buren
        // ook bij een oneven marge precies één marge tussen zich hebben.
        func inset(_ onEdge: Bool, _ inner: CGFloat) -> CGFloat { onEdge ? outer : inner }
        let leading = (size / 2).rounded(.down), trailing = (size / 2).rounded(.up)
        let left = inset(abs(rect.minX - visible.minX) < 1, leading)
        let right = inset(abs(rect.maxX - visible.maxX) < 1, trailing)
        let top = inset(abs(rect.minY - visible.minY) < 1, leading)
        let bottom = inset(abs(rect.maxY - visible.maxY) < 1, trailing)
        // Eerst de maten uitrekenen: een CGRect met negatieve breedte wordt genormaliseerd.
        let width = rect.width - left - right, height = rect.height - top - bottom
        guard width > 0, height > 0 else { return rect }
        return CGRect(x: rect.minX + left, y: rect.minY + top, width: width, height: height)
    }
}
