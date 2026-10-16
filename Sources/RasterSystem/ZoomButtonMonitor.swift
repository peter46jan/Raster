import AppKit
import RasterCore

/// Merkt dat de muis `hoverDelay` stil op een groene knop rust en meldt dat zonder toets: het menu van Raster
/// verschijnt dan vóór dat van macOS. Is `systemMenuModifier` ingedrukt, dan meldt de monitor niets, zodat het
/// menu van macOS verschijnt. Event tap die alleen luistert, op muisbewegingen (en toetswijzigingen, als macOS
/// dat toestaat, zodat een toets die tijdens het rusten wordt ingedrukt meteen telt). De AX-hit-test gebeurt pas
/// na stilstand, dus gewoon bewegen kost niets. Per knop één keer melden tot de muis elders tot rust komt.
@MainActor
public final class ZoomButtonMonitor {
    public var onHover: ((AXWindow, CGPoint) -> Void)?
    /// Met deze toets ingedrukt toont Raster niets, zodat het menu van macOS verschijnt ("Select modifier
    /// key to show system menu").
    public var systemMenuModifier: NSEvent.ModifierFlags = .control
    /// Hoe lang de muis stil moet staan; kort, zodat het menu van Raster vóór dat van macOS komt.
    public var hoverDelay: TimeInterval = 0.3
    /// Of het eigen menu van Raster bij de groene knop nog open is (het horizontale paneel); zolang dat zo is, telt rusten
    /// op een eigen venster niet als "elders".
    public var isMenuOpen: () -> Bool = { false }

    private let windows: WindowController
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var timer: Timer?
    private var restLocation = CGPoint.zero
    private var hover = ZoomHoverState<AXUIElement>(isSame: { CFEqual($0, $1) })

    public init(windows: WindowController) {
        self.windows = windows
    }

    isolated deinit {
        stop()
    }

    public var isRunning: Bool { tap != nil }

    @discardableResult
    public func start() -> Bool {
        if tap != nil { return true }
        // Eerst met toetswijzigingen; weigert macOS dat (toetsenbord-event), dan alleen muisbewegingen.
        // Een toets indrukken (flagsChanged) hoort bij het toetsenbord en vraagt dus toestemming voor "Input Monitoring".
        let attempts: [[CGEventType]] = CGPreflightListenEventAccess() ? [[.mouseMoved, .flagsChanged], [.mouseMoved]] : [[.mouseMoved]]
        for types in attempts {
            let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
            if let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
                eventsOfInterest: mask, callback: zoomTapCallback,
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            ) {
                let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
                CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
                CGEvent.tapEnable(tap: tap, enable: true)
                self.tap = tap
                self.source = source
                return true
            }
        }
        return false
    }

    public func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        timer?.invalidate()
        timer = nil
        hover.reset()
    }

    fileprivate func receive(_ type: CGEventType, at location: CGPoint) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .mouseMoved, .flagsChanged:
            guard tap != nil else { return }
            restLocation = location
            scheduleRest()
        default:
            break
        }
    }

    /// Eén timer in de standaardmodus (dus nooit tijdens het volgen van een menu); elke beweging schuift hem `hoverDelay` op.
    private func scheduleRest() {
        let fireDate = Date(timeIntervalSinceNow: hoverDelay)
        if let timer, timer.isValid {
            timer.fireDate = fireDate
            return
        }
        let timer = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.rest() }
        }
        RunLoop.main.add(timer, forMode: .default)
        self.timer = timer
    }

    private func rest() {
        timer = nil
        let location = restLocation
        // Op een eigen venster (zoals het horizontale paneel) geen AX-hit-test: die zou Raster zelf bevragen en
        // kan dan tot de time-out blijven hangen.
        if WindowController.isOwnWindow(at: location) {
            _ = hover.rest(.ownWindow(menuOpen: isMenuOpen()))
            return
        }
        if NSEvent.modifierFlags.contains(systemMenuModifier) {
            _ = hover.rest(.suppressed)
            return
        }
        guard let hit = windows.zoomButtonWindow(at: location) else {
            _ = hover.rest(.elsewhere)
            return
        }
        if hover.rest(.button(hit.button)) { onHover?(hit.window, location) }
    }
}

/// Zie `dragTapCallback`: meteen teruggeven, het werk gebeurt in de volgende ronde van de hoofdthread.
private func zoomTapCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if let userInfo {
        let monitor = Unmanaged<ZoomButtonMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        let location = event.location
        DispatchQueue.main.async { [weak monitor] in
            MainActor.assumeIsolated { monitor?.receive(type, at: location) }
        }
    }
    return Unmanaged.passUnretained(event)
}
