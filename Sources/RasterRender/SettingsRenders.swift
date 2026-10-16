import AppKit
import RasterCore
import SwiftUI
import RasterUI

/// Het instellingenvenster offscreen naar PNG, om naast `referentie-prefs.png` (Preferences, inactief, @1x) en
/// `referentie-commands.png` (Commands, actief, @2x) te leggen.
@MainActor
enum SettingsRenders {
    /// Het hele venster met titelbalk: elk paneel actief en inactief, licht en donker, @2x en (voor de vergelijking
    /// met `referentie-prefs.png`) @1x, als `settings-<paneel>-…`. In `settings-chrome.txt` de plaats van de verkeerslichten
    /// in vensterpunten.
    static func settingsChrome() throws {
        var report: [String] = []
        for panel in SettingsPanel.allCases {
            try renderWindow(panel: panel, name: "settings-\(panel)") { window, name, dark in
                if !dark { report.append(name + ": " + describeButtons(of: window)) }
            }
        }
        try (report.joined(separator: "\n") + "\n").write(toFile: Render.directory + "/settings-chrome.txt",
                                                         atomically: true, encoding: .utf8)
    }

    /// Rendert het hele instellingenvenster met `panel` (en voor Commands `commandID` gekozen) in elke combinatie van
    /// `actives` × `darks` × `scales`, als `<name>-active|inactive[-1x][-dark].png` (schaal 2 zonder achtervoegsel,
    /// anders `-<schaal>x`). `inspect` krijgt elk venster mee (bijv. voor maten in een tekstbestand).
    static func renderWindow(panel: SettingsPanel, name: String, commandID: String? = "left",
                             actives: [Bool] = [true, false], darks: [Bool] = [false, true],
                             scales: [CGFloat] = [2, 1],
                             inspect: (NSWindow, String, Bool) throws -> Void = { _, _, _ in }) throws {
        for active in actives {
            for dark in darks {
                let window = try Self.window(panel: panel, active: active, dark: dark, commandID: commandID)
                let base = name + (active ? "-active" : "-inactive")
                for scale in scales {
                    let suffix = scale == 2 ? "" : "-\(Int(scale))x"
                    try Render.window(window, name: base + suffix, dark: dark, scale: scale)
                }
                try inspect(window, base, dark)
            }
        }
    }

    /// De bouwstenen als de kaarten General, Mouse, Activation Areas en Target Areas van `referentie-prefs.png`: de
    /// inhoudskolom (530 breed) vanaf de onderkant van de iCloud-kaart (y 171 in de referentie), @1x en @2x.
    static func components() throws {
        let view = ComponentsSample()
        for dark in [false, true] {
            try Render.view(view, size: CGSize(width: 530, height: 659), name: "settings-components", dark: dark)
            try Render.view(view, size: CGSize(width: 530, height: 659), name: "settings-components-1x", dark: dark,
                            scale: 1)
        }
    }

    /// Een niet-getoond instellingenvenster met `panel` gekozen; Commands opent met `commandID`.
    static func window(panel: SettingsPanel, active: Bool, dark: Bool, commandID: String? = "left") throws -> NSWindow {
        let file = scratch.appending(path: "commands-\(UUID().uuidString).json")
        let controller = SettingsWindowController(
            model: CommandsModel(store: CommandStore(fileURL: file)),
            snapping: SnappingSettings(state: SnappingState(), set: { _ in }),
            settings: AppSettings(storage: InMemorySettingsStorage()),
            loginItem: LoginItemState(), onShow: {}, onReset: { _ in })
        let window = Render.Window(contentRect: CGRect(x: 0, y: 0, width: panel.width, height: SettingsMetrics.height),
                                   styleMask: SettingsWindowController.styleMask, backing: .buffered, defer: false)
        window.isActive = active
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        controller.navigation.selectedCommandID = commandID
        controller.install(in: window)
        controller.select(panel, animate: false)
        retained.append(controller)
        // SwiftUI werkt de inhoud bij in de runloop.
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        return window
    }

    /// Controllers blijven bestaan zolang het programma loopt (het venster houdt ze niet vast).
    private static var retained: [SettingsWindowController] = []

    /// Eigen tijdelijke map (commands.json en eventuele back-ups), nooit die van de app. Voorkeuren staan alleen in
    /// het geheugen (`InMemorySettingsStorage`): raster-render schrijft niets naar ~/Library/Preferences.
    private static let scratch = FileManager.default.temporaryDirectory.appending(path: "raster-render-\(UUID().uuidString)")

    /// Ruimt de tijdelijke map op; aan het eind van `raster-render`.
    static func cleanUp() {
        try? FileManager.default.removeItem(at: scratch)
    }

    /// Middelpunten van de verkeerslichten (vanaf linksboven) en of de groene knop zichtbaar is.
    private static func describeButtons(of window: NSWindow) -> String {
        let height = window.frame.height
        var parts = ["venster \(Int(window.frame.width)) × \(Int(height))"]
        for (name, type) in [("sluiten", NSWindow.ButtonType.closeButton), ("minimaliseren", .miniaturizeButton),
                             ("zoom", .zoomButton)] {
            guard let button = window.standardWindowButton(type) else { continue }
            let frame = button.convert(button.bounds, to: nil)
            parts.append("\(name) (\(frame.midX), \(height - frame.midY)) \(Int(frame.width))×\(Int(frame.height))"
                         + (button.isHidden ? " verborgen" : ""))
        }
        return parts.joined(separator: ", ")
    }
}

/// Voorbeeld met de teksten van het paneel Preferences (alleen voor de vergelijking).
private struct ComponentsSample: View {
    @State private var on = true
    @State private var off = false
    @State private var scale = 0.8
    @State private var edge = 8.0
    @State private var outline = 2.0
    @State private var appearance = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle("General")
            SettingsCard {
                SettingsRow(title: "Open Raster at login") { MiniSwitch(isOn: $on) }
                SettingsRow(title: "Hide menu bar icon", subtitle: "With the icon hidden, open Raster again from Applications\n"
                            + "or with Spotlight to get back to these settings.") {
                    MiniSwitch(isOn: $off)
                }
            }
            SectionTitle("Mouse")
            SettingsCard {
                SettingsRow(title: "Drag windows to snap them") { MiniSwitch(isOn: $on) }
                SettingsRow(title: "Restore size when dragged away", subtitle: "A snapped window gets its earlier size "
                            + "back\nas soon as you drag it out of place.") { MiniSwitch(isOn: $on) }
            }
            SectionTitle("Snap Zones")
            SettingsCard {
                SettingsRow(title: "Show snap zones while dragging") { MiniSwitch(isOn: $off) }
                SettingsRow(title: "Size of snap zones away from edges", placement: .centered) {
                    StepperValue(text: "\(Int(scale * 100)) %", value: $scale, in: 0.5...2, step: 0.1)
                }
                SettingsRow(title: "Width of snap zones at screen edges", placement: .centered) {
                    StepperValue(text: "\(Int(edge)) pt", value: $edge, in: 1...40)
                }
            }
            SectionTitle("Snap Preview")
            SettingsCard {
                SettingsRow(title: "Preview appearance", placement: .centered) {
                    PopUp(selection: $appearance, options: [(0, "Automatic"), (1, "Custom")])
                }
                SettingsRow(title: "Preview outline", placement: .centered) {
                    StepperValue(text: "\(Int(outline)) pt", value: $outline, in: 0...5)
                }
            }
            SectionTitle("Green Button")
            Spacer(minLength: 0)
        }
        .padding(.leading, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RasterColor.background.color)
    }
}
