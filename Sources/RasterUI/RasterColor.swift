import AppKit
import SwiftUI

/// Het palet van Raster (sRGB, licht en donker). De hoofdkleur is een diep groenblauw (`brand`): daarin tekent de app
/// selectie, raster, badges en de iconen in de lijst. De neutrale tinten hebben een heel lichte koele zweem, zodat
/// ze bij de hoofdkleur passen.
package enum RasterColor: CaseIterable {
    case areaBackground, areaDot, areaDotSecondarySelect, areaDotSelect, areaPointSecondary
    case areaSegmentRemoveHover, areaSegmentRemovePrimary, areaSegmentRemoveSecondary, areaSegmentSelect
    case background, brand, border, control, divider, green, lightBackground, listBackground, listItemHover
    case position, red, shortcutField, sidebarItemHover, sidebarItemIcon, targetAreaBackground, targetAreaOutline
    case toolbar, welcomeText
    /// Vulling van de kaarten in beide panelen, net iets donkerder (licht) of lichter (donker) dan `background`.
    case card

    /// (rood, groen, blauw, alfa) in sRGB.
    typealias RGBA = (red: Double, green: Double, blue: Double, alpha: Double)

    /// Hoofdkleur: diep groenblauw. In donker iets lichter, zodat hij op de donkere vlakken even sterk oogt en wit
    /// erop leesbaar blijft.
    private static let brandLight: RGBA = (0.051, 0.478, 0.478, 1)   // #0D7A7A
    private static let brandDark: RGBA = (0.141, 0.592, 0.573, 1)    // #249792

    /// Waarden licht en donker.
    private var values: (light: RGBA, dark: RGBA) {
        switch self {
        case .areaBackground: (neutral(0.9), neutral(0.215))
        case .areaDot: (neutral(0.69), neutral(0.42))
        case .areaDotSecondarySelect: (neutral(0.69), neutral(0.19))
        case .areaDotSelect: (neutral(0.97), neutral(0.94))
        case .areaPointSecondary: (neutral(0.83), neutral(0.29))
        case .areaSegmentRemoveHover: (neutral(0.97), neutral(0.19))
        case .areaSegmentRemovePrimary: (neutral(0.97), neutral(0.94))
        case .areaSegmentRemoveSecondary: (neutral(0.69), neutral(0.19))
        case .areaSegmentSelect: (neutral(0.985), neutral(0.72))
        case .background: (neutral(0.96), neutral(0.16))
        case .brand: (Self.brandLight, Self.brandDark)
        case .border: (neutral(0.88), neutral(0.29))
        case .control: (neutral(0.7), neutral(0.7))
        case .divider: (neutral(0.82), neutral(0.33))
        case .green: ((0.153, 0.588, 0.341, 1), (0.243, 0.733, 0.447, 1))    // #279657 / #3EBB72
        case .lightBackground: (neutral(0.98), neutral(0.2))
        case .listBackground: (neutral(0.93), neutral(0.19))
        case .listItemHover: ((0, 0.12, 0.12, 0.06), (0.8, 1, 1, 0.07))
        case .position: (neutral(0.83), neutral(0.29))
        case .red: ((0.82, 0.235, 0.204, 1), (0.937, 0.396, 0.341, 1))       // #D13C34 / #EF6557
        case .shortcutField: (neutral(0.99), neutral(0.26))
        case .sidebarItemHover: ((1, 1, 1, 0.55), (1, 1, 1, 0.2))
        case .sidebarItemIcon: (neutral(0.97), neutral(0.97))
        case .targetAreaBackground: (withAlpha(Self.brandLight, 0.15), withAlpha(Self.brandDark, 0.2))
        case .targetAreaOutline: (withAlpha(Self.brandLight, 0.75), withAlpha(Self.brandDark, 0.8))
        case .toolbar: (neutral(0.98), neutral(0.13))
        case .welcomeText: (neutral(0.32), neutral(0.75))
        case .card: (neutral(0.945), neutral(0.185))
        }
    }

    /// Kleur die met het uiterlijk (licht of donker) van de view meewisselt.
    package var nsColor: NSColor {
        let (light, dark) = values
        return NSColor(name: nil) { appearance in
            let c = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: c.alpha)
        }
    }

    package var color: Color { Color(nsColor: nsColor) }

    /// Hoofdkleur voor AppKit (selectie, raster, badges, iconen in de lijst).
    package static var accentNSColor: NSColor { RasterColor.brand.nsColor }

    /// Hoofdkleur voor SwiftUI.
    package static var accent: Color { RasterColor.brand.color }
}

/// Neutraal grijs met een lichte koele (groenblauwe) zweem, zonder transparantie.
private func neutral(_ white: Double) -> RasterColor.RGBA { (white - 0.012, white - 0.002, white, 1) }

/// Dezelfde kleur met een andere alfa.
private func withAlpha(_ c: RasterColor.RGBA, _ alpha: Double) -> RasterColor.RGBA { (c.red, c.green, c.blue, alpha) }
