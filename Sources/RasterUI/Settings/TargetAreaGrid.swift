import RasterCore
import SwiftUI

/// Raster voor het doelgebied (Horizontal 24 × 12, Vertical 12 × 24) met breukbadges boven en links.
///
/// Vakjes van 14 pt met 2 pt tussenruimte (Horizontal 382 × 190), hoekradius 3; gekozen in de accentkleur, anders
/// `position`. De frame is precies het raster: de badges (breedte boven, hoogte links) liggen erbuiten als overlay.
/// Slepen kiest een rechthoek (`GridSelection.rect`); bij loslaten volgt `onChange`.
package struct TargetAreaGrid: View {
    let grid: GridSize
    let area: GridArea
    let onChange: (GridArea) -> Void

    /// Begin en huidige cel van een lopende sleep.
    @State private var drag: (start: GridCell, end: GridCell)?

    package init(grid: GridSize, area: GridArea, onChange: @escaping (GridArea) -> Void) {
        self.grid = grid
        self.area = area
        self.onChange = onChange
    }

    /// Vakje 14 pt, steek 16 pt.
    static let cell: CGFloat = 14
    static let pitch: CGFloat = 16

    /// Maat van het raster: Horizontal 382 × 190, Vertical 190 × 382.
    static func size(of grid: GridSize) -> CGSize {
        CGSize(width: pitch * CGFloat(grid.columns) - (pitch - cell), height: pitch * CGFloat(grid.rows) - (pitch - cell))
    }

    /// Het getoonde gebied: tijdens het slepen de rechthoek onder de muis, anders `area`.
    private var shown: GridArea {
        drag.map { GridArea(GridSelection.rect(from: $0.start, to: $0.end)) } ?? area
    }

    package var body: some View {
        let size = Self.size(of: grid)
        let shown = shown
        Canvas { context, _ in
            let shape = { (column: Int, row: Int) in
                Path(roundedRect: CGRect(x: CGFloat(column) * Self.pitch, y: CGFloat(row) * Self.pitch,
                                         width: Self.cell, height: Self.cell),
                     cornerRadius: 3, style: .continuous)
            }
            var selected = Path(), other = Path()
            for row in 0..<grid.rows {
                for column in 0..<grid.columns {
                    if shown.contains(GridCell(column: column, row: row)) {
                        selected.addPath(shape(column, row))
                    } else {
                        other.addPath(shape(column, row))
                    }
                }
            }
            context.fill(other, with: .color(RasterColor.position.color))
            context.fill(selected, with: .color(RasterColor.accent))
        }
        .frame(width: size.width, height: size.height)
        .overlay(alignment: .topLeading) { badges(for: shown) }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    drag = (cell(at: value.startLocation), cell(at: value.location))
                }
                .onEnded { value in
                    drag = nil
                    onChange(GridArea(GridSelection.rect(from: cell(at: value.startLocation), to: cell(at: value.location))))
                }
        )
        .accessibilityElement()
        .accessibilityLabel(L10n.commandContentTargetAreaTitle)
        .accessibilityValue(accessibilityValue(for: shown))
    }

    /// Badges met de breedte (boven, onderkant 7,5 pt boven het raster) en de hoogte (links, rechterkant 7,3 pt vóór het
    /// raster) van het gekozen deel, elk (vrijwel) gecentreerd op dat deel.
    @ViewBuilder private func badges(for area: GridArea) -> some View {
        if let bounds = area.bounds {
            // Gemeten maat: de badge boven staat op het midden van de cellen inclusief de tussenruimte erna
            // (½ op 96 i.p.v. 95), die links 1 pt boven het midden van het gekozen deel (94 i.p.v. 95).
            let midX = Self.pitch * (CGFloat(bounds.x) + CGFloat(bounds.width) / 2)
            let midY = Self.pitch * (CGFloat(bounds.y) + CGFloat(bounds.height) / 2) - (Self.pitch - Self.cell) / 2 - 1
            ZStack(alignment: .topLeading) {
                // Een lege frame van 0 × 0 als anker: de badge hangt er met zijn onderkant (boven) of rechterkant
                // (links) aan.
                Color.clear.frame(width: 0, height: 0)
                    .overlay(alignment: .bottom) { FractionBadge(text: GridFraction.text(bounds.width, of: grid.columns)) }
                    .position(x: midX, y: -7.5)
                Color.clear.frame(width: 0, height: 0)
                    .overlay(alignment: .trailing) { FractionBadge(text: GridFraction.text(bounds.height, of: grid.rows)) }
                    .position(x: -7.3, y: midY)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func cell(at point: CGPoint) -> GridCell {
        gridCell(at: point, pitch: Self.pitch, grid: grid)
    }

    private func accessibilityValue(for area: GridArea) -> String {
        guard let bounds = area.bounds else { return "" }
        return GridFraction.text(bounds.width, of: grid.columns) + ", " + GridFraction.text(bounds.height, of: grid.rows)
    }
}

/// Witte breuk op een accent-capsule: 16 pt hoog, hoekradius 4,5, ≈ 2,85 pt marge links en rechts (gemeten ½ 15,3 en
/// 1⁄1 14,8 pt breed).
struct FractionBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(GridFraction.badgeFont)
            .foregroundStyle(.white)
            .fixedSize()
            // Gemeten: de breuk staat 0,5 pt onder het midden van de badge.
            .offset(y: 0.5)
            .padding(.horizontal, 2.85)
            .frame(height: 16)
            .background(RoundedRectangle(cornerRadius: 4.5, style: .continuous).fill(RasterColor.accent))
    }
}
