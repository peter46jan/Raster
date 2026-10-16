import AppKit
import RasterCore
import SwiftUI

/// Stippenraster met de sleepzones van dit commando (accent) en die van andere commando's (grijze capsules).
///
/// Cellen van 16 pt (Horizontal 384 × 192, Vertical 192 × 384) op `areaBackground` met hoekradius 8; in het midden van
/// elke cel een stip van 4 pt in `areaDot`. Zones zijn capsules die precies hun cellen beslaan (radius 8): van andere
/// commando's in `position` met stippen in `areaDotSecondarySelect` (in licht gelijk aan `areaDot`), de eigen in de
/// accentkleur met stippen in `areaDotSelect`.
///
/// Slepen over cellen voegt een zone toe (`onChange`). Op een zone verschijnt bij hover het kruisje
/// (`RasterIcons.removeArea`, alleen het kruisje heeft de tooltip "Remove"); een klik op een eigen zone haalt hem weg
/// (`onChange`). Een klik op een grijze zone vraagt eerst, als blad aan het eigen venster, of hij bij dat andere
/// commando weg mag ("Another Command's Area") en roept dan `onRemoveOther` aan. Met `isEnabled` uit is het raster
/// vaag en niet te bedienen.
package struct ActivationAreaGrid: View {
    /// Sleepzones van een ander commando in dezelfde lijst.
    package struct OtherZones: Identifiable, Equatable {
        package let id: String
        package let name: String
        package let area: GridArea

        package init(id: String, name: String, area: GridArea) {
            self.id = id
            self.name = name
            self.area = area
        }
    }

    /// Wat er onder een cel ligt.
    enum Hit: Equatable {
        /// Een eigen zone (index in `zones.segments`).
        case own(Int)
        /// Een zone van een ander commando (index in `area.segments` van dat commando).
        case other(OtherZones, Int)
        case empty
    }

    let grid: GridSize
    let zones: GridArea
    let others: [OtherZones]
    let isEnabled: Bool
    let onChange: (GridArea) -> Void
    let onRemoveOther: (OtherZones, GridCell) -> Void

    /// Begin en huidige cel van een lopende sleep, en wat er bij het begin onder de muis lag.
    @State private var drag: (start: GridCell, end: GridCell, startHit: Hit)?
    /// Zone onder de muis (zonder te slepen).
    @State private var hover: Hit = .empty
    /// Alleen voor `raster-render`: doen alsof de muis boven deze cel staat.
    @Environment(\.activationAreaPreviewHover) private var previewHover
    /// Het venster van het raster: daaraan hangt de vraag "Another Command's Area" als blad.
    @State private var window = WindowReference()

    package init(grid: GridSize, zones: GridArea, others: [OtherZones], isEnabled: Bool,
                 onChange: @escaping (GridArea) -> Void,
                 onRemoveOther: @escaping (OtherZones, GridCell) -> Void) {
        self.grid = grid
        self.zones = zones
        self.others = others
        self.isEnabled = isEnabled
        self.onChange = onChange
        self.onRemoveOther = onRemoveOther
    }

    /// Cel van 16 pt, stip van 4 pt.
    static let pitch: CGFloat = 16
    static let dot: CGFloat = 4

    /// Maat van het raster: Horizontal 384 × 192, Vertical 192 × 384.
    static func size(of grid: GridSize) -> CGSize {
        CGSize(width: pitch * CGFloat(grid.columns), height: pitch * CGFloat(grid.rows))
    }

    // MARK: - Beslissingen (puur, getest)

    /// Sleepzones van de andere commando's in `commands` (dezelfde lijst als `command`) die meetellen: met de
    /// schakelaar aan en minstens één zone.
    package static func others(for command: Command, in commands: [Command]) -> [OtherZones] {
        commands.compactMap { other in
            guard other.id != command.id, !other.activeDragZones.segments.isEmpty else { return nil }
            return OtherZones(id: other.id, name: other.name, area: other.activeDragZones)
        }
    }

    /// Wat er onder `cell` ligt: eerst de eigen zones, dan die van andere commando's.
    static func hit(_ cell: GridCell, zones: GridArea, others: [OtherZones]) -> Hit {
        if let index = zones.segments.firstIndex(where: { $0.contains(column: cell.column, row: cell.row) }) {
            return .own(index)
        }
        for other in others {
            if let index = other.area.segments.firstIndex(where: { $0.contains(column: cell.column, row: cell.row) }) {
                return .other(other, index)
            }
        }
        return .empty
    }

    /// De eigen zones met `rect` erbij; eigen zones die er helemaal in vallen, gaan op in de nieuwe.
    static func adding(_ rect: GridRect, to zones: GridArea) -> GridArea {
        var segments = zones.segments.filter { !rect.covers($0) }
        segments.append(rect)
        return GridArea(segments: segments)
    }

    /// De eigen zones zonder het segment op `index`.
    static func removing(_ index: Int, from zones: GridArea) -> GridArea {
        var segments = zones.segments
        if segments.indices.contains(index) { segments.remove(at: index) }
        return GridArea(segments: segments)
    }

    /// Wat er gebeurt als de muis bij `end` loslaat na indrukken bij `start`.
    enum Action: Equatable {
        case change(GridArea)
        case askRemoveOther(OtherZones, GridCell)
    }

    static func action(from start: GridCell, to end: GridCell, zones: GridArea, others: [OtherZones]) -> Action {
        if start == end {
            switch hit(start, zones: zones, others: others) {
            case .own(let index): return .change(removing(index, from: zones))
            case .other(let other, _): return .askRemoveOther(other, start)
            case .empty: break
            }
        }
        return .change(adding(GridSelection.rect(from: start, to: end), to: zones))
    }

    // MARK: - Weergave

    /// De rechthoek die een lopende sleep zou toevoegen; geen bij een klik op een bestaande zone.
    private var preview: GridRect? {
        guard let drag else { return nil }
        if drag.start == drag.end, drag.startHit != .empty { return nil }
        return GridSelection.rect(from: drag.start, to: drag.end)
    }

    /// Het segment waarop het kruisje staat, met de kleur van het kruisje.
    private var hovered: (rect: GridRect, color: NSColor)? {
        guard isEnabled, drag == nil else { return nil }
        let hover = previewHover.map { Self.hit($0, zones: zones, others: others) } ?? hover
        switch hover {
        case .own(let index) where zones.segments.indices.contains(index):
            return (zones.segments[index], RasterColor.areaSegmentRemovePrimary.nsColor)
        case .other(let other, let index) where other.area.segments.indices.contains(index):
            return (other.area.segments[index], RasterColor.areaSegmentRemoveSecondary.nsColor)
        default:
            return nil
        }
    }

    package var body: some View {
        let size = Self.size(of: grid)
        let preview = preview
        let hovered = hovered
        Canvas { context, _ in
            let pitch = Self.pitch
            let frame = { (r: GridRect) in
                CGRect(x: CGFloat(r.x) * pitch, y: CGFloat(r.y) * pitch,
                       width: CGFloat(r.width) * pitch, height: CGFloat(r.height) * pitch)
            }
            let capsule = { (r: GridRect) in Path(roundedRect: frame(r), cornerRadius: pitch / 2) }
            context.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 8),
                         with: .color(RasterColor.areaBackground.color))
            var gray = Path(), own = Path()
            for other in others {
                for segment in other.area.segments { gray.addPath(capsule(segment)) }
            }
            for segment in zones.segments { own.addPath(capsule(segment)) }
            if let preview { own.addPath(capsule(preview)) }
            context.fill(gray, with: .color(RasterColor.position.color))
            context.fill(own, with: .color(RasterColor.accent))

            var dots = Path(), otherDots = Path(), selectedDots = Path()
            for row in 0..<grid.rows {
                for column in 0..<grid.columns {
                    // Op het segment met het kruisje geen stippen.
                    if let hovered, hovered.rect.contains(column: column, row: row) { continue }
                    let center = CGPoint(x: (CGFloat(column) + 0.5) * pitch, y: (CGFloat(row) + 0.5) * pitch)
                    let dot = Path(ellipseIn: CGRect(x: center.x - Self.dot / 2, y: center.y - Self.dot / 2,
                                                     width: Self.dot, height: Self.dot))
                    let cell = GridCell(column: column, row: row)
                    if zones.contains(cell) || preview?.contains(column: column, row: row) == true {
                        selectedDots.addPath(dot)
                    } else if others.contains(where: { $0.area.contains(cell) }) {
                        otherDots.addPath(dot)
                    } else {
                        dots.addPath(dot)
                    }
                }
            }
            context.fill(dots, with: .color(RasterColor.areaDot.color))
            context.fill(otherDots, with: .color(RasterColor.areaDotSecondarySelect.color))
            context.fill(selectedDots, with: .color(RasterColor.areaDotSelect.color))
        }
        .frame(width: size.width, height: size.height)
        .background(HostWindowReader(reference: window))
        .overlay(alignment: .topLeading) {
            if let hovered {
                // Het kruisje zelf vangt geen klikken (die gaan naar het raster); een lege vlakte eronder draagt de
                // tooltip, zodat alleen het kruisje "Remove" toont.
                Color.clear
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
                    .help(L10n.areaGridSegmentRemoveTooltip)
                    .overlay {
                        TemplateImage(image: RasterIcons.removeArea, color: hovered.color)
                            .allowsHitTesting(false)
                    }
                    .position(x: (CGFloat(hovered.rect.x) + CGFloat(hovered.rect.width) / 2) * Self.pitch,
                              y: (CGFloat(hovered.rect.y) + CGFloat(hovered.rect.height) / 2) * Self.pitch)
            }
        }
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let location) where gridContains(location, pitch: Self.pitch, grid: grid):
                let next = Self.hit(cell(at: location), zones: zones, others: others)
                if next != hover { hover = next }
            default:
                if hover != .empty { hover = .empty }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let start = cell(at: value.startLocation)
                    drag = (start, cell(at: value.location),
                            drag?.startHit ?? Self.hit(start, zones: zones, others: others))
                }
                .onEnded { value in
                    drag = nil
                    let start = cell(at: value.startLocation), end = cell(at: value.location)
                    switch Self.action(from: start, to: end, zones: zones, others: others) {
                    case .change(let area):
                        hover = Self.hit(end, zones: area, others: others)
                        onChange(area)
                    case .askRemoveOther(let other, let cell):
                        askRemove(other, at: cell)
                    }
                }
        )
        .dimmedWhenDisabled(isEnabled)
        .accessibilityElement()
        .accessibilityLabel(L10n.commandContentActivationAreaTitle)
    }

    private func cell(at point: CGPoint) -> GridCell {
        gridCell(at: point, pitch: Self.pitch, grid: grid)
    }

    /// "Another Command's Area": bij Remove gaat de zone bij het andere commando weg. Als blad op het venster.
    private func askRemove(_ other: OtherZones, at cell: GridCell) {
        let alert = NSAlert()
        alert.messageText = L10n.areaGridSegmentRemoveSheetTitle
        alert.informativeText = L10n.areaGridSegmentRemoveSheetSubtitle
        alert.addButton(withTitle: L10n.areaGridSegmentRemoveSheetPrimaryTitle)
        alert.addButton(withTitle: L10n.coreSheetButtonCancel)
        let onRemoveOther = onRemoveOther
        if let window = window.window, window.isVisible {
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn { onRemoveOther(other, cell) }
            }
        } else if alert.runModal() == .alertFirstButtonReturn {
            onRemoveOther(other, cell)
        }
    }
}

extension EnvironmentValues {
    /// Alleen voor `raster-render`: de cel waarboven `ActivationAreaGrid` de muis laat zien (hover-weergave).
    @Entry package var activationAreaPreviewHover: GridCell? = nil
}

extension GridRect {
    /// Of `other` helemaal binnen deze rechthoek valt.
    func covers(_ other: GridRect) -> Bool {
        other.x >= x && other.y >= y && other.x + other.width <= x + width && other.y + other.height <= y + height
    }
}
