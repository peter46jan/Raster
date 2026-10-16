import Testing
@testable import RasterCore

final class FakePreferences: BoolPreferences {
    var values: [String: Bool] = [:]
    func bool(_ key: String) -> Bool? { values[key] }
    func set(_ key: String, _ value: Bool?) { values[key] = value }
}

struct TilingGuardTests {
    let system = FakePreferences()
    let own = FakePreferences()
    var guardian: TilingGuard { TilingGuard(system: system, own: own) }

    @Test func disableStoresOriginalsAndTurnsTilingOff() {
        guardian.disableSystemTiling()
        #expect(system.values == ["EnableTilingByEdgeDrag": false, "EnableTopTilingByEdgeDrag": false])
        // Ontbrekende sleutel = standaard van macOS = aan.
        #expect(own.values == ["originalEnableTilingByEdgeDrag": true, "originalEnableTopTilingByEdgeDrag": true])
    }

    @Test func secondDisableKeepsFirstOriginals() {
        system.values = ["EnableTilingByEdgeDrag": true, "EnableTopTilingByEdgeDrag": false]
        guardian.disableSystemTiling()
        guardian.disableSystemTiling()
        #expect(own.values == ["originalEnableTilingByEdgeDrag": true, "originalEnableTopTilingByEdgeDrag": false])
    }

    @Test func restorePutsOriginalsBackAndForgetsThem() {
        system.values = ["EnableTilingByEdgeDrag": true, "EnableTopTilingByEdgeDrag": false]
        guardian.disableSystemTiling()
        guardian.restoreSystemTiling()
        #expect(system.values == ["EnableTilingByEdgeDrag": true, "EnableTopTilingByEdgeDrag": false])
        #expect(own.values.isEmpty)
    }

    @Test func restoreWithoutOriginalsChangesNothing() {
        system.values = ["EnableTilingByEdgeDrag": false]
        guardian.restoreSystemTiling()
        #expect(system.values == ["EnableTilingByEdgeDrag": false])
    }

    @Test func systemTilingIsActiveUnlessBothKeysAreOff() {
        #expect(guardian.isSystemTilingActive) // ontbrekend = aan (standaard van macOS)
        system.set("EnableTilingByEdgeDrag", false)
        #expect(guardian.isSystemTilingActive)
        system.set("EnableTopTilingByEdgeDrag", false)
        #expect(!guardian.isSystemTilingActive)
    }
}
