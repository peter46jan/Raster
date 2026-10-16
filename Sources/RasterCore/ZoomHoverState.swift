/// Of het menu bij de groene knop na een rustmoment van de muis moet verschijnen: één keer per knop, tot de muis
/// elders tot rust komt. Rusten op een eigen venster van Raster telt als elders, behalve zolang het eigen
/// menu open is (dan is de muis op weg van de knop naar dat menu en terug).
public struct ZoomHoverState<Button> {
    public enum Rest {
        /// Op een venster van Raster zelf; `menuOpen` als het menu bij de groene knop nog open is.
        case ownWindow(menuOpen: Bool)
        /// Toets voor het menu van macOS ingedrukt.
        case suppressed
        /// Geen groene knop onder de muis.
        case elsewhere
        case button(Button)
    }

    private var last: Button?
    private let isSame: (Button, Button) -> Bool

    public init(isSame: @escaping (Button, Button) -> Bool) {
        self.isSame = isSame
    }

    /// Waar als het menu nu moet verschijnen.
    public mutating func rest(_ rest: Rest) -> Bool {
        switch rest {
        case .ownWindow(let menuOpen):
            if !menuOpen { last = nil }
            return false
        case .suppressed, .elsewhere:
            last = nil
            return false
        case .button(let button):
            if let last, isSame(last, button) { return false }
            last = button
            return true
        }
    }

    public mutating func reset() {
        last = nil
    }
}
