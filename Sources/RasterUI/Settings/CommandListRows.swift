import AppKit
import RasterCore
import SwiftUI
import UniformTypeIdentifiers

// Onderdelen van de lijstkolom in Commands: sectiekop, rijen en de knoppen erin. Maten in pt, vanaf de linkerkant van de lijstkolom).

/// Sectiekop "Horizontal" / "Vertical": SF 15 semibold op x 24, basislijn 30,5, 52 pt hoog. Rechts de chevron en
/// de plusknop (frames 20 × 20 naast elkaar, rechtermarge 22), midden op 25 pt: het cap-midden van de titel.
struct CommandListSectionHeader: View {
    let title: String
    let isExpanded: Bool
    let isReadOnly: Bool
    let toggle: () -> Void
    let addCommand: () -> Void
    let addDivider: () -> Void

    @State private var isAdding = false

    static let height: CGFloat = 52

    var body: some View {
        BaselineStack(baselines: [30.5], bottom: Self.height - 30.5) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(nsColor: .labelColor))
                .lineLimit(1)
        }
        .padding(.leading, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.height)
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 0) {
                ChevronButton(angle: CommandListLogic.chevronAngle(isExpanded: isExpanded),
                              tooltip: CommandListLogic.chevronTooltip(isExpanded: isExpanded), action: toggle)
                CircleIconButton(image: RasterIcons.add, tooltip: L10n.commandListSectionHeaderAddButtonTooltip) {
                    isAdding = true
                }
                .disabled(isReadOnly)
                .popover(isPresented: $isAdding, arrowEdge: .bottom) {
                    AddPopover(
                        addCommand: { isAdding = false; addCommand() },
                        addDivider: { isAdding = false; addDivider() })
                }
            }
            .padding(.top, 15)
            .padding(.trailing, 22)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }
}

/// De chevron van een sectiekop: ingeklapt wijst hij naar rechts, uitgeklapt omlaag. De draaiing animeert: SwiftUI
/// geeft tussenwaarden van `angle` door en de knop tekent het icoon telkens opnieuw gedraaid (een `rotationEffect`
/// op de AppKit-afbeelding zou offscreen niet meegetekend worden).
private struct ChevronButton: View, Animatable {
    var angle: Double
    let tooltip: String
    let action: () -> Void

    nonisolated var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        CircleIconButton(image: Self.chevron(rotatedBy: angle), tooltip: tooltip, action: action)
    }

    /// `RasterIcons.chevron` gedraaid met de klok mee om het midden.
    private static func chevron(rotatedBy degrees: Double) -> NSImage {
        let base = RasterIcons.chevron
        guard degrees != 0 else { return base }
        if let cached = cache[degrees] { return cached }
        let source = base
        let image = NSImage(size: base.size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.translateBy(x: rect.midX, y: rect.midY)
            // y omhoog: een negatieve hoek draait met de klok mee.
            context.rotate(by: -degrees * .pi / 180)
            context.translateBy(x: -rect.midX, y: -rect.midY)
            source.draw(in: rect)
            return true
        }
        image.isTemplate = true
        if cache.count > 200 { cache.removeAll() }
        cache[degrees] = image
        return image
    }

    @MainActor private static var cache: [Double: NSImage] = [:]
}

/// Popover van de plusknop: "Command" en "Divider".
private struct AddPopover: View {
    let addCommand: () -> Void
    let addDivider: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PopoverItem(title: L10n.commandListSectionHeaderPopoverItemTitleCommand, action: addCommand)
            PopoverItem(title: L10n.commandListSectionHeaderPopoverItemTitleDivider, action: addDivider)
        }
        .padding(5)
    }
}

