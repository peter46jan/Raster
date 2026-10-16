import AppKit
import RasterCore
import RasterUI

/// Paneel Preferences (taak 8), steeds het hele venster:
/// - `preferences-…`: standaardvoorkeuren, actief en inactief, licht en donker, @2x en @1x;
/// - `preferences-aangepast-…`: de waarden uit `referentie-prefs.png` (80 %, 8 pt, 2 pt, slepen aan) om ernaast te leggen;
/// - `preferences-full-…`: het venster hoger gemaakt (1250 pt) zodat alle secties zichtbaar zijn, met de gebieden
///   getoond en overal "Custom" (kleurkiezers), actief, licht en donker, @2x en @1x.
@MainActor
func renderPreferences(to directory: String) throws {
    Render.directory = directory
    defer { PreferencesRenders.cleanUp() }
    try SettingsRenders.renderWindow(panel: .preferences, name: "preferences")
    try PreferencesRenders.render(name: "preferences-aangepast", values: PreferencesRenders.aangepast, scales: [1, 2])
    try PreferencesRenders.render(name: "preferences-full", values: PreferencesRenders.full, actives: [true],
                                  height: 1250)
}

@MainActor
enum PreferencesRenders {
    /// De voorkeuren uit de referentie-opname.
    static let aangepast: [String: Any] = [
        "activationAreaScale": 0.8, "activationAreaEdgeWidth": 8, "previewOutline": 2.0, "restoreToOriginalSize": true,
    ]

    /// Alle rijen zichtbaar: gebieden getoond, eigen kleuren, marge (dan is "Fit tightly" te kiezen).
    static let full: [String: Any] = [
        "highlightZones": true, "zoneAppearance": "custom", "previewAppearance": "custom", "zoneOutline": 1.5,
        "margin": 8, "fitTightly": true,
    ]

    /// Rendert het venster met Preferences en `values` als voorkeuren (slepen aan en actief), als
    /// `<name>-active|inactive[-1x][-dark].png`.
    static func render(name: String, values: [String: Any], actives: [Bool] = [true, false],
                       scales: [CGFloat] = [2, 1], height: CGFloat = SettingsMetrics.height) throws {
        for active in actives {
            for dark in [false, true] {
                let window = try window(values: values, active: active, dark: dark, height: height)
                for scale in scales {
                    let suffix = scale == 2 ? "" : "-\(Int(scale))x"
                    try Render.window(window, name: name + (active ? "-active" : "-inactive") + suffix, dark: dark,
                                      scale: scale)
                }
            }
        }
    }

    /// Als `SettingsRenders.window`, maar met eigen voorkeuren, slepen aan en eventueel een hoger venster.
    private static func window(values: [String: Any], active: Bool, dark: Bool, height: CGFloat) throws -> NSWindow {
        let controller = SettingsWindowController(
            model: CommandsModel(store: CommandStore(fileURL: scratch.appending(path: "commands-\(UUID().uuidString).json"))),
            snapping: SnappingSettings(state: SnappingState(isEnabled: true, isRunning: true), set: { _ in }),
            settings: AppSettings(storage: InMemorySettingsStorage(values)),
            loginItem: LoginItemState(), onShow: {}, onReset: { _ in })
        let window = Render.Window(contentRect: CGRect(x: 0, y: 0, width: SettingsPanel.preferences.width, height: height),
                                   styleMask: SettingsWindowController.styleMask, backing: .buffered, defer: false)
        window.isActive = active
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        controller.install(in: window)
        if height != SettingsMetrics.height {
            window.setFrame(CGRect(x: 0, y: 0, width: SettingsPanel.preferences.width, height: height), display: false)
        }
        retained.append(controller)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        return window
    }

    private static var retained: [SettingsWindowController] = []

    /// Eigen tijdelijke map, nooit die van de app; `cleanUp` ruimt hem op. Voorkeuren staan alleen in het geheugen.
    private static let scratch = FileManager.default.temporaryDirectory
        .appending(path: "raster-render-preferences-\(UUID().uuidString)")

    static func cleanUp() {
        try? FileManager.default.removeItem(at: scratch)
    }
}
