import AppKit

/// Magnet van CrowdCafé gebruikt dezelfde sneltoetsen; samen draaien geeft dubbele acties.
@MainActor
enum RealMagnetCheck {
    static let bundleID = "com.crowdcafe.windowmagnet"

    /// Vraagt de gebruiker of Magnet van CrowdCafé moet stoppen en wacht daar maximaal 3 seconden op.
    static func run() async {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        guard !running.isEmpty else { return }
        let alert = NSAlert()
        // Eigen teksten, behalve Cancel.
        alert.messageText = "Magnet by CrowdCafé is running"
        alert.informativeText = "Both apps use the same keyboard shortcuts. Quit Magnet by CrowdCafé to use this Magnet."
        alert.addButton(withTitle: "Quit Magnet by CrowdCafé")
        alert.addButton(withTitle: L10n.coreSheetButtonCancel)
        NSApp.activate()
        let choice = alert.runModal()
        defer { NSApp.yieldFocusIfIdle() }
        guard choice == .alertFirstButtonReturn else { return }
        for app in running { app.terminate() }
        var waited = 0
        while running.contains(where: { !$0.isTerminated }) && waited < 30 {
            try? await Task.sleep(for: .milliseconds(100))
            waited += 1
        }
        if running.contains(where: { !$0.isTerminated }) {
            let stillRunning = NSAlert()
            stillRunning.messageText = "Magnet by CrowdCafé hasn't quit yet"
            stillRunning.informativeText = "Both apps now respond to the same shortcuts."
            stillRunning.addButton(withTitle: "OK")
            NSApp.activate()
            stillRunning.runModal()
        }
    }
}