/// Regel in de popover, als een menu-item: SF 13, bij hover gemarkeerd in de accentkleur.
private struct PopoverItem: View {
    let title: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(isHovered ? Color.white : Color(nsColor: .labelColor))
                .padding(.horizontal, 10)
                .frame(minWidth: 100, minHeight: 24, alignment: .leading)
                .background(isHovered ? RasterColor.accent : .clear,
                            in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

/// Eén rij van 30 pt: een commando (icoon 25 × 15 op x 25, naam SF 13 op x 60 met basislijn 20) of een
/// scheidingsrij (capsule 25 × 4 op x 25, midden in de rij). Achtergrond van selectie en hover: x 15 … 260,
/// 28 hoog (1 pt inset), hoekradius 5. Bij hover rechts de rijknoppen.
struct CommandListRowView: View {
    let row: CommandListRow
    let isSelected: Bool
    let buttons: [CommandRowButton]
    let onTap: () -> Void
    let onButton: (CommandRowButton.Kind) -> Void

    @Environment(\.controlActiveState) private var activeState
    @State private var isHovered: Bool

    init(row: CommandListRow, isSelected: Bool, buttons: [CommandRowButton], isHovered: Bool = false,
         onTap: @escaping () -> Void, onButton: @escaping (CommandRowButton.Kind) -> Void) {
        self.row = row
        self.isSelected = isSelected
        self.buttons = buttons
        self.onTap = onTap
        self.onButton = onButton
        self._isHovered = State(initialValue: isHovered)
    }

    /// Zijmarge van de achtergrond van selectie en hover.
    private static let inset: CGFloat = 15
    /// Rechtermarge van de rijknoppen, gelijk met de knoppen van de sectiekop.
    private static let buttonsTrailing: CGFloat = 22

    var body: some View {
        content
            .frame(width: SettingsMetrics.listWidth, height: CommandListLogic.rowHeight, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(background)
                    .padding(.horizontal, Self.inset)
                    .padding(.vertical, 1)
            }
            .overlay(alignment: .trailing) {
                if isHovered {
                    HStack(spacing: 0) {
                        ForEach(buttons) { button in
                            RowButton(button: button, onSelection: isSelected) { onButton(button.kind) }
                        }
                    }
                    .padding(.trailing, Self.buttonsTrailing)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .onHover { isHovered = $0 }
            // VoiceOver: de rij is één knop (kiezen); de rijknoppen, die alleen bij hover zichtbaar zijn, zijn acties.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityTitle)
            .accessibilityAddTraits(accessibilityTraits)
            .accessibilityAction { onTap() }
            .accessibilityActions {
                ForEach(buttons.filter(\.isEnabled)) { button in
                    Button(button.tooltip) { onButton(button.kind) }
                }
            }
    }

    private var accessibilityTraits: AccessibilityTraits {
        var traits: AccessibilityTraits = []
        if row.command != nil { traits.formUnion(.isButton) }
        if isSelected { traits.formUnion(.isSelected) }
        return traits
    }

    @ViewBuilder private var content: some View {
        switch row {
        case .command(let command):
            BaselineStack(baselines: [20], bottom: CommandListLogic.rowHeight - 20) {
                Text(command.name)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? Color.white : Color(nsColor: .labelColor))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.leading, 60)
            // De naam loopt niet onder de rijknoppen door.
            .padding(.trailing, isHovered ? Self.buttonsTrailing + CGFloat(buttons.count) * 20 : Self.inset)
            .overlay(alignment: .leading) {
                // Vertical-iconen (15 × 25) staan gecentreerd in dezelfde 25 pt.
                TemplateImage(image: RasterIcons.command(command), color: iconColor)
                    .frame(width: 25, height: CommandListLogic.rowHeight)
                    .padding(.leading, 25)
                    .accessibilityHidden(true)
            }
        case .divider:
            Capsule()
                .fill(RasterColor.divider.color)
                .frame(width: 25, height: 4)
                .padding(.leading, 25)
                .accessibilityHidden(true)
        }
    }

    private var accessibilityTitle: String {
        switch row {
        case .command(let command): command.name
        case .divider: L10n.commandDefaultDivider
        }
    }

    private var background: Color {
        if isSelected { return CommandListColors.selection(active: activeState != .inactive) }
        return isHovered ? RasterColor.listItemHover.color : .clear
    }

    /// Normaal de accentkleur (gebied vol, achtergrond 25 %), geselecteerd wit 93 % (gemeten 239 … 245 op accent).
    private var iconColor: NSColor {
        isSelected ? NSColor(white: 1, alpha: 0.93) : RasterColor.accentNSColor
    }
}

/// Rijknop van 20 × 20 (vierkant of cirkel van 16 pt): `secondaryLabelColor`, uitgeschakeld `tertiaryLabelColor`;
/// op de selectie wit (uitgeschakeld half doorzichtig).
private struct RowButton: View {
    let button: CommandRowButton
    let onSelection: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            TemplateImage(image: button.image, color: color)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!button.isEnabled)
        .help(button.tooltip)
        .accessibilityLabel(button.tooltip)
    }

    private var color: NSColor {
        if onSelection { return NSColor(white: 1, alpha: button.isEnabled ? 1 : 0.5) }
        return button.isEnabled ? .secondaryLabelColor : .tertiaryLabelColor
    }
}

/// Kleuren van de lijst die afhangen van het venster.
enum CommandListColors {
    /// Selectie: de accentkleur; in een inactief venster grijs zoals de zijbalk (sRGB 164, donker geschat).
    static func selection(active: Bool) -> Color {
        active ? RasterColor.accent : Color(nsColor: inactiveSelection)
    }

