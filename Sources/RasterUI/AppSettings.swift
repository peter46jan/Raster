import Foundation
import RasterCore
import Observation

/// Opslag van `AppSettings`. De app gebruikt `UserDefaults` (`.standard`); tests en `raster-render` gebruiken
/// `InMemorySettingsStorage`, zodat er nooit een voorkeurenbestand in ~/Library/Preferences ontstaat.
package protocol SettingsStorage: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
    func string(forKey key: String) -> String?
    func stringArray(forKey key: String) -> [String]?
    func bool(forKey key: String) -> Bool
}

/// `UserDefaults` heeft alle methoden al; het gedrag in de app blijft precies hetzelfde.
extension UserDefaults: SettingsStorage {}

/// Voorkeuren alleen in het geheugen, voor tests en `raster-render`; schrijft niets naar schijf.
package final class InMemorySettingsStorage: SettingsStorage {
    private var values: [String: Any]

    package init(_ values: [String: Any] = [:]) {
        self.values = values
    }

    package func object(forKey key: String) -> Any? { values[key] }
    package func set(_ value: Any?, forKey key: String) { values[key] = value }
    package func removeObject(forKey key: String) { values[key] = nil }
    package func string(forKey key: String) -> String? { values[key] as? String }
    package func stringArray(forKey key: String) -> [String]? { values[key] as? [String] }
    package func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
}

