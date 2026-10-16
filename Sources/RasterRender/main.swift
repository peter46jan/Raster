import AppKit

// raster-render: tekent onderdelen van de interface offscreen naar PNG's, voor snapshots van de interface en om ze
// met referentie-schermafbeeldingen te vergelijken. Gelinkt met SDK-versie 15.2 zoals de app (zie Package.swift), zodat AppKit dezelfde
// (oudere) vormgeving tekent; het testproces kan dat niet. Toont niets en start niets van de app: geen runloop van
// NSApp, geen menubalkicoon, geen sneltoetsen.
//
// Gebruik: swift run raster-render <map> [colors|icons|menu|settings|components|preferences|commands|detail …]   (zonder namen: alles)

let arguments = CommandLine.arguments.dropFirst()
guard let directory = arguments.first else {
    FileHandle.standardError.write(Data("gebruik: raster-render <map> [naam …], namen: colors icons menu settings components preferences commands detail\n".utf8))
    exit(2)
}

MainActor.assumeIsolated {
    _ = NSApplication.shared
    // Geen Dock-icoon, geen menubalk, nooit actief.
    NSApp.setActivationPolicy(.prohibited)
    Render.directory = directory

    // Per naam een functie in een eigen bestand; nieuwe renders krijgen hier een regel.
    let renders: [(name: String, run: @MainActor (String) throws -> Void)] = [
        ("colors", { _ in try BasicRenders.colors() }),
        ("icons", { _ in try BasicRenders.icons() }),
        ("menu", { _ in try BasicRenders.menu() }),
        ("settings", { _ in try SettingsRenders.settingsChrome() }),
        ("components", { _ in try SettingsRenders.components() }),
        ("preferences", renderPreferences(to:)),
        ("commands", renderCommands(to:)),
        ("detail", renderDetail(to:)),
    ]
    let wanted = Set(arguments.dropFirst())
    if let unknown = wanted.subtracting(renders.map(\.name)).first {
        FileHandle.standardError.write(Data("onbekend: \(unknown)\n".utf8))
        exit(2)
    }
    do {
        for render in renders where wanted.isEmpty || wanted.contains(render.name) {
            try render.run(directory)
            print("✓ \(render.name)")
        }
        SettingsRenders.cleanUp()
    } catch {
        SettingsRenders.cleanUp()
        FileHandle.standardError.write(Data("mislukt: \(error)\n".utf8))
        exit(1)
    }
}
