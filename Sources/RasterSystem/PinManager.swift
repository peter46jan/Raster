import AppKit

/// "Altijd bovenop" (experimenteel en standaard uitgezet). macOS laat een app de laag van
/// vensters van andere apps niet zetten. Raster haalt vastgepinde vensters daarom met AXRaise weer naar
/// voren zodra een andere app actief wordt, en nog eens 0,25 s later (apps zetten na activeren hun eigen
/// vensters voor); die herhaling wordt bij elke activering opnieuw ingepland. Activeert een raise zelf de
/// app van een vastgepind venster, dan negeert Raster die melding kort, zodat het niet heen en weer gaat.
/// Binnen dezelfde app kan een vastgepind venster dus wel even achter raken.
@MainActor
public final class PinManager {
    private var pinned: [AXWindow] = []
    private var observer: NSObjectProtocol?
    private var delayedRaise: DispatchWorkItem?
    private var lastRaise: TimeInterval?

    public init() {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let pid = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
            MainActor.assumeIsolated { self?.appActivated(pid: pid) }
        }
    }

    isolated deinit {
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        delayedRaise?.cancel()
    }

    public var count: Int { pinned.count }

    public func isPinned(_ window: AXWindow) -> Bool {
        pinned.contains { CFEqual($0.element, window.element) }
    }

    /// Vastpinnen of loslaten.
    public func toggle(_ window: AXWindow) {
        if let index = pinned.firstIndex(where: { CFEqual($0.element, window.element) }) {
            pinned.remove(at: index)
        } else {
            pinned.append(window)
            window.raise()
        }
    }

    /// Laat alle vastgepinde vensters los van apps met deze bundle-ID's (uitgesloten apps).
    public func unpin(bundleIDs: Set<String>) {
        guard !bundleIDs.isEmpty else { return }
        pinned.removeAll { window in
            NSRunningApplication(processIdentifier: window.pid)?.bundleIdentifier.map(bundleIDs.contains) ?? false
        }
    }

    private func appActivated(pid: pid_t?) {
        guard !pinned.isEmpty else { return }
        if let pid, let lastRaise, ProcessInfo.processInfo.systemUptime - lastRaise < 0.5,
           pinned.contains(where: { $0.pid == pid }) {
            return
        }
        raiseAll()
        delayedRaise?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.raiseAll() }
        }
        delayedRaise = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    func raiseAll() {
        pinned.removeAll { window in
            if window.isGone { return true }
            guard let app = NSRunningApplication(processIdentifier: window.pid) else { return true }
            return app.isTerminated
        }
        var raised = false
        for window in pinned where !window.isMinimized {
            window.raise()
            raised = true
        }
        if raised { lastRaise = ProcessInfo.processInfo.systemUptime }
    }
}