/// Voorkeuren, bewaard in `SettingsStorage` (in de app `UserDefaults.standard`). Views wijzigen ze alleen via
/// `set(_:_:)`; daarna volgt `onChange`.
@MainActor
@Observable
package final class AppSettings {
    private enum Key {
        static let zoomButtonMenu = "zoomButtonMenu"
        static let systemMenuModifier = "systemMenuModifier"
        static let zoomHoverDelay = "zoomHoverDelay"
        static let zoomMenuStyle = "zoomMenuStyle"
        static let excludedApps = "excludedApps"
        static let margin = "margin"
        static let fitTightly = "fitTightly"
        static let restoreOriginalSize = "restoreToOriginalSize"
        static let highlightZones = "highlightZones"
        static let edgeWidth = "activationAreaEdgeWidth"
        static let innerScale = "activationAreaScale"
        static let zoneAppearance = "zoneAppearance"
        static let zoneColor = "zoneColor"
        static let zoneOutline = "zoneOutline"
        static let previewAppearance = "previewAppearance"
        static let previewColor = "previewColor"
        static let previewOutline = "previewOutline"
        static let hideMenuBarIcon = "hideMenuBarIcon"

        static let tilingPromptAnswered = "tilingPromptAnswered"
        static let welcomeShown = "welcomeShown"
        static let loginPromptShown = "loginPromptShown"

        /// Alle voorkeuren die `resetPreferences` wist (niet de eenmalige vragen). Zonder `excludedApps`: de lijst met
        /// genegeerde apps hoort bij dezelfde categorie als `lastMigratedVersion` en de pulse-vlaggen, die geen enkele
        /// "Restore"-keuze terugzet.
        static let preferences = [
            zoomButtonMenu, systemMenuModifier, zoomHoverDelay, zoomMenuStyle, margin, fitTightly,
            restoreOriginalSize, highlightZones, edgeWidth, innerScale, zoneAppearance, zoneColor, zoneOutline,
            previewAppearance, previewColor, previewOutline, hideMenuBarIcon,
        ]
    }

    @ObservationIgnored private let defaults: any SettingsStorage
    @ObservationIgnored var onChange: (() -> Void)?

    var zoomButtonMenu = true
    var systemMenuModifier = SystemMenuModifier.control
    var zoomHoverDelay = 0.3
    var zoomMenuStyle = ZoomMenuStyle.standard
    var excludedBundleIDs: [String] = []
    var margin = 0
    var fitTightly = false
    var restoreOriginalSize = true
    var highlightZones = false
    var edgeWidth = 6
    var innerScale = 1.0
    var zoneAppearance = ZoneAppearance.automatic
    var zoneColor = RGBColor.blue
    var zoneOutline = 1.0
    var previewAppearance = PreviewAppearance.automatic
    var previewColor = RGBColor.blue
    var previewOutline = 1.0
    var hideMenuBarIcon = false

    private(set) var tilingPromptAnswered = false
    private(set) var welcomeShown = false
    private(set) var loginPromptShown = false

    package init(storage defaults: any SettingsStorage = UserDefaults.standard) {
        self.defaults = defaults
        // De oude instelling "Alleen met ⌃" (fase 4) bestaat niet meer: het menu komt nu zonder toets.
        defaults.removeObject(forKey: "zoomButtonNeedsControl")
        load()
        tilingPromptAnswered = defaults.bool(forKey: Key.tilingPromptAnswered)
        welcomeShown = defaults.bool(forKey: Key.welcomeShown)
        loginPromptShown = defaults.bool(forKey: Key.loginPromptShown)
    }

    /// Wijzigt één voorkeur, bewaart en meldt. Opnieuw inlezen zet een waarde buiten het bereik terug binnen het bereik.
    func set<Value>(_ keyPath: ReferenceWritableKeyPath<AppSettings, Value>, _ value: Value) {
        self[keyPath: keyPath] = value
        save()
        load()
        onChange?()
    }

    /// Alle voorkeuren terug naar de standaard (niet de eenmalige vragen en niet de genegeerde apps).
    func resetPreferences() {
        for key in Key.preferences { defaults.removeObject(forKey: key) }
        load()
        onChange?()
    }

    func isExcluded(_ bundleID: String) -> Bool {
        excludedBundleIDs.contains(bundleID)
    }

    func addExcluded(_ bundleID: String) {
        guard !bundleID.isEmpty, bundleID != Bundle.main.bundleIdentifier, !isExcluded(bundleID) else { return }
        set(\.excludedBundleIDs, excludedBundleIDs + [bundleID])
    }

    func removeExcluded(_ bundleID: String) {
        guard isExcluded(bundleID) else { return }
        set(\.excludedBundleIDs, excludedBundleIDs.filter { $0 != bundleID })
    }

    func markTilingPromptAnswered() {
        tilingPromptAnswered = true
        defaults.set(true, forKey: Key.tilingPromptAnswered)
    }

    func markWelcomeShown() {
        welcomeShown = true
        defaults.set(true, forKey: Key.welcomeShown)
    }

    func markLoginPromptShown() {
        loginPromptShown = true
        defaults.set(true, forKey: Key.loginPromptShown)
    }

    /// Leest elke voorkeur; ontbreekt hij of is hij ongeldig, dan de standaardwaarde. Getallen binnen hun bereik.
    private func load() {
        func bool(_ key: String, _ fallback: Bool) -> Bool { defaults.object(forKey: key) as? Bool ?? fallback }
        func number(_ key: String) -> Double? { (defaults.object(forKey: key) as? NSNumber)?.doubleValue.nilIfNotFinite }
        func integer(_ key: String, _ fallback: Int, _ range: ClosedRange<Int>) -> Int {
            Int((number(key) ?? Double(fallback)).rounded().clamped(to: Double(range.lowerBound)...Double(range.upperBound)))
        }
        func value<T: RawRepresentable<String>>(_ key: String, _ fallback: T) -> T {
            defaults.string(forKey: key).flatMap { T(rawValue: $0) } ?? fallback
        }
        func color(_ key: String) -> RGBColor { defaults.string(forKey: key).flatMap(RGBColor.init(hex:)) ?? .blue }

        zoomButtonMenu = bool(Key.zoomButtonMenu, true)
        systemMenuModifier = value(Key.systemMenuModifier, .control)
        zoomHoverDelay = (number(Key.zoomHoverDelay) ?? 0.3).clamped(to: PreferenceRange.hoverDelay)
        zoomMenuStyle = value(Key.zoomMenuStyle, .standard)
        excludedBundleIDs = defaults.stringArray(forKey: Key.excludedApps) ?? []
        margin = integer(Key.margin, 0, PreferenceRange.margin)
        fitTightly = bool(Key.fitTightly, false)
        restoreOriginalSize = bool(Key.restoreOriginalSize, true)
        highlightZones = bool(Key.highlightZones, false)
        edgeWidth = integer(Key.edgeWidth, 6, PreferenceRange.edgeWidth)
        innerScale = (number(Key.innerScale) ?? 1).clamped(to: PreferenceRange.innerScale)
        zoneAppearance = value(Key.zoneAppearance, .automatic)
        zoneColor = color(Key.zoneColor)
        zoneOutline = (number(Key.zoneOutline) ?? 1).clamped(to: PreferenceRange.outlineWidth)
        previewAppearance = value(Key.previewAppearance, .automatic)
        previewColor = color(Key.previewColor)
        previewOutline = (number(Key.previewOutline) ?? 1).clamped(to: PreferenceRange.outlineWidth)
        hideMenuBarIcon = bool(Key.hideMenuBarIcon, false)
    }

    /// Schrijft alle voorkeuren; keuzes als rawValue, kleuren als hex.
    private func save() {
        defaults.set(zoomButtonMenu, forKey: Key.zoomButtonMenu)
        defaults.set(systemMenuModifier.rawValue, forKey: Key.systemMenuModifier)
        defaults.set(zoomHoverDelay, forKey: Key.zoomHoverDelay)
        defaults.set(zoomMenuStyle.rawValue, forKey: Key.zoomMenuStyle)
        defaults.set(excludedBundleIDs, forKey: Key.excludedApps)
        defaults.set(margin, forKey: Key.margin)
        defaults.set(fitTightly, forKey: Key.fitTightly)
        defaults.set(restoreOriginalSize, forKey: Key.restoreOriginalSize)
        defaults.set(highlightZones, forKey: Key.highlightZones)
        defaults.set(edgeWidth, forKey: Key.edgeWidth)
        defaults.set(innerScale, forKey: Key.innerScale)
        defaults.set(zoneAppearance.rawValue, forKey: Key.zoneAppearance)
        defaults.set(zoneColor.hex, forKey: Key.zoneColor)
        defaults.set(zoneOutline, forKey: Key.zoneOutline)
        defaults.set(previewAppearance.rawValue, forKey: Key.previewAppearance)
        defaults.set(previewColor.hex, forKey: Key.previewColor)
        defaults.set(previewOutline, forKey: Key.previewOutline)
        defaults.set(hideMenuBarIcon, forKey: Key.hideMenuBarIcon)
    }
}

private extension Double {
    var nilIfNotFinite: Double? { isFinite ? self : nil }
}
