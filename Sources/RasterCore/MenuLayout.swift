import Foundation

/// Eén regel in de menuvolgorde: een commando (id van het commando) of een scheidingslijn (eigen id, "divider-N").
public struct MenuEntry: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case command, divider
    }

    public var kind: Kind
    public var id: String

    public init(kind: Kind, id: String) {
        self.kind = kind
        self.id = id
    }

    public static func command(_ id: String) -> MenuEntry { MenuEntry(kind: .command, id: id) }
}

/// Wat een menu toont.
public enum MenuItem: Equatable, Sendable {
    case command(Command)
    case divider
}

/// Volgorde van de commando's in de menu's, met scheidingslijnen (commando's slepen en "Add divider").
public struct MenuLayout: Codable, Equatable, Sendable {
    public var entries: [MenuEntry]

    public init(entries: [MenuEntry]) {
        self.entries = entries
    }

    /// Een regel die niet te lezen is wordt overgeslagen, niet de hele volgorde.
    private struct Lossy: Decodable {
        let entry: MenuEntry?

        init(from decoder: Decoder) throws {
            entry = try? MenuEntry(from: decoder)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case entries
    }

    public init(from decoder: Decoder) throws {
        self = try Self.decodeReportingLoss(from: decoder).layout
    }

    /// Leest de volgorde zoals `init(from:)`; `lost` is waar als er een onleesbare regel is overgeslagen.
    static func decodeReportingLoss(from decoder: Decoder) throws -> (layout: MenuLayout, lost: Bool) {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let read = try container.decode([Lossy].self, forKey: .entries)
        let entries = read.compactMap(\.entry)
        return (MenuLayout(entries: entries), entries.count != read.count)
    }

    /// Commando's in hun volgorde, met een scheidingslijn waar de groep wisselt (zoals standaard).
    /// De scheidingslijnen krijgen vaste ids ("divider-1", …), zodat de standaard altijd gelijk is aan zichzelf.
    public static func standard(for commands: [Command]) -> MenuLayout {
        var entries: [MenuEntry] = []
        var lastGroup: CommandGroup?
        var dividers = 0
        for command in commands {
            if let lastGroup, lastGroup != command.group {
                dividers += 1
                entries.append(MenuEntry(kind: .divider, id: "divider-\(dividers)"))
            }
            lastGroup = command.group
            entries.append(.command(command.id))
        }
        return MenuLayout(entries: entries)
    }

    /// Commando's die niet meer bestaan eruit, elk commando één keer, ontbrekende commando's achteraan
    /// (met een scheidingslijn ervoor als de groep verschilt van het laatste commando). Scheidingslijnen met een
    /// dubbele id of direct na een andere vervallen. Een scheidingslijn vlak vóór een weggevallen commando vervalt
    /// mee als daarna een scheidingslijn of het eind komt; andere scheidingslijnen, ook aan begin of eind, blijven
    /// staan (de menu's slaan die over). Ook een eigen scheidingslijn van de gebruiker vlak vóór dat commando
    /// vervalt zo; dat is bewust, extra administratie van wie een lijn plaatste is het niet waard.
    public func resolved(with commands: [Command]) -> MenuLayout {
        let byID = Dictionary(commands.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<String>()
        var dividerIDs = Set<String>()
        var result: [MenuEntry] = []
        for (index, entry) in entries.enumerated() {
            switch entry.kind {
            case .divider:
                guard dividerIDs.insert(entry.id).inserted, result.last?.kind != .divider else { continue }
                result.append(entry)
            case .command:
                if byID[entry.id] != nil, seen.insert(entry.id).inserted {
                    result.append(entry)
                    continue
                }
                // Wat er na dit weggevallen commando nog komt, zonder andere weggevallen commando's.
                let next = entries[(index + 1)...].first { $0.kind == .divider || byID[$0.id] != nil }
                if result.last?.kind == .divider, next == nil || next?.kind == .divider {
                    dividerIDs.remove(result.removeLast().id)
                }
            }
        }
        for command in commands where seen.insert(command.id).inserted {
            let lastGroup = result.last { $0.kind == .command }.flatMap { byID[$0.id]?.group }
            if let lastGroup, lastGroup != command.group, result.last?.kind != .divider {
                result.append(MenuEntry(kind: .divider, id: Self.freeDividerID(in: result)))
            }
            result.append(.command(command.id))
        }
        return MenuLayout(entries: result)
    }

    /// Menu-items voor de commando's die `include` doorlaat, in deze volgorde; geen scheidingslijn aan het begin,
    /// aan het eind of twee na elkaar.
    public func items(for commands: [Command], include: (Command) -> Bool) -> [MenuItem] {
        let byID = Dictionary(commands.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var items: [MenuItem] = []
        var pendingDivider = false
        for entry in entries {
            switch entry.kind {
            case .divider:
                pendingDivider = !items.isEmpty
            case .command:
                guard let command = byID[entry.id], include(command) else { continue }
                if pendingDivider { items.append(.divider) }
                pendingDivider = false
                items.append(.command(command))
            }
        }
        return items
    }

    /// Zelfde betekenis als `move(fromOffsets:toOffset:)` van SwiftUI (`List.onMove`).
    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.map { entries[$0] }
        let target = destination - source.count(in: 0..<destination)
        for index in source.reversed() { entries.remove(at: index) }
        entries.insert(contentsOf: moving, at: min(max(target, 0), entries.count))
    }

    public mutating func insertDivider(at index: Int) {
        entries.insert(MenuEntry(kind: .divider, id: Self.freeDividerID(in: entries)), at: min(max(index, 0), entries.count))
    }

    /// Eerste vrije "divider-N", zoals `standard(for:)` ze nummert; zo kan een aangevulde volgorde weer gelijk
    /// zijn aan de standaard.
    static func freeDividerID(in entries: [MenuEntry]) -> String {
        let used = Set(entries.lazy.filter { $0.kind == .divider }.map(\.id))
        var number = 1
        while used.contains("divider-\(number)") { number += 1 }
        return "divider-\(number)"
    }

    /// Verwijdert een scheidingslijn; commando's blijven staan.
    public mutating func removeDivider(id: String) {
        entries.removeAll { $0.kind == .divider && $0.id == id }
    }
}