    private static let inactiveSelection = NSColor(name: nil) { appearance in
        NSColor(white: appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? 0.4 : 164 / 255, alpha: 1)
    }
}

/// Invoeglijn tijdens slepen: 2 pt in de accentkleur over de breedte van de selectie, met een open rondje links,
/// zoals een AppKit-tabel.
struct CommandListInsertionLine: View {
    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .strokeBorder(RasterColor.accent, lineWidth: 2)
                .frame(width: 7, height: 7)
            Rectangle()
                .fill(RasterColor.accent)
                .frame(height: 2)
        }
        .frame(height: 7)
        .padding(.leading, 12)
        .padding(.trailing, 15)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension UTType {
    /// Een gesleepte rij van de lijst; alleen binnen dit proces zichtbaar, zodat de id niet in andere apps belandt.
    static let rasterCommandListRow = UTType(exportedAs: "nl.jimlindenburg.raster.command-list-row")
}

/// Wat er gesleept wordt: de rij met id `rowID` uit de lijst van `axis`. Alleen voor de invoeglijn; verplaatsen
/// gebruikt de id die met de sleep zelf meekomt.
struct CommandListDrag: Equatable {
    let axis: CommandAxis
    let rowID: String

    /// Typen die een sectie aanneemt: precies het type dat `itemProvider(for:)` aanbiedt.
    static let types: [UTType] = [.rasterCommandListRow]

    /// Sleepgegevens van een rij: de id als eigen type, alleen voor dit proces.
    static func itemProvider(for rowID: String) -> NSItemProvider {
        let provider = NSItemProvider()
        let data = Data(rowID.utf8)
        provider.registerDataRepresentation(forTypeIdentifier: UTType.rasterCommandListRow.identifier,
                                            visibility: .ownProcess) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }
}

/// Ontvangt een gesleepte rij in de rijen van één sectie. Alleen eigen sleeps (het eigen type) tellen; `move`
/// zoekt de rij op id in de huidige lijst en doet niets als die er niet (meer) in staat, bijvoorbeeld een rij uit
/// de andere sectie. `location` is gemeten vanaf de bovenkant van de eerste rij.
struct CommandListDropDelegate: DropDelegate {
    let axis: CommandAxis
    let count: Int
    let isReadOnly: Bool
    @Binding var drag: CommandListDrag?
    @Binding var target: Int?
    let move: @MainActor (_ rowID: String, _ to: Int) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        guard !isReadOnly, info.hasItemsConforming(to: CommandListDrag.types) else { return false }
        // Een sleep uit de andere sectie hoort hier niet; zonder `drag` beslist `move` (die zoekt de rij op id).
        return drag.map { $0.axis == axis } ?? true
    }

    func dropEntered(info: DropInfo) {
        update(info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard validateDrop(info: info) else { return DropProposal(operation: .forbidden) }
        update(info)
        return DropProposal(operation: .move)
    }

    /// Alleen de invoeglijn verdwijnt: `drag` blijft staan tot `performDrop` of de volgende `onDrag`, zodat de
    /// andere sectie een sleep van hier blijft weigeren.
    func dropExited(info: DropInfo) {
        target = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            drag = nil
            target = nil
        }
        guard validateDrop(info: info),
              let provider = info.itemProviders(for: CommandListDrag.types).first else { return false }
        let destination = CommandListLogic.insertionIndex(y: info.location.y, count: count)
        let move = self.move
        _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.rasterCommandListRow.identifier) { data, _ in
            guard let data, let rowID = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in move(rowID, destination) }
        }
        return true
    }

    private func update(_ info: DropInfo) {
        guard validateDrop(info: info) else { return }
        target = CommandListLogic.insertionIndex(y: info.location.y, count: count)
    }
}
