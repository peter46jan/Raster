import AppKit
import RasterCore

/// Voert commando's uit op vensters van andere apps.
@MainActor
public final class WindowController {
    /// Bundle-ID's van apps waarvan Raster de vensters met rust laat (fase 4 vult dit in).
    public var excludedBundleIDs: Set<String> = []
    public let pins = PinManager()
    /// Marges rond vensters bij commando's met een gebied.
    public var margins = WindowMargins.none
    private var memory = RestoreMemory<WindowKey>(limit: 50)
    /// Laatste andere app dan Raster zelf die voorop stond; terugval als Raster zelf voorop staat.
    private var lastExternalApp: NSRunningApplication?

    public init() {
        // Standaard wacht AX tot 6 seconden op een app die niet reageert; dat bevriest de hoofdthread.
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 1.0)
        let ownPID = ProcessInfo.processInfo.processIdentifier
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != ownPID {
            lastExternalApp = front
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ownPID else { return }
            MainActor.assumeIsolated { self?.lastExternalApp = app }
        }
    }

    /// Voert een commando uit op `window`. De aanroeper bepaalt zelf of het venster mag (uitgesloten apps,
    /// volledig scherm). `screenIndex` nil = het scherm waar het venster nu staat.
    /// `previousFrame` is wat "herstellen" later terugzet; standaard de huidige frame.
    public func perform(_ command: Command, on window: AXWindow, screenIndex: Int? = nil, previousFrame: CGRect? = nil) {
        if command.action == .special(.stayOnTop) {
            pins.toggle(window)
            return
        }
        guard window.canMove, let frame = window.frame else { return }
        let key = WindowKey(element: window.element)
        if command.action == .special(.restore) {
            if let saved = memory.take(key) { window.setFrame(saved) }
            return
        }
        let screens = Screens.current()
        guard let index = screenIndex ?? ScreenGeometry.screenIndex(for: frame, in: screens) else { return }
        let canResize = window.canResize
        guard let target = CommandPlanner.target(
            for: command.action, grid: command.axis.grid, frame: frame, screens: screens, screenIndex: index, canResize: canResize, margins: margins
        ) else { return }
        window.setFrame(target, canResize: canResize)
        memory.record(before: previousFrame ?? frame, after: window.frame ?? target, for: key)
    }

    /// Waar `window` terecht zou komen, voor het voorbeeldpaneel tijdens slepen.
    public func previewFrame(for command: Command, window: AXWindow, screenIndex: Int) -> CGRect? {
        guard let frame = window.frame else { return nil }
        return CommandPlanner.target(
            for: command.action, grid: command.axis.grid, frame: frame, screens: Screens.current(), screenIndex: screenIndex, canResize: window.canResize,
            margins: margins
        )
    }

    /// Of "Restore" voor `window` iets terugzet (anders staat het menu-item grijs). Het menu vraagt het actieve
    /// venster één keer op met `focusedWindowAndGrid()` en geeft het hier mee.
    public func canRestore(_ window: AXWindow) -> Bool {
        memory.contains(WindowKey(element: window.element))
    }

    /// Lostrekken ("restoreToOriginalSize"): stond het venster bij het begin van het slepen nog
    /// waar Raster het neerzette, dan krijgt het zijn grootte van daarvoor terug, met de cursor op
    /// dezelfde relatieve plek in de titelbalk. Geeft die eerdere frame terug (nil als er niets te herstellen was),
    /// zodat "herstellen" later weer naar de situatie van vóór de reeks plaatsingen gaat.
    @discardableResult
    public func unsnap(_ window: AXWindow, startFrame: CGRect, cursor: CGPoint) -> CGRect? {
        let key = WindowKey(element: window.element)
        guard let saved = memory.snappedFrame(for: key, current: startFrame), let frame = window.frame else { return nil }
        _ = memory.take(key)
        let grab = frame.width > 0 ? (cursor.x - frame.minX) / frame.width : 0.5
        window.setFrame(CGRect(x: (cursor.x - grab * saved.width).rounded(), y: frame.minY, width: saved.width, height: saved.height))
        return saved
    }

    /// Het venster onder `point` (AX-coördinaten) van een andere, niet uitgesloten app, of nil.
    /// Doet bewust alleen de goedkope controles; `isMovable(_:)` volgt zodra een verplaatsing echt begint.
    public func windowCandidate(at point: CGPoint) -> AXWindow? {
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &hit) == .success,
              let hit, let element = Self.containingWindow(of: hit) else { return nil }
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success, pid != ProcessInfo.processInfo.processIdentifier else { return nil }
        if let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier, excludedBundleIDs.contains(bundleID) {
            return nil
        }
        guard AX.string(element, AX.subrole) != "AXFloatingWindow" else { return nil }
        return AXWindow(element: element, pid: pid)
    }

    /// Mag Raster dit venster verplaatsen: niet op volledig scherm en wel te verplaatsen.
    public func isMovable(_ window: AXWindow) -> Bool {
        !window.isFullScreen && window.canMove
    }

    private static func containingWindow(of element: AXUIElement) -> AXUIElement? {
        if AX.string(element, AX.role) == "AXWindow" { return element }
        if let window = AX.element(element, AX.window) { return window }
        var current = element
        for _ in 0..<32 {
            guard let parent = AX.element(current, AX.parent) else { return nil }
            if AX.string(parent, AX.role) == "AXWindow" { return parent }
            current = parent
        }
        return nil
    }

    /// Het actieve venster met het raster van zijn scherm (liggend als dat niet te bepalen is), of nil zonder
    /// actief venster dat Raster mag bedienen. Eén AX-ronde: de aanroeper kiest de lijst met het raster en voert
    /// het commando daarna met `perform(_:on:)` uit op ditzelfde venster, ook als de focus intussen wisselt.
    public func focusedWindowAndGrid() -> (window: AXWindow, grid: GridSize)? {
        guard let window = focusedWindow() else { return nil }
        return (window, grid(for: window) ?? .landscape)
    }

    /// Raster van het scherm waarop `window` staat.
    public func grid(for window: AXWindow) -> GridSize? {
        guard let frame = window.frame else { return nil }
        let screens = Screens.current()
        guard let index = ScreenGeometry.screenIndex(for: frame, in: screens) else { return nil }
        return GridSize.for(screens[index].visibleFrame.size)
    }

    /// Venster en knop als onder `point` (AX-coördinaten) de groene knop van een venster ligt dat Raster mag
    /// bedienen; anders nil.
    public func zoomButtonWindow(at point: CGPoint) -> (window: AXWindow, button: AXUIElement)? {
        // Goedkope voorselectie zonder AX: alleen in de knoppenstrook van het bovenste venster van een andere app.
        // Zo bevraagt rusten elders (of boven een app die niet reageert) niemand via AX.
        guard let frame = Self.topWindowFrame(at: point),
              ScreenGeometry.isInTitleBarButtons(point, windowFrame: frame) else { return nil }
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &hit) == .success,
              let hit, AX.string(hit, AX.subrole) == "AXZoomButton",
              let element = Self.containingWindow(of: hit),
              AX.string(element, AX.subrole) != "AXFloatingWindow" else { return nil }
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success, pid != ProcessInfo.processInfo.processIdentifier else { return nil }
        if let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier, excludedBundleIDs.contains(bundleID) {
            return nil
        }
        let window = AXWindow(element: element, pid: pid)
        return window.isFullScreen ? nil : (window, hit)
    }

    /// Zonder AX: ligt het bovenste venster op dit punt (AX-coördinaten) van Raster zelf? Dan geen AX-hit-test,
    /// want die zou Raster zelf bevragen en tot de time-out kunnen hangen.
    public static func isOwnWindow(at axPoint: CGPoint) -> Bool {
        guard let mainHeight = NSScreen.screens.first?.frame.height else { return false }
        let number = NSWindow.windowNumber(at: NSPoint(x: axPoint.x, y: mainHeight - axPoint.y), belowWindowWithWindowNumber: 0)
        return NSApp.windows.contains { $0.isVisible && $0.windowNumber == number }
    }

    /// Frame (AX-coördinaten) van het bovenste gewone, zichtbare venster op dit punt, als dat van een andere app is
    /// (zie `WindowStack`). `kCGWindowBounds` gebruikt dezelfde coördinaten als AX.
    static func topWindowFrame(at point: CGPoint) -> CGRect? {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return nil }
        let windows = list.compactMap { info -> WindowListEntry? in
            guard let boundsInfo = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsInfo),
                  let layer = info[kCGWindowLayer as String] as? Int,
                  let pid = info[kCGWindowOwnerPID as String] as? Int else { return nil }
            // Zonder bounds, laag of eigenaar (komt in de praktijk niet voor) slaan we het venster over.
            // Zonder alpha-waarde geldt het venster als zichtbaar.
            let alpha = info[kCGWindowAlpha as String] as? Double ?? 1
            return WindowListEntry(bounds: bounds, layer: layer, alpha: alpha, pid: Int32(pid))
        }
        return WindowStack.topWindowFrame(at: point, in: windows, ownPID: ProcessInfo.processInfo.processIdentifier)
    }

    /// De app waar commando's uit het menu op werken: de voorste app, of de laatste andere als Raster zelf voorop staat.
    public var targetApplication: NSRunningApplication? {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let front = NSWorkspace.shared.frontmostApplication
        let app = front?.processIdentifier == ownPID ? lastExternalApp : front
        return app?.isTerminated == false ? app : nil
    }

    func focusedWindow() -> AXWindow? {
        guard let app = targetApplication else { return nil }
        if let bundleID = app.bundleIdentifier, excludedBundleIDs.contains(bundleID) { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, 1)
        guard let element = AX.element(appElement, AX.focusedWindow) ?? AX.element(appElement, AX.mainWindow),
              AX.bool(element, AX.minimized) != true,
              AX.string(element, AX.subrole) != "AXFloatingWindow" else { return nil }
        let window = AXWindow(element: element, pid: app.processIdentifier)
        return window.isFullScreen ? nil : window
    }
}
