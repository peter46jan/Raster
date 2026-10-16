import ApplicationServices

/// Eén venster van een andere app.
public struct AXWindow {
    public let element: AXUIElement
    public let pid: pid_t

    public init(element: AXUIElement, pid: pid_t) {
        self.element = element
        self.pid = pid
    }

    /// Frame in AX-coördinaten.
    public var frame: CGRect? {
        guard let origin = AX.point(element, AX.position), let size = AX.size(element, AX.size) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    public var isFullScreen: Bool { AX.bool(element, AX.fullScreen) == true }
    public var canMove: Bool { AX.isSettable(element, AX.position) }
    public var canResize: Bool { AX.isSettable(element, AX.size) }

    /// Waar als AX meldt dat het element niet meer bestaat; een time-out of andere fout telt niet.
    public var isGone: Bool { AX.error(element, AX.role) == .invalidUIElement }

    public var isMinimized: Bool { AX.bool(element, AX.minimized) == true }

    /// Venster vooraan in zijn app zetten, zonder de app te activeren.
    public func raise() {
        AXUIElementPerformAction(element, AX.raise as CFString)
    }

    /// Zet grootte, positie en nog eens grootte: zo lukt het ook als het venster tegen de
    /// schermrand botst of een minimale grootte heeft. Chrome en Electron-apps animeren traag
    /// zolang `AXEnhancedUserInterface` aan staat; die gaat tijdelijk uit.
    /// `canResize` mag worden meegegeven als de aanroeper het al weet (scheelt een AX-ronde).
    public func setFrame(_ frame: CGRect, canResize: Bool? = nil) {
        let app = AXUIElementCreateApplication(pid)
        let enhanced = AX.bool(app, AX.enhancedUserInterface) == true
        if enhanced { AX.set(app, AX.enhancedUserInterface, bool: false) }
        defer { if enhanced { AX.set(app, AX.enhancedUserInterface, bool: true) } }
        let resizable = canResize ?? self.canResize
        if resizable { AX.set(element, AX.size, size: frame.size) }
        AX.set(element, AX.position, point: frame.origin)
        if resizable { AX.set(element, AX.size, size: frame.size) }
    }
}

/// Sleutel voor het herstel-geheugen: twee elementen zijn hetzelfde venster als `CFEqual` dat zegt.
struct WindowKey: Equatable {
    let element: AXUIElement

    static func == (lhs: WindowKey, rhs: WindowKey) -> Bool {
        CFEqual(lhs.element, rhs.element)
    }
}
