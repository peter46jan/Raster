import AppKit

/// Start Raster: menubalkapp zonder Dock-icoon met `AppDelegate`. Aangeroepen door het startpunt in de executable.
@MainActor
package enum RasterApplication {
    package static func run() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}
