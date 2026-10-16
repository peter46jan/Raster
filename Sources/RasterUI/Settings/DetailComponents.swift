import AppKit
import CoreText
import RasterCore
import SwiftUI

// Gedeelde hulpjes voor de rasters en het sneltoetsveld in de detailkolom van Commands.

/// Vereenvoudigde breuk voor de badges boven en links van het doelgebied: 12 van 24 kolommen → 1/2, 12 van 12 → 1/1.
enum GridFraction {
    /// `count` van `total` cellen, vereenvoudigd. Een lege of ongeldige telling geeft 0/1.
    static func reduced(_ count: Int, of total: Int) -> (numerator: Int, denominator: Int) {
        guard count > 0, total > 0 else { return (0, 1) }
        let divisor = gcd(count, total)
        return (count / divisor, total / divisor)
    }

    /// Tekst voor de badge, bijv. "1/2"; het lettertype met diagonale breuken (`badgeFont`) maakt er "½" van.
    static func text(_ count: Int, of total: Int) -> String {
        let (numerator, denominator) = reduced(count, of: total)
        return "\(numerator)/\(denominator)"
    }

    /// SF 15 semibold, smal (condensed), met de OpenType-feature voor diagonale breuken. Gemeten: inkt van
    /// "½" 9 × 10,5 pt en van "1⁄1" 8 × 10,5 pt; dat is precies deze variant (9,1 en 8,0).
    static let badgeFont: Font = {
        let base = NSFont.systemFont(ofSize: 15, weight: .semibold, width: .condensed)
        let descriptor = base.fontDescriptor.addingAttributes([
            .featureSettings: [[
                NSFontDescriptor.FeatureKey.typeIdentifier: kFractionsType,
                NSFontDescriptor.FeatureKey.selectorIdentifier: kDiagonalFractionsSelector,
            ]],
        ])
        return Font(NSFont(descriptor: descriptor, size: 15) ?? base)
    }()

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        b == 0 ? a : gcd(b, a % b)
    }
}

extension GridArea {
    /// Omsluitende rechthoek van alle segmenten, of nil als het gebied leeg is.
    var bounds: GridRect? {
        guard let first = segments.first else { return nil }
        var minX = first.x, minY = first.y
        var maxX = first.x + first.width, maxY = first.y + first.height
        for segment in segments.dropFirst() {
            minX = min(minX, segment.x)
            minY = min(minY, segment.y)
            maxX = max(maxX, segment.x + segment.width)
            maxY = max(maxY, segment.y + segment.height)
        }
        return GridRect(minX, minY, maxX - minX, maxY - minY)
    }

    /// Of een segment deze cel bevat.
    func contains(_ cell: GridCell) -> Bool {
        segments.contains { $0.contains(column: cell.column, row: cell.row) }
    }
}

/// De cel onder `point` op een raster met een steek van `pitch` pt, begrensd tot het raster (slepen buiten het raster
/// blijft op de rand).
func gridCell(at point: CGPoint, pitch: CGFloat, grid: GridSize) -> GridCell {
    GridCell(column: min(max(Int((point.x / pitch).rounded(.down)), 0), grid.columns - 1),
             row: min(max(Int((point.y / pitch).rounded(.down)), 0), grid.rows - 1))
}

/// Of `point` binnen een raster van `grid` cellen met steek `pitch` valt.
func gridContains(_ point: CGPoint, pitch: CGFloat, grid: GridSize) -> Bool {
    point.x >= 0 && point.y >= 0 && point.x < pitch * CGFloat(grid.columns) && point.y < pitch * CGFloat(grid.rows)
}

extension View {
    /// Uitgeschakeld: vaag en niet te bedienen.
    func dimmedWhenDisabled(_ isEnabled: Bool) -> some View {
        opacity(isEnabled ? 1 : 0.5)
            .allowsHitTesting(isEnabled)
            .disabled(!isEnabled)
    }
}
