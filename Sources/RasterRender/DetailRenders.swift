import AppKit
import RasterCore
import RasterUI
import SwiftUI

/// Detailkolom van Commands (taak 10): het hele venster per gekozen commando, actief, licht en donker, @2x:
/// `detail-left-…` (Horizontal, naast `referentie-commands.png` te leggen met een verschuiving van (−6, −3) pt; ook inactief),
/// `detail-topthird-…` (Vertical), `detail-center-…` (speciaal: alleen sneltoets en zichtbaarheid) en
/// `detail-new-…` (nieuw commando "Command" met een leeg gebied). Verder de bouwstenen van de kaarten los
/// (`detail-target-…`, `detail-shortcut-…`, `detail-activation-…`).
@MainActor
func renderDetail(to directory: String) throws {
    Render.directory = directory
    try SettingsRenders.renderWindow(panel: .commands, name: "detail-left", commandID: "left", scales: [2])
    try SettingsRenders.renderWindow(panel: .commands, name: "detail-topthird", commandID: "vertical.topThird",
                                     actives: [true], scales: [2])
    try SettingsRenders.renderWindow(panel: .commands, name: "detail-center", commandID: "center",
                                     actives: [true], scales: [2])
    for dark in [false, true] {
        try Render.window(try NewCommandWindow.make(dark: dark), name: "detail-new-active", dark: dark)
    }
    try DetailComponentRenders.render()
}

/// Instellingenvenster met Commands en een nieuw, nog leeg commando gekozen (zoals na de knop +). Zoals
/// `SettingsRenders.window`, maar met een eigen model, zodat het commando toegevoegd kan worden.
@MainActor
private enum NewCommandWindow {
    static func make(dark: Bool) throws -> NSWindow {
        let file = FileManager.default.temporaryDirectory
            .appending(path: "raster-render-new-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        // Zoals de knop + (de naam is de standaardnaam, `L10n.commandDefaultName`).
        var store = CommandStore(fileURL: file)
        let command = store.addCustom(axis: .horizontal, name: "Command")
        let model = CommandsModel(store: store)
        let controller = SettingsWindowController(
            model: model, snapping: SnappingSettings(state: SnappingState(), set: { _ in }),
            settings: AppSettings(storage: InMemorySettingsStorage()),
            loginItem: LoginItemState(), onShow: {}, onReset: { _ in })
        let window = Render.Window(contentRect: CGRect(x: 0, y: 0, width: SettingsPanel.commands.width,
                                                       height: SettingsMetrics.height),
                                   styleMask: SettingsWindowController.styleMask, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        // Meteen in Commands beginnen: wisselen van paneel gooit onvolledige commando's weg.
        controller.navigation.panel = .commands
        controller.navigation.selectedCommandID = command.id
        controller.install(in: window)
        retained.append(controller)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        return window
    }

    /// Controllers blijven bestaan zolang het programma loopt (het venster houdt ze niet vast).
    private static var retained: [SettingsWindowController] = []
}

/// De drie bouwstenen van de detailkolom, elk in een kaart zoals in `referentie-commands.png` (486 breed, titel op x 14,
/// basislijn 25, schakelaar rechts): doelgebied, sneltoetsveld en activeringsraster, voor Left (Horizontal) en Top Third
/// (Vertical), en de toestanden opnemen, "taken", uitgeschakeld en hover; licht en donker, @2x.
@MainActor
enum DetailComponentRenders {
    static func render() throws {
        let file = FileManager.default.temporaryDirectory
            .appending(path: "raster-render-detail-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let model = CommandsModel(store: CommandStore(fileURL: file))
        guard let left = DefaultCommands.command("left"),
              let topThird = DefaultCommands.command("vertical.topThird") else { return }

        for dark in [false, true] {
            // Doelgebied.
            try card(TargetCard(command: left), name: "detail-target-left", dark: dark)
            try card(TargetCard(command: topThird), name: "detail-target-topthird", dark: dark)

            // Activeringsraster, ook met hover op de eigen zone en op een grijze zone, en uitgeschakeld.
            try card(ActivationCard(command: left), name: "detail-activation-left", dark: dark)
            try card(ActivationCard(command: left, hover: GridCell(column: 0, row: 5)),
                     name: "detail-activation-left-hover", dark: dark)
            try card(ActivationCard(command: left, hover: GridCell(column: 5, row: 11)),
                     name: "detail-activation-left-hover-other", dark: dark)
            try card(ActivationCard(command: left, isEnabled: false), name: "detail-activation-left-disabled", dark: dark)
            try card(ActivationCard(command: topThird), name: "detail-activation-topthird", dark: dark)

            // Sneltoetsveld: met sneltoets, zonder, opnemen, "taken" en uitgeschakeld.
            try card(ShortcutCard(model: model, command: left), name: "detail-shortcut-left", dark: dark)
            var empty = left
            empty.id = "render.empty"
            empty.shortcut = nil
            try card(ShortcutCard(model: model, command: empty), name: "detail-shortcut-empty", dark: dark)
            model.startRecording(for: left.id)
            try card(ShortcutCard(model: model, command: left), name: "detail-shortcut-recording", dark: dark)
            // ⌃⌥▶ is van Right: niet toegewezen, de opname loopt door.
            model.handleKey(keyCode: 124, flags: [.control, .option])
            try card(ShortcutCard(model: model, command: left), name: "detail-shortcut-taken", dark: dark)
            model.cancelRecording()
            var disabled = left
            disabled.id = "render.disabled"
            disabled.shortcutEnabled = false
            try card(ShortcutCard(model: model, command: disabled), name: "detail-shortcut-disabled", dark: dark)
        }
    }

    /// Een kaart op de detailachtergrond met 10 pt rand eromheen, in een (niet getoond) actief venster: zonder venster
    /// tekent SwiftUI tekst op 1x en schakelaars als in een inactief venster.
    private static func card<V: View>(_ content: V, name: String, dark: Bool) throws {
        let view = content
            .padding(10)
            .fixedSize()
            .background(RasterColor.background.color)
        let host = NSHostingView(rootView: view)
        let size = host.fittingSize
        let window = Render.Window(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless],
                                   backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentView = host
        host.frame = CGRect(origin: .zero, size: size)
        // SwiftUI werkt de inhoud bij in de runloop.
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        try Render.view(host, name: name, dark: dark)
        windows.append(window)
    }

    /// Vensters blijven bestaan tot het eind (vrijgeven tijdens het tekenen van SwiftUI geeft problemen).
    private static var windows: [NSWindow] = []
}

/// Kaart zoals in de detailkolom (alleen voor de vergelijking): 486 breed, radius 6, vulling `card`, haarlijnrand
/// `border`; titel SF 13 op x 14 met de basislijn 25 pt onder de bovenkant; schakelaar rechts op het midden van de
/// titelregel (y 20).
private struct SampleCard<Content: View>: View {
    let title: String
    let height: CGFloat
    var switchOn: Bool?
    @ViewBuilder let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        ZStack(alignment: .topLeading) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Color(nsColor: .labelColor))
                .alignmentGuide(.top) { $0[.firstTextBaseline] - 25 }
                .padding(.leading, 14)
            content
        }
        .frame(width: 486, height: height, alignment: .topLeading)
        .overlay(alignment: .topTrailing) {
            if let switchOn {
                MiniSwitch(isOn: .constant(switchOn), label: title)
                    .frame(height: 40)
                    .padding(.trailing, 14)
            }
        }
        .background(shape.fill(RasterColor.card.color))
        .overlay(shape.strokeBorder(RasterColor.border.color, lineWidth: 0.5))
    }
}

