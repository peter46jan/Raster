import Foundation
import RasterCore

/// Ja/nee-voorkeuren van één domein (bijv. `com.apple.WindowManager`) via CFPreferences,
/// voor de huidige gebruiker en elke host — dezelfde plek die `defaults` leest.
public final class DomainPreferences: BoolPreferences {
    private let domain: CFString

    public init(domain: String) {
        self.domain = domain as CFString
    }

    public func bool(_ key: String) -> Bool? {
        CFPreferencesCopyAppValue(key as CFString, domain) as? Bool
    }

    public func set(_ key: String, _ value: Bool?) {
        CFPreferencesSetAppValue(key as CFString, value.map { NSNumber(value: $0) }, domain)
        CFPreferencesAppSynchronize(domain)
    }
}
