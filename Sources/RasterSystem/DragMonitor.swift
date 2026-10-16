import AppKit
import RasterCore

/// Volgt het slepen van vensters met een event tap die alleen meeluistert en nooit iets tegenhoudt.
/// Muis omlaag op een venster start een sessie; zodra het venster verschuift zonder van grootte te
/// veranderen is het "verplaatsen" (anders vergroten: sessie stopt). Tijdens verplaatsen meldt de
/// monitor het voorbeeld voor de zone onder de cursor; bij loslaten in een zone voert hij het commando uit.
@MainActor
public final class DragMonitor {
    /// Rechthoek van het voorbeeldpaneel (AX-coördinaten), of nil als er geen zone is.
    public var onPreviewChange: ((CGRect?) -> Void)?
    public var lists: () -> CommandLists = { .empty }
    /// "Restore windows to original size" bij het wegslepen van een geplaatst venster.
    public var restoresOriginalSize = true
    public var edgeWidth: CGFloat = DragZoneResolver.edgeWidth
    public var innerScale: CGFloat = 1
    /// Sleepzones van het scherm onder de cursor melden tijdens het verplaatsen ("Highlight activation areas").
    public var showsZones = false
    /// Rechthoeken (AX) van de sleepzones om te tonen; leeg = verbergen.
    public var onZonesChange: (([CGRect]) -> Void)?

    private let windows: WindowController
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var session: Session?

    private struct Session {
        let window: AXWindow
        let startFrame: CGRect
        var isMoving = false
        var restoreFrame: CGRect?
        /// Grootte die het venster tijdens het verplaatsen moet houden; een andere grootte betekent vergroten.
        var expectedSize: CGSize = .zero
        var match: DragMatch?
        /// Index van het scherm waarvan de zones nu getoond worden.
        var zoneScreen: Int?
        var lastCheck: ContinuousClock.Instant?
    }

    public init(windows: WindowController) {
        self.windows = windows
    }

    isolated deinit {
        stop()
    }

    public var isRunning: Bool { tap != nil }

    /// Start de event tap. Geeft false als macOS hem weigert (bijv. geen toestemming).
    @discardableResult
    public func start() -> Bool {
        if tap != nil { return true }
        let types: [CGEventType] = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: mask, callback: dragTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        return true
    }

    public func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        endSession()
    }

    fileprivate func receive(_ type: CGEventType, at location: CGPoint) {
        // Een gebeurtenis die nog in de wachtrij stond terwijl de tap werd gestopt, telt niet meer.
        guard let tap else { return }
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            CGEvent.tapEnable(tap: tap, enable: true)
        case .leftMouseDown:
            mouseDown(at: location)
        case .leftMouseDragged:
            mouseDragged(to: location)
        case .leftMouseUp:
            mouseUp(at: location)
        default:
            break
        }
    }

    private func mouseDown(at location: CGPoint) {
        endSession()
        // Klikken in de eigen vensters van Raster (paneel, instellingen, meldingen): geen AX-vraag aan onszelf.
        guard !WindowController.isOwnWindow(at: location),
              let window = windows.windowCandidate(at: location), let frame = window.frame else { return }
        session = Session(window: window, startFrame: frame)
    }

    private func mouseDragged(to location: CGPoint) {
        guard var current = session else { return }
        let now = ContinuousClock.now
        if let last = current.lastCheck, now - last < .milliseconds(50) { return }
        current.lastCheck = now
        guard let frame = current.window.frame else {
            endSession()
            return
        }
        if !current.isMoving {
            guard Self.hasSize(frame, current.startFrame.size) else {
                endSession() // vergroten, geen verplaatsen
                return
            }
            guard frame.origin != current.startFrame.origin else {
                session = current
                return
            }
            guard windows.isMovable(current.window) else {
                endSession()
                return
            }
            current.isMoving = true
            current.restoreFrame = restoresOriginalSize
                ? windows.unsnap(current.window, startFrame: current.startFrame, cursor: location)
                : nil
            current.expectedSize = current.restoreFrame == nil
                ? current.startFrame.size
                : current.window.frame?.size ?? current.restoreFrame?.size ?? current.startFrame.size
        } else if !Self.hasSize(frame, current.expectedSize) {
            endSession() // alsnog vergroten
            return
        }
        let screens = Screens.current()
        let lists = lists()
        let match = DragZoneResolver.match(
            cursor: location, screens: screens, lists: lists, edgeWidth: edgeWidth, innerScale: innerScale)
        if match != current.match {
            current.match = match
            onPreviewChange?(match.flatMap { preview(for: $0, window: current.window) })
        }
        if showsZones {
            let screen = screens.firstIndex { $0.frame.contains(location) }
            if screen != current.zoneScreen {
                current.zoneScreen = screen
                onZonesChange?(screen.map {
                    DragZoneResolver.zoneRects(on: screens[$0], lists: lists, edgeWidth: edgeWidth, innerScale: innerScale)
                } ?? [])
            }
        }
        session = current
    }

    private func mouseUp(at location: CGPoint) {
        guard var current = session else { return }
        endSession()
        // Het laatste verschuiven kan zijn gemist door de pauze tussen controles: nog één keer kijken.
        if !current.isMoving, let frame = current.window.frame,
           Self.hasSize(frame, current.startFrame.size),
           frame.origin != current.startFrame.origin, windows.isMovable(current.window) {
            current.isMoving = true
        }
        guard current.isMoving,
              let match = DragZoneResolver.match(
                  cursor: location, screens: Screens.current(), lists: lists(), edgeWidth: edgeWidth, innerScale: innerScale),
              let command = lists().command(match.commandID) else { return }
        windows.perform(
            command, on: current.window, screenIndex: match.screenIndex,
            previousFrame: current.restoreFrame ?? current.startFrame
        )
    }

    private func preview(for match: DragMatch, window: AXWindow) -> CGRect? {
        guard let command = lists().command(match.commandID) else { return nil }
        return windows.previewFrame(for: command, window: window, screenIndex: match.screenIndex)
    }

    private static func hasSize(_ frame: CGRect, _ size: CGSize) -> Bool {
        abs(frame.width - size.width) < 0.5 && abs(frame.height - size.height) < 0.5
    }

    private func endSession() {
        if session?.match != nil { onPreviewChange?(nil) }
        if session?.zoneScreen != nil { onZonesChange?([]) }
        session = nil
    }
}

/// macOS roept dit aan op de hoofdthread (de bron hangt aan de main run loop). Meteen teruggeven;
/// het werk met AX gebeurt in de volgende ronde van de hoofdthread, zodat de tap nooit wacht.
private func dragTapCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if let userInfo {
        let monitor = Unmanaged<DragMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        let location = event.location
        DispatchQueue.main.async { [weak monitor] in
            MainActor.assumeIsolated { monitor?.receive(type, at: location) }
        }
    }
    return Unmanaged.passUnretained(event)
}
