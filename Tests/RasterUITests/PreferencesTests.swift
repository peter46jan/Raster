import AppKit
import RasterCore
import SwiftUI
import Testing
@testable import RasterUI

/// Paneel Preferences: de resetvraag, de schakelaar voor slepen, de waarden naast de steppers en de rijen met
/// subtitel.
@MainActor
struct PreferencesTests {
    @Test func resetOffersAllThreeChoicesInOrder() {
        let choices = PreferencesReset.choices(commandsReadOnly: false)
        #expect(choices.map(\.scope) == [.all, .commands, .preferences])
        #expect(choices.map(\.title) == ["Reset Everything", "Reset Commands", "Reset Preferences"])
    }

    @Test func readOnlyCommandsOnlyRestorePreferences() {
        let choices = PreferencesReset.choices(commandsReadOnly: true)
        #expect(choices.map(\.scope) == [.preferences])
    }

    @Test func resetAlertHasTextsAndCancelWithEscape() {
        let alert = PreferencesReset.alert(commandsReadOnly: false)
        #expect(alert.messageText == "Reset to Defaults")
        #expect(alert.informativeText == L10n.preferencesContentSectionDefaultsSheetResetSubtitle)
        #expect(alert.buttons.map(\.title) == ["Reset Everything", "Reset Commands", "Reset Preferences", "Cancel"])
        #expect(alert.buttons.last?.keyEquivalent == "\u{1b}")

        let readOnly = PreferencesReset.alert(commandsReadOnly: true)
        #expect(readOnly.buttons.map(\.title) == ["Reset Preferences", "Cancel"])
    }

    @Test func resetResponseMapsToScope() {
        let first = NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        func response(_ index: Int) -> NSApplication.ModalResponse { .init(rawValue: first + index) }
        #expect(PreferencesReset.scope(for: response(0), commandsReadOnly: false) == .all)
        #expect(PreferencesReset.scope(for: response(1), commandsReadOnly: false) == .commands)
        #expect(PreferencesReset.scope(for: response(2), commandsReadOnly: false) == .preferences)
        #expect(PreferencesReset.scope(for: response(3), commandsReadOnly: false) == nil, "Cancel")
        #expect(PreferencesReset.scope(for: response(0), commandsReadOnly: true) == .preferences)
        #expect(PreferencesReset.scope(for: response(1), commandsReadOnly: true) == nil, "Cancel")
        #expect(PreferencesReset.scope(for: .abort, commandsReadOnly: false) == nil)
    }

    /// Aan maar geweigerd door macOS: de schakelaar staat uit, en aanzetten probeert het opnieuw.
    @Test func snappingSwitchShowsRunningStateAndRetries() {
        var calls: [Bool] = []
        let state = SnappingState(isEnabled: true, isRunning: false)
        let binding = PreferencesPanel.snappingBinding(SnappingSettings(state: state, set: { calls.append($0) }))
        #expect(binding.wrappedValue == false)
        binding.wrappedValue = true
        #expect(calls == [true])

        state.isRunning = true
        #expect(binding.wrappedValue == true)
        binding.wrappedValue = false
        #expect(calls == [true, false])

        state.isEnabled = false
        #expect(binding.wrappedValue == false, "uit, ook al draait de bewaking nog")
    }

    @Test func stepperValuesInEnglish() {
        #expect(L10n.points(1.0) == "1 pt")
        #expect(L10n.points(1.5) == "1.5 pt")
        #expect(L10n.points(0.0) == "0 pt")
        #expect(L10n.points(8) == "8 pt")
        #expect(L10n.percent(0.8) == "80 %")
        #expect(L10n.percent(1.0) == "100 %")
        #expect(L10n.percent(0.7000000001) == "70 %")
        #expect(L10n.seconds(0.3) == "0.3 s")
        #expect(L10n.seconds(2) == "2.0 s")
    }

    @Test func subtitleLinesFollowLineBreaks() {
        let lines = SettingsRow<EmptyView>.subtitleLines(
            L10n.preferencesContentSectionMouseItemRestoreToOriginalSizeSubtitle)
        #expect(lines == ["A snapped window gets its earlier size back", "as soon as you drag it out of place."])
        #expect(SettingsRow<EmptyView>.subtitleLines("One line.") == ["One line."])
    }

    /// Een rij met twee subtitelregels is 69,5 pt hoog, één regel 55,5 pt, zonder subtitel 39 pt; los
    /// van de regelhoogte die SwiftUI een tekst geeft.
    @Test func settingsRowHeights() {
        func height(_ subtitle: String?) -> CGFloat {
            let row = SettingsRow(title: "Title", subtitle: subtitle) { EmptyView() }
            let host = NSHostingController(rootView: row.frame(width: 486))
            return host.sizeThatFits(in: CGSize(width: 486, height: 10_000)).height
        }
        let two = height(L10n.preferencesContentSectionGeneralItemHideMenuBarIconSubtitle)
        #expect(two == 69.5, "\(two)")
        let one = height(L10n.preferencesContentSectionSpacingItemFitTightlyToScreenEdgesSubtitle)
        #expect(one == 55.5, "\(one)")
        let none = height(nil)
        #expect(none == 39, "\(none)")
    }

    /// De kleurkiezer naast een pop-up voor het uiterlijk heeft voor VoiceOver een ander label dan de pop-up.
    @Test func appearanceColorPickerHasItsOwnLabel() {
        let title = L10n.preferencesContentSectionTargetAreasItemTargetAreaAppearanceTitle
        #expect(L10n.customColor(title) != title)
        #expect(L10n.customColor(title).hasPrefix(title))
    }

    /// Voorkeuren in het geheugen (tests en raster-render): lezen, bewaren onder dezelfde sleutels als in de app en
    /// herstellen naar standaard, zonder de eenmalige vragen en de genegeerde apps.
    @Test func settingsUseTheirStorage() {
        let storage = InMemorySettingsStorage(["margin": 8, "excludedApps": ["com.example.app"], "welcomeShown": true,
                                               "zoomButtonNeedsControl": true])
        let settings = AppSettings(storage: storage)
        #expect(settings.margin == 8)
        #expect(settings.excludedBundleIDs == ["com.example.app"])
        #expect(settings.welcomeShown)
        #expect(storage.object(forKey: "zoomButtonNeedsControl") == nil, "oude instelling opgeruimd")

        settings.set(\.fitTightly, true)
        #expect(storage.bool(forKey: "fitTightly"))
        settings.set(\.zoneColor, RGBColor.blue)
        #expect(storage.string(forKey: "zoneColor") == RGBColor.blue.hex)

        settings.resetPreferences()
        #expect(settings.margin == 0 && !settings.fitTightly)
        #expect(storage.object(forKey: "margin") == nil)
        #expect(settings.excludedBundleIDs == ["com.example.app"], "genegeerde apps blijven")
        #expect(storage.bool(forKey: "welcomeShown"), "eenmalige vragen blijven")
    }
}
