import Foundation

/// Zet `commands.json` van fase 1–5 (versie 1: één lijst, per commando een liggend en een staand gebied) om naar de
/// twee lijsten van fase 6. Eigen commando's, sneltoetsen, eigen namen, zichtbaarheid, sleepzones en de menuvolgorde
/// komen in beide lijsten terug. Uitzondering: bij een uitgezet commando (`enabled = false`) komen de oude vinkjes
/// "in menubalk" en "in zoomknopmenu" niet terug (het staat dan in geen enkel menu); ze staan nog in de v1-back-up.
enum CommandMigration {
    private struct LegacyDragZones: Decodable {
        var landscape: GridArea
        var portrait: GridArea
    }

    private enum LegacyAction: Decodable {
        case area(landscape: GridArea, portrait: GridArea)
        case special(SpecialAction)
    }

    private struct LegacyCommand: Decodable {
        var id: String
        var name: String
        var group: CommandGroup
        var action: LegacyAction
        var dragZones: LegacyDragZones?
        var shortcut: Shortcut?
        var enabled: Bool
        var inMenuBar: Bool
        var inZoomButtonMenu: Bool

        private enum CodingKeys: String, CodingKey {
            case id, name, group, action, dragZones, shortcut, enabled, inMenuBar, inZoomButtonMenu
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            group = try container.decode(CommandGroup.self, forKey: .group)
            action = try container.decode(LegacyAction.self, forKey: .action)
            dragZones = try container.decodeIfPresent(LegacyDragZones.self, forKey: .dragZones)
            shortcut = try container.decodeIfPresent(Shortcut.self, forKey: .shortcut)
            enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
            inMenuBar = try container.decodeIfPresent(Bool.self, forKey: .inMenuBar) ?? true
            inZoomButtonMenu = try container.decodeIfPresent(Bool.self, forKey: .inZoomButtonMenu) ?? true
        }
    }

    /// Een onleesbaar commando kost alleen dat commando, een onleesbare volgorde alleen de volgorde (zoals in fase 5).
    private struct LegacyFile: Decodable {
        var commands: [LegacyCommand]
        var layout: MenuLayout?

        private struct Lossy: Decodable {
            let command: LegacyCommand?

            init(from decoder: Decoder) throws {
                command = try? LegacyCommand(from: decoder)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case commands, layout
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            commands = try container.decode([Lossy].self, forKey: .commands).compactMap(\.command)
            layout = try? container.decodeIfPresent(MenuLayout.self, forKey: .layout)
        }
    }

    /// Namen van fase 1–5. Wie een standaardcommando zo liet heten, krijgt de Engelse standaardnaam.
    private static let oldNames: [String: String] = [
        "left": "Links", "right": "Rechts", "up": "Boven", "down": "Onder",
        "topLeft": "Linksboven", "topRight": "Rechtsboven", "bottomLeft": "Linksonder", "bottomRight": "Rechtsonder",
        "leftThird": "Linkerderde", "centerThird": "Middelste derde", "rightThird": "Rechterderde",
        "leftTwoThirds": "Linker tweederde", "centerTwoThirds": "Middelste tweederde", "rightTwoThirds": "Rechter tweederde",
        "nextDisplay": "Volgend scherm", "previousDisplay": "Vorig scherm",
        "maximize": "Maximaliseren", "center": "Centreren", "restore": "Herstellen", "stayOnTop": "Altijd bovenop",
    ]

    /// Stay On Top zoals fase 4–5 het meeleverde; alleen een aangepast exemplaar blijft na de migratie in de lijsten.
    private static let oldStayOnTopShortcut = Shortcut(keyCode: 126, modifiers: Shortcut.controlOptionCommand)

    /// Id in Vertical bij een id van fase 1–5: de derden heten daar boven/onder, de rest krijgt "vertical.".
    static func verticalID(_ id: String) -> String {
        switch id {
        case "leftThird": "vertical.topThird"
        case "rightThird": "vertical.bottomThird"
        case "leftTwoThirds": "vertical.topTwoThirds"
        case "rightTwoThirds": "vertical.bottomTwoThirds"
        default: "vertical." + id
        }
    }

    static func migrate(_ data: Data) throws -> CommandLists {
        let file = try JSONDecoder().decode(LegacyFile.self, from: data)
        let stored = Dictionary(file.commands.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var lists = CommandLists.empty
        for axis in CommandAxis.allCases {
            func newID(_ oldID: String) -> String { axis == .vertical ? verticalID(oldID) : oldID }
            var commands: [Command] = []
            for horizontal in DefaultCommands.horizontal {
                guard var command = DefaultCommands.command(newID(horizontal.id)) else { continue }
                if let old = stored[horizontal.id] { apply(old, to: &command, axis: axis) }
                commands.append(command)
            }
            if let old = stored["stayOnTop"], keepsStayOnTop(old) {
                var command = DefaultCommands.stayOnTop(axis: axis)
                apply(old, to: &command, axis: axis)
                commands.append(command)
            }
            var seen = Set(commands.map(\.id))
            for old in file.commands where old.group == .custom && seen.insert(newID(old.id)).inserted {
                guard case .area(let landscape, let portrait) = old.action else { continue }
                var command = Command(id: newID(old.id), name: old.name, axis: axis, group: .custom,
                                      action: .area(axis == .vertical ? portrait : landscape), dragZones: GridArea(segments: []))
                apply(old, to: &command, axis: axis)
                commands.append(command)
            }
            let layout = file.layout.map { layout in
                MenuLayout(entries: layout.entries.map { $0.kind == .command ? .command(newID($0.id)) : $0 })
            }
            lists[axis] = CommandList(commands: commands, layout: layout)
        }
        return lists
    }

    /// Neemt over wat de gebruiker in fase 1–5 kon instellen. Uitgezet (`enabled = false`) wordt: sneltoets uit,
    /// sleepzones uit en in geen enkel menu; sneltoets en zones zelf blijven bewaard.
    private static func apply(_ old: LegacyCommand, to command: inout Command, axis: CommandAxis) {
        if old.group == .custom || old.name != oldNames[old.id] { command.name = old.name }
        command.shortcut = old.shortcut
        if let zones = old.dragZones, command.dragZones != nil {
            command.dragZones = axis == .vertical ? zones.portrait : zones.landscape
        }
        command.shortcutEnabled = old.enabled
        command.dragZonesEnabled = old.enabled
        command.inMenuBar = old.enabled && old.inMenuBar
        command.inZoomButtonMenu = old.enabled && old.inZoomButtonMenu
    }

    /// Ongewijzigd (standaardnaam, ⌃⌥⌘↑, in beide menu's) of uitgezet: weg.
    private static func keepsStayOnTop(_ old: LegacyCommand) -> Bool {
        old.enabled && (old.name != oldNames["stayOnTop"] || old.shortcut != oldStayOnTopShortcut
            || !old.inMenuBar || !old.inZoomButtonMenu)
    }
}
