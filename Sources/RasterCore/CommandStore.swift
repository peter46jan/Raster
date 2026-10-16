import Foundation

/// De lijsten Horizontal en Vertical, bewaard in `commands.json`. Wat er bewaard is, is leidend:
/// ook gebieden van standaardcommando's zijn te wijzigen. Standaardcommando's zijn niet te verwijderen.
public struct CommandStore {
    public static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "Raster/commands.json")
    }

    public enum Error: Swift.Error {
        /// Er wordt niet opgeslagen (zie `readOnlyReason`): overschrijven zou gegevens kwijtmaken.
        case readOnly
    }

    /// Waarom er niet opgeslagen wordt.
    public enum ReadOnlyReason: Sendable {
        /// Het bestand komt van een nieuwere versie van de app.
        case newerFormat
        /// Het bestand moest omgezet of hersteld worden, maar de back-up van het origineel lukte niet.
        case backupFailed
        /// Het bestand bestaat maar kon niet gelezen worden (bijvoorbeeld door de rechten).
        case unreadable
    }

    public let fileURL: URL
    public private(set) var lists: CommandLists
    /// Gezet als het bestand niet overschreven mag worden: het komt van een nieuwere versie van de app, het kon niet
    /// gelezen worden, of het moest omgezet of hersteld worden en de back-up lukte niet. Een bestand van fase 1–5
    /// wordt verder gewoon omgezet.
    public private(set) var readOnlyReason: ReadOnlyReason?
    /// Waar als er niet opgeslagen wordt (`readOnlyReason`).
    public var isReadOnly: Bool { readOnlyReason != nil }

    public init(fileURL: URL) {
        self.fileURL = fileURL
        let loaded = CommandFile.load(from: fileURL)
        lists = loaded.lists
        readOnlyReason = loaded.readOnlyReason
        // Een omgezet of hersteld bestand is al apart bewaard; nu meteen als versie 2 schrijven.
        if loaded.needsSave {
            do {
                try save()
            } catch {
                NSLog("Raster: omgezette of herstelde commando's niet bewaard: %@", String(describing: error))
            }
        }
    }

    public func commands(for axis: CommandAxis) -> [Command] { lists[axis].commands }
    public func layout(for axis: CommandAxis) -> MenuLayout { lists[axis].layout }
    public func command(_ id: String) -> Command? { lists.command(id) }

    public mutating func setShortcut(_ shortcut: Shortcut?, for id: String) { modify(id) { $0.shortcut = shortcut } }
    public mutating func setShortcutEnabled(_ enabled: Bool, for id: String) { modify(id) { $0.shortcutEnabled = enabled } }
    public mutating func setDragZonesEnabled(_ enabled: Bool, for id: String) { modify(id) { $0.dragZonesEnabled = enabled } }
    public mutating func setInMenuBar(_ value: Bool, for id: String) { modify(id) { $0.inMenuBar = value } }
    public mutating func setInZoomButtonMenu(_ value: Bool, for id: String) { modify(id) { $0.inZoomButtonMenu = value } }
    public mutating func setArea(_ area: GridArea, for id: String) { modify(id) { $0.setArea(area) } }

    /// Sleepzones vervangen; niet bij speciale commando's (die hebben er geen).
    public mutating func setDragZones(_ zones: GridArea, for id: String) {
        modify(id) { if $0.dragZones != nil { $0.dragZones = zones } }
    }

    /// Nieuwe naam. Leeg bij een standaardcommando: de standaardnaam terug; leeg bij een eigen commando: niets.
    public mutating func setName(_ name: String, for id: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let original = DefaultCommands.command(id)
        modify(id) { command in
            if !trimmed.isEmpty {
                command.name = trimmed
            } else if let original {
                command.name = original.name
            }
        }
    }

    /// Nieuw eigen commando onderaan de lijst van `axis`: nog zonder gebied, sneltoets of sleepzones.
    @discardableResult
    public mutating func addCustom(axis: CommandAxis, name: String) -> Command {
        let command = Command(id: UUID().uuidString, name: name, axis: axis, group: .custom,
                              action: .area(GridArea(segments: [])), dragZones: GridArea(segments: []))
        lists[axis].commands.append(command)
        lists[axis].resolveLayout()
        return command
    }

    /// Standaardcommando's zijn niet te verwijderen ("Can’t be removed").
    public func isRemovable(_ id: String) -> Bool {
        DefaultCommands.command(id) == nil && lists.command(id) != nil
    }

    public mutating func remove(_ id: String) {
        guard isRemovable(id), let axis = lists.command(id)?.axis else { return }
        lists[axis].commands.removeAll { $0.id == id }
        lists[axis].resolveLayout()
    }

    /// Eigen commando's zonder gebied weggooien ("Incomplete Command" › Discard).
    public mutating func discardIncomplete() {
        lists = lists.withoutIncomplete()
    }

    /// Haalt de sleepzone(s) van `id` weg die cel `cell` bevatten (op het raster van zijn as).
    public mutating func removeDragZone(at cell: GridCell, from id: String) {
        modify(id) { command in
            guard var zones = command.dragZones else { return }
            zones.segments.removeAll { $0.contains(column: cell.column, row: cell.row) }
            command.dragZones = zones
        }
    }

    public mutating func moveLayoutEntries(_ axis: CommandAxis, fromOffsets source: IndexSet, toOffset destination: Int) {
        lists[axis].layout.move(fromOffsets: source, toOffset: destination)
    }

    public mutating func insertDivider(_ axis: CommandAxis, at index: Int) { lists[axis].layout.insertDivider(at: index) }
    public mutating func removeDivider(_ axis: CommandAxis, id: String) { lists[axis].layout.removeDivider(id: id) }

    /// Beide lijsten terug naar de standaard: eigen commando's weg, standaardvolgorde.
    public mutating func resetAll() {
        lists = .standard
    }

    private mutating func modify(_ id: String, _ change: (inout Command) -> Void) {
        for axis in CommandAxis.allCases {
            guard let index = lists[axis].commands.firstIndex(where: { $0.id == id }) else { continue }
            change(&lists[axis].commands[index])
            return
        }
    }

    public func save() throws {
        guard !isReadOnly else { throw Error.readOnly }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(StoredCommands(horizontal: lists.horizontal, vertical: lists.vertical)).write(to: fileURL, options: .atomic)
    }
}
