public enum SpecialAction: String, Codable, Sendable {
    case nextDisplay, previousDisplay, center, restore, stayOnTop
}

/// Wat een commando doet: een gebied op het raster van zijn as, of een speciale actie.
public enum CommandAction: Codable, Equatable, Sendable {
    case area(GridArea)
    case special(SpecialAction)
}

/// Groepen bepalen de scheidingslijnen in de standaardvolgorde; eigen commando's gaan bij slepen voor.
public enum CommandGroup: String, Codable, Sendable {
    case halves, corners, thirds, twoThirds, displays, other, custom
}

/// Er zijn aparte lijsten voor liggende schermen (Horizontal, raster 24 × 12) en staande (Vertical, 12 × 24).
public enum CommandAxis: String, Codable, CaseIterable, Sendable {
    case horizontal, vertical

    public var grid: GridSize { self == .vertical ? .portrait : .landscape }

    public static func `for`(_ grid: GridSize) -> CommandAxis { grid == .portrait ? .vertical : .horizontal }
}

public struct Command: Codable, Equatable, Identifiable, Sendable {
    /// Uniek over beide lijsten: "left" en "vertical.left" voor standaardcommando's, een UUID-tekst voor eigen commando's.
    public var id: String
    public var name: String
    public var axis: CommandAxis
    public var group: CommandGroup
    public var action: CommandAction
    /// Sleepzones op het raster van `axis`; nil bij speciale commando's.
    public var dragZones: GridArea?
    public var shortcut: Shortcut?
    /// Schakelaar "Keyboard shortcut": uit bewaart de sneltoets maar registreert hem niet.
    public var shortcutEnabled: Bool
    /// Schakelaar "Activation area for dragging".
    public var dragZonesEnabled: Bool
    public var inMenuBar: Bool
    public var inZoomButtonMenu: Bool

    public init(
        id: String,
        name: String,
        axis: CommandAxis,
        group: CommandGroup,
        action: CommandAction,
        dragZones: GridArea? = nil,
        shortcut: Shortcut? = nil,
        shortcutEnabled: Bool = true,
        dragZonesEnabled: Bool = true,
        inMenuBar: Bool = true,
        inZoomButtonMenu: Bool = true
    ) {
        self.id = id
        self.name = name
        self.axis = axis
        self.group = group
        self.action = action
        self.dragZones = dragZones
        self.shortcut = shortcut
        self.shortcutEnabled = shortcutEnabled
        self.dragZonesEnabled = dragZonesEnabled
        self.inMenuBar = inMenuBar
        self.inZoomButtonMenu = inZoomButtonMenu
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, axis, group, action, dragZones, shortcut, shortcutEnabled, dragZonesEnabled, inMenuBar, inZoomButtonMenu
    }

    /// `id`, `name`, `axis`, `group` en `action` zijn verplicht; de rest mag ontbreken.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            axis: try container.decode(CommandAxis.self, forKey: .axis),
            group: try container.decode(CommandGroup.self, forKey: .group),
            action: try container.decode(CommandAction.self, forKey: .action),
            dragZones: try container.decodeIfPresent(GridArea.self, forKey: .dragZones),
            shortcut: try container.decodeIfPresent(Shortcut.self, forKey: .shortcut),
            shortcutEnabled: try container.decodeIfPresent(Bool.self, forKey: .shortcutEnabled) ?? true,
            dragZonesEnabled: try container.decodeIfPresent(Bool.self, forKey: .dragZonesEnabled) ?? true,
            inMenuBar: try container.decodeIfPresent(Bool.self, forKey: .inMenuBar) ?? true,
            inZoomButtonMenu: try container.decodeIfPresent(Bool.self, forKey: .inZoomButtonMenu) ?? true
        )
    }
}

extension Command {
    /// Doelgebied, of nil bij speciale commando's.
    public var area: GridArea? {
        guard case .area(let area) = action else { return nil }
        return area
    }

    /// Zet het doelgebied; doet niets bij speciale commando's.
    public mutating func setArea(_ area: GridArea) {
        guard case .area = action else { return }
        action = .area(area)
    }

    /// Een commando met een leeg gebied is nog niet af ("Incomplete Command" in de lijst) en telt nergens mee.
    public var isComplete: Bool {
        area.map { !$0.segments.isEmpty } ?? true
    }

    /// De sneltoets die werkt: ingesteld en ingeschakeld.
    public var activeShortcut: Shortcut? {
        shortcutEnabled ? shortcut : nil
    }

    /// De sleepzones die werken: leeg als ze uit staan of als het commando er geen heeft.
    public var activeDragZones: GridArea {
        dragZonesEnabled ? dragZones ?? GridArea(segments: []) : GridArea(segments: [])
    }
}
