import Foundation

// Waarden naast de steppers in Preferences ("80 %", "8 pt", "0.3 s"). Ze worden samengesteld,
// dus de eenheden staan hier en niet in `Strings.swift`.
extension L10n {
    /// Punten: "6 pt", "1.5 pt" (hoogstens één decimaal).
    static func points(_ value: Double) -> String { decimal(value, digits: 0...1) + " pt" }
    static func points(_ value: Int) -> String { "\(value) pt" }
    /// Factor als percentage: 0,8 → "80 %".
    static func percent(_ factor: Double) -> String { "\(Int((factor * 100).rounded())) %" }
    /// Seconden met één decimaal: "0.3 s".
    static func seconds(_ value: Double) -> String { decimal(value, digits: 1...1) + " s" }
}

/// Getal met een punt als decimaalteken, zoals in de Engelse interface ("0.3").
func decimal(_ value: Double, digits: ClosedRange<Int>) -> String {
    value.formatted(.number.precision(.fractionLength(digits)).locale(Locale(identifier: "en_US_POSIX")))
}
