import Foundation

/// Weergave van het menu bij de groene knop (Standard, Compact, Horizontal).
public enum ZoomMenuStyle: String, CaseIterable, Sendable {
    case standard, compact, horizontal
}

/// Toets die het menu van Raster bij de groene knop onderdrukt, zodat dat van macOS verschijnt.
public enum SystemMenuModifier: String, CaseIterable, Sendable {
    case control, command
}

/// Kleur van het voorbeeld tijdens slepen (Automatic, Light, Dark, Inverse, Custom).
public enum PreviewAppearance: String, CaseIterable, Sendable {
    case automatic, light, dark, inverse, custom
}

/// Kleur van de getoonde sleepzones.
public enum ZoneAppearance: String, CaseIterable, Sendable {
    case automatic, custom
}

/// Toegestane waarden van de voorkeuren; de enige bron voor deze bereiken.
public enum PreferenceRange {
    /// Marge rond vensters, in punten.
    public static let margin = 0...50
    /// Wachttijd voor het menu bij de groene knop, in seconden.
    public static let hoverDelay = 0.1...2.0
    /// Breedte van de randzone bij slepen, in punten.
    public static let edgeWidth = 1...40
    /// Grootte van de binnenzones, als factor.
    public static let innerScale = 0.5...2.0
    /// Breedte van de omlijning van het voorbeeld, in punten.
    public static let outlineWidth = 0.0...5.0
}

extension Comparable {
    public func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

/// sRGB-kleur zonder AppKit, bewaard als "#RRGGBB".
public struct RGBColor: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red.clamped(to: 0...1)
        self.green = green.clamped(to: 0...1)
        self.blue = blue.clamped(to: 0...1)
    }

    public init?(hex: String) {
        var text = Substring(hex)
        if text.hasPrefix("#") { text = text.dropFirst() }
        guard text.count == 6, text.allSatisfy(\.isHexDigit), let value = UInt32(text, radix: 16) else { return nil }
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }

    public var hex: String {
        func byte(_ component: Double) -> Int { Int((component * 255).rounded()) }
        return "#" + [red, green, blue].map { String(format: "%02X", byte($0)) }.joined()
    }

    /// Systeemblauw, de standaard voor eigen kleuren.
    public static let blue = RGBColor(red: 0, green: 122.0 / 255, blue: 1)
}
