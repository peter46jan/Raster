/// Ja/nee-voorkeuren van één domein; nil = sleutel ontbreekt (bij `set`: sleutel wissen).
public protocol BoolPreferences: AnyObject {
    func bool(_ key: String) -> Bool?
    func set(_ key: String, _ value: Bool?)
}

/// Zet het tegelen door slepen van macOS uit zolang Raster zelf snapt, en zet het daarna terug.
/// De oorspronkelijke waarden staan in de eigen voorkeuren van Raster (`original…`);
/// zo overleven ze een crash en worden ze bij een tweede keer uitzetten niet overschreven.
public struct TilingGuard {
    public static let keys = ["EnableTilingByEdgeDrag", "EnableTopTilingByEdgeDrag"]

    let system: BoolPreferences
    let own: BoolPreferences

    public init(system: BoolPreferences, own: BoolPreferences) {
        self.system = system
        self.own = own
    }

    /// Waar als macOS nu vensters tegelt bij slepen naar de rand (een ontbrekende sleutel betekent aan).
    public var isSystemTilingActive: Bool {
        Self.keys.contains { system.bool($0) ?? true }
    }

    public func disableSystemTiling() {
        for key in Self.keys {
            let originalKey = "original" + key
            if own.bool(originalKey) == nil { own.set(originalKey, system.bool(key) ?? true) }
            system.set(key, false)
        }
    }

    public func restoreSystemTiling() {
        for key in Self.keys {
            let originalKey = "original" + key
            guard let original = own.bool(originalKey) else { continue }
            system.set(key, original)
            own.set(originalKey, nil)
        }
    }
}
