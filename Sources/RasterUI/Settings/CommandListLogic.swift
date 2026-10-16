import AppKit
import RasterCore

// Logica van de lijstkolom in Commands, los van de views zodat de tests er zonder scherm bij kunnen.

/// Eén rij in de lijstkolom: een commando of een scheidingsrij. Scheidingsrijen dragen hun as mee: hun id
/// ("divider-1", …) is alleen binnen één lijst uniek.
enum CommandListRow: Equatable, Identifiable {
    case command(Command)
    case divider(axis: CommandAxis, id: String)

    /// Uniek over beide lijsten: de id van het commando (die zijn al uniek), of "divider:<as>:<id>".
    var id: String {
        switch self {
        case .command(let command): command.id
        case .divider(let axis, let id): Self.dividerRowID(axis: axis, id: id)
        }
    }

    static func dividerRowID(axis: CommandAxis, id: String) -> String {
        "divider:\(axis.rawValue):\(id)"
    }

    var command: Command? {
        if case .command(let command) = self { return command }
        return nil
    }

    /// De regel in de menuvolgorde die deze rij toont.
    var entry: MenuEntry {
        switch self {
        case .command(let command): .command(command.id)
        case .divider(_, let id): MenuEntry(kind: .divider, id: id)
        }
    }

    /// De rijen van de lijst van `axis` in de volgorde van zijn `layout`, één rij per regel. Een regel waarvan het commando
    /// ontbreekt (komt na opschonen niet voor) valt weg; verplaatsen rekent daarom met de plaats in `layout.entries`
    /// (`entryIndex`), niet met de plaats van de rij.
    static func rows(of lists: CommandLists, axis: CommandAxis) -> [CommandListRow] {
        let list = lists[axis]
        let byID = Dictionary(list.commands.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return list.layout.entries.compactMap { entry in
            switch entry.kind {
            case .divider: .divider(axis: axis, id: entry.id)
            case .command: byID[entry.id].map(CommandListRow.command)
            }
        }
    }
}

/// Knop die bij hover rechts in een rij verschijnt.
struct CommandRowButton: Equatable, Identifiable {
    enum Kind: Equatable {
        /// "Visible in green button menu": aan/uit.
        case greenMenu
        /// "Visible in menu bar": aan/uit.
        case menuBar
        case remove
    }

    let kind: Kind
    /// Bij green-menu en menu-bar: of het commando zichtbaar is (anders doorgestreept).
    let isOn: Bool
    let isEnabled: Bool
    let tooltip: String

    var id: Kind { kind }

    /// Sjabloonicoon van 20 × 20.
    @MainActor var image: NSImage {
        switch kind {
        case .greenMenu: isOn ? RasterIcons.greenMenu : RasterIcons.greenMenuCrossed
        case .menuBar: isOn ? RasterIcons.menuBar : RasterIcons.menuBarCrossed
        case .remove: RasterIcons.remove
        }
    }

    /// Green-menu, menu-bar en remove. Remove is uitgeschakeld voor standaardcommando's ("Can’t be
    /// removed"); in alleen-lezen-modus is alles uitgeschakeld.
    static func buttons(for command: Command, isRemovable: Bool, isReadOnly: Bool = false) -> [CommandRowButton] {
        [
            CommandRowButton(kind: .greenMenu, isOn: command.inZoomButtonMenu, isEnabled: !isReadOnly,
                             tooltip: command.inZoomButtonMenu
                                 ? L10n.commandListSectionRowButtonVisibleInGreenButtonMenuTooltipEnabled
                                 : L10n.commandListSectionRowButtonVisibleInGreenButtonMenuTooltipDisabled),
            CommandRowButton(kind: .menuBar, isOn: command.inMenuBar, isEnabled: !isReadOnly,
                             tooltip: command.inMenuBar
                                 ? L10n.commandListSectionRowButtonVisibleInMenuBarTooltipEnabled
                                 : L10n.commandListSectionRowButtonVisibleInMenuBarTooltipDisabled),
            removeButton(isRemovable: isRemovable && !isReadOnly, explainsDefault: !isRemovable),
        ]
    }

