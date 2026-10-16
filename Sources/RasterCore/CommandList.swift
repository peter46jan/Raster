/// Eén lijst (Horizontal of Vertical): de commando's en hun volgorde met scheidingslijnen.
public struct CommandList: Codable, Equatable, Sendable {
    public var commands: [Command]
    public var layout: MenuLayout

    /// Zonder volgorde de standaardvolgorde; de volgorde wordt altijd opgeschoond tegen de commando's.
    public init(commands: [Command], layout: MenuLayout? = nil) {
        self.commands = commands
        self.layout = (layout ?? .standard(for: commands)).resolved(with: commands)
    }

    /// Een onleesbaar commando kost alleen dat commando, een onleesbare volgorde alleen de volgorde.
    private struct Lossy: Decodable {
        let command: Command?

        init(from decoder: Decoder) throws {
            command = try? Command(from: decoder)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case commands, layout
    }

    public init(from decoder: Decoder) throws {
        self = try Self.decodeReportingLoss(from: decoder).list
    }

    /// Leest de lijst zoals `init(from:)`; `lost` is waar als er een commando, de volgorde of een regel van de
    /// volgorde wegviel. Geen volgorde (of null) is de standaardvolgorde en geen verlies.
    static func decodeReportingLoss(from decoder: Decoder) throws -> (list: CommandList, lost: Bool) {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let read = try container.decode([Lossy].self, forKey: .commands)
        let commands = read.compactMap(\.command)
        var lost = commands.count != read.count
        var layout: MenuLayout?
        if container.contains(.layout), try !container.decodeNil(forKey: .layout) {
            if let decoded = try? MenuLayout.decodeReportingLoss(from: container.superDecoder(forKey: .layout)) {
                layout = decoded.layout
                lost = lost || decoded.lost
            } else {
                lost = true
            }
        }
        return (CommandList(commands: commands, layout: layout), lost)
    }

    public func command(_ id: String) -> Command? {
        commands.first { $0.id == id }
    }

    /// Menu-items in de volgorde van de lijst: alleen complete commando's die `include` doorlaat.
    public func menuItems(include: (Command) -> Bool) -> [MenuItem] {
        layout.items(for: commands) { $0.isComplete && include($0) }
    }

    /// Volgorde opnieuw opschonen na het toevoegen of verwijderen van commando's.
    mutating func resolveLayout() {
        layout = layout.resolved(with: commands)
    }
}

/// De twee lijsten: Horizontal en Vertical.
public struct CommandLists: Equatable, Sendable {
    public var horizontal: CommandList
    public var vertical: CommandList

    public init(horizontal: CommandList, vertical: CommandList) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    public static let standard = CommandLists(horizontal: CommandList(commands: DefaultCommands.horizontal),
                                              vertical: CommandList(commands: DefaultCommands.vertical))

    public static let empty = CommandLists(horizontal: CommandList(commands: []), vertical: CommandList(commands: []))

    public subscript(axis: CommandAxis) -> CommandList {
        get { axis == .vertical ? vertical : horizontal }
        set {
            if axis == .vertical { vertical = newValue } else { horizontal = newValue }
        }
    }

    /// Het commando met deze id, in welke lijst ook.
    public func command(_ id: String) -> Command? {
        horizontal.command(id) ?? vertical.command(id)
    }

    /// Het commando dat een sneltoets op deze as uitvoert: het eerste complete commando met die ingeschakelde sneltoets.
    public func command(for shortcut: Shortcut, axis: CommandAxis) -> Command? {
        self[axis].commands.first { $0.isComplete && $0.activeShortcut == shortcut }
    }

    /// Alle sneltoetsen die geregistreerd moeten worden; Horizontal en Vertical delen ze.
    public var activeShortcuts: Set<Shortcut> {
        Set((horizontal.commands + vertical.commands).filter(\.isComplete).compactMap(\.activeShortcut))
    }

    /// Of een ander compleet commando op dezelfde as deze sneltoets al gebruikt ("This combination is taken").
    public func isTaken(_ shortcut: Shortcut, axis: CommandAxis, except id: String) -> Bool {
        self[axis].commands.contains { $0.id != id && $0.isComplete && $0.activeShortcut == shortcut }
    }
}

extension CommandLists {
    /// Opgeschoond na het laden of omzetten:
    /// - elk commando krijgt de as van zijn lijst;
    /// - een standaardcommando hoort in de lijst van zijn as (volgens `DefaultCommands`); in de andere lijst valt het weg
    ///   en de standaardversie komt terug in de eigen lijst (eigen instellingen staan dan alleen in de back-up);
    /// - een id komt maar één keer voor (het eerste exemplaar blijft, Horizontal eerst);
    /// - onvolledige eigen commando's vallen weg (dat telt niet als verlies);
    /// - ontbrekende standaardcommando's komen achteraan terug (ze zijn niet te verwijderen, dus ontbreken is schade).
    /// `lost` is waar als er een commando wegviel dat er niet weg hoort: dubbel of in de verkeerde lijst.
    func normalized() -> (lists: CommandLists, lost: Bool) {
        var lists = self
        var seen = Set<String>()
        var lost = false
        for axis in CommandAxis.allCases {
            lists[axis].commands = self[axis].commands.compactMap { command in
                if command.group == .custom && !command.isComplete { return nil }
                if let standard = DefaultCommands.command(command.id), standard.axis != axis {
                    lost = true
                    return nil
                }
                guard seen.insert(command.id).inserted else {
                    lost = true
                    return nil
                }
                var command = command
                command.axis = axis
                return command
            }
        }
        for axis in CommandAxis.allCases {
            lists[axis].commands += DefaultCommands.list(for: axis).filter { !seen.contains($0.id) }
        }
        return (lists.withoutIncomplete(), lost) // ook de volgorde opschonen; aangevulde commando's komen achteraan
    }

    /// Of er een eigen commando zonder gebied in staat ("Incomplete Command"); precies wat
    /// `withoutIncomplete()` weghaalt.
    public var hasIncomplete: Bool {
        CommandAxis.allCases.contains { self[$0].commands.contains(where: Self.isIncomplete) }
    }

    /// Eigen commando zonder gebied; standaardcommando's met een leeg gebied blijven altijd staan.
    private static func isIncomplete(_ command: Command) -> Bool {
        command.group == .custom && !command.isComplete
    }

    /// Zonder eigen commando's die nog geen gebied hebben ("Incomplete Command"), met opgeschoonde volgorde.
    func withoutIncomplete() -> CommandLists {
        var lists = self
        for axis in CommandAxis.allCases {
            lists[axis].commands.removeAll(where: Self.isIncomplete)
            lists[axis].resolveLayout()
        }
        return lists
    }
}