/// "Intended window size and position": raster op (52, 73) bij Horizontal, horizontaal gecentreerd bij Vertical; 43 pt
/// onder het raster tot de rand.
private struct TargetCard: View {
    let command: Command

    var body: some View {
        let grid = command.axis.grid
        let size = gridSize(grid)
        SampleCard(title: "Window size and position", height: 73 + size.height + 43) {
            TargetAreaGrid(grid: grid, area: command.area ?? GridArea(segments: []), onChange: { _ in })
                .offset(x: ((486 - size.width) / 2).rounded(.down), y: 73)
        }
    }

    private func gridSize(_ grid: GridSize) -> CGSize {
        CGSize(width: CGFloat(grid.columns) * 16 - 2, height: CGFloat(grid.rows) * 16 - 2)
    }
}

/// "Keyboard shortcut": veld op (14, 42), 458 breed; kaart 86 hoog. Gemeten in `referentie-commands.png`: haarlijn op 41,5–42
/// en op x 14,5, wit van 42 tot 66,5, schaduw tot 68.
private struct ShortcutCard: View {
    let model: CommandsModel
    let command: Command

    var body: some View {
        SampleCard(title: "Keyboard shortcut", height: 86, switchOn: command.shortcutEnabled) {
            ShortcutField(model: model, command: command)
                .frame(width: 458)
                .offset(x: 14, y: 42)
        }
    }
}

/// "Activation area for dragging": raster op (51, 62) bij Horizontal, horizontaal gecentreerd bij Vertical; 42 pt
/// onder het raster tot de rand. De grijze zones zijn die van de andere standaardcommando's op dezelfde as.
private struct ActivationCard: View {
    let command: Command
    var hover: GridCell?
    var isEnabled = true

    var body: some View {
        let grid = command.axis.grid
        let size = CGSize(width: CGFloat(grid.columns) * 16, height: CGFloat(grid.rows) * 16)
        SampleCard(title: "Snap zone for dragging", height: 62 + size.height + 42, switchOn: isEnabled) {
            ActivationAreaGrid(grid: grid, zones: command.dragZones ?? GridArea(segments: []),
                               others: ActivationAreaGrid.others(for: command, in: DefaultCommands.list(for: command.axis)),
                               isEnabled: isEnabled, onChange: { _ in }, onRemoveOther: { _, _ in })
                .environment(\.activationAreaPreviewHover, hover)
                .offset(x: (486 - size.width) / 2, y: 62)
        }
    }
}