    /// Een scheidingsrij heeft alleen de remove-knop.
    static func dividerButtons(isReadOnly: Bool = false) -> [CommandRowButton] {
        [removeButton(isRemovable: !isReadOnly, explainsDefault: false)]
    }

    /// `explainsDefault`: de tooltip zegt "Can’t be removed" (standaardcommando), anders "Remove".
    private static func removeButton(isRemovable: Bool, explainsDefault: Bool) -> CommandRowButton {
        CommandRowButton(kind: .remove, isOn: true, isEnabled: isRemovable,
                         tooltip: explainsDefault ? L10n.commandListSectionRowButtonRemoveTooltipDisabled
                                                  : L10n.commandListSectionRowButtonRemoveTooltipEnabled)
    }
}

/// Keuzes van de lijstkolom die geen view nodig hebben.
enum CommandListLogic {
    /// Hoogte van een rij en een scheidingsrij (pt).
    static let rowHeight: CGFloat = 30

    /// Tooltip van de chevron: uitgeklapt "Collapse", ingeklapt "Expand".
    static func chevronTooltip(isExpanded: Bool) -> String {
        isExpanded ? L10n.commandListSectionHeaderExpandButtonTooltipCollapse
                   : L10n.commandListSectionHeaderExpandButtonTooltipExpand
    }

    /// Draaiing van de chevron (graden, met de klok mee): ingeklapt wijst hij naar rechts, uitgeklapt omlaag.
    static func chevronAngle(isExpanded: Bool) -> Double { isExpanded ? 90 : 0 }

    /// Vraagt het wisselen van `current` naar `next` om "Incomplete Command"? Alleen als het huidige commando nog
    /// geen gebied heeft en er echt iets anders gekozen wordt.
    static func needsLeaveConfirmation(current: Command?, next: String?) -> Bool {
        guard let current, !current.isComplete else { return false }
        return next != current.id
    }

    /// Het commando dat gekozen wordt als `id` uit de lijst verdwijnt: het volgende commando eronder, anders het
    /// vorige, anders geen.
    static func selectionAfterRemoving(_ id: String, rows: [CommandListRow]) -> String? {
        guard let index = rows.firstIndex(where: { $0.command?.id == id }) else { return nil }
        let after = rows[(index + 1)...].lazy.compactMap(\.command).first
        let before = rows[..<index].reversed().lazy.compactMap(\.command).first
        return (after ?? before)?.id
    }

    /// Plaats tussen de rijen (0 … `count`) waar een gesleepte rij terechtkomt, voor een punt `y` pt onder de
    /// bovenkant van de eerste rij: de dichtstbijzijnde grens tussen twee rijen.
    static func insertionIndex(y: CGFloat, count: Int) -> Int {
        min(max(Int((y / rowHeight).rounded()), 0), count)
    }

    /// Verandert het verplaatsen van rij `from` naar plaats `to` (zoals `List.onMove`) iets aan de volgorde?
    static func isMove(from: Int, to: Int) -> Bool {
        to != from && to != from + 1
    }

    /// Rij `from` naar plaats `to` (beide in rijen, zoals `List.onMove`) omgezet naar plaatsen in `entries`; nil als
    /// er niets verandert. Zo klopt verplaatsen ook als er een regel zonder rij tussen zit.
    static func entryMove(from: Int, to: Int, rows: [CommandListRow],
                          entries: [MenuEntry]) -> (source: Int, destination: Int)? {
        guard rows.indices.contains(from), isMove(from: from, to: to),
              let source = entries.firstIndex(of: rows[from].entry) else { return nil }
        let destination: Int
        if to < rows.count {
            guard let index = entries.firstIndex(of: rows[to].entry) else { return nil }
            destination = index
        } else {
            destination = entries.count
        }
        return (source, destination)
    }
}

extension CommandsModel {
    /// Verwijdert wat een rij toont: het commando (alleen eigen commando's), of de scheidingsrij uit de eigen lijst;
    /// een scheidingsrij met dezelfde id in de andere lijst blijft staan.
    func remove(_ row: CommandListRow) {
        switch row {
        case .command(let command): remove(command.id)
        case .divider(let axis, let id): removeDivider(axis, id: id)
        }
    }
}
