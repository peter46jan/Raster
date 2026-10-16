import AppKit
import RasterCore
import SwiftUI

/// Paneel Preferences: de kop "Preferences" (titel op x 36) en daaronder op de achtergrond de
/// secties General, Mouse, Activation Areas, Target Areas, Green Button, Spacing en Defaults, elk een kop met een
/// kaart (486 breed, 22 pt van de linkerkant van de inhoud). Een sectie iCloud ontbreekt: alles staat daardoor
/// 119 pt hoger.
struct PreferencesPanel: View {
    let model: CommandsModel
    let snapping: SnappingSettings
    let settings: AppSettings
    let loginItem: LoginItemState
    let onReset: (ResetScope) -> Void

    /// Het venster van het paneel: daaraan hangt de vraag van "Restore to defaults" als blad.
    @State private var window = WindowReference()

    init(model: CommandsModel, snapping: SnappingSettings, settings: AppSettings, loginItem: LoginItemState,
         onReset: @escaping (ResetScope) -> Void) {
        self.model = model
        self.snapping = snapping
        self.settings = settings
        self.loginItem = loginItem
        self.onReset = onReset
    }

    /// Kaart 22 pt van de linkerkant van de inhoud (gemeten x 93 in het venster, inhoud vanaf 71).
    static let cardLeading: CGFloat = 22

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: L10n.settingsContentTitlePreferences, leading: 36)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    general
                    mouse
                    activationAreas
                    targetAreas
                    greenButton
                    spacing
                    defaults
                }
                .padding(.leading, Self.cardLeading)
                .padding(.bottom, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(RasterColor.background.color)
        }
        .background(HostWindowReader(reference: window))
    }

    // MARK: Secties

    @ViewBuilder private var general: some View {
        SectionTitle(L10n.preferencesContentSectionGeneralTitle)
        SettingsCard {
            SettingsRow(title: L10n.preferencesContentSectionGeneralItemLaunchAtLoginTitle) {
                MiniSwitch(isOn: Self.loginItemBinding(loginItem))
            }
            SettingsRow(title: L10n.preferencesContentSectionGeneralItemHideMenuBarIconTitle,
                        subtitle: L10n.preferencesContentSectionGeneralItemHideMenuBarIconSubtitle) {
                MiniSwitch(isOn: settings.binding(\.hideMenuBarIcon))
            }
        }
    }

    @ViewBuilder private var mouse: some View {
        SectionTitle(L10n.preferencesContentSectionMouseTitle)
        SettingsCard {
            SettingsRow(title: L10n.preferencesContentSectionMouseItemSnapWindowsTitle) {
                MiniSwitch(isOn: Self.snappingBinding(snapping))
            }
            SettingsRow(title: L10n.preferencesContentSectionMouseItemRestoreToOriginalSizeTitle,
                        subtitle: L10n.preferencesContentSectionMouseItemRestoreToOriginalSizeSubtitle) {
                MiniSwitch(isOn: settings.binding(\.restoreOriginalSize))
            }
        }
    }

    /// Uiterlijk en rand van de getoonde gebieden staan er alleen als ze getoond worden: bij tonen uit heeft de kaart alleen de rijen tonen, schaal en randbreedte.
    @ViewBuilder private var activationAreas: some View {
        SectionTitle(L10n.preferencesContentSectionActivationAreasTitle)
        SettingsCard {
            SettingsRow(title: L10n.preferencesContentSectionActivationAreasItemHighlightActivationAreasTitle) {
                MiniSwitch(isOn: settings.binding(\.highlightZones))
            }
            if settings.highlightZones {
                SettingsRow(title: L10n.preferencesContentSectionActivationAreasItemActivationAreaAppearanceTitle,
                            placement: .centered) {
                    AppearancePicker(selection: settings.binding(\.zoneAppearance),
                                     color: settings.colorBinding(\.zoneColor), showsColor: settings.zoneAppearance == .custom,
                                     options: Self.zoneAppearances)
                }
                SettingsRow(title: L10n.preferencesContentSectionActivationAreasItemActivationAreaOutlineTitle,
                            placement: .centered) {
                    outlineStepper(\.zoneOutline)
                }
            }
            SettingsRow(title: L10n.preferencesContentSectionActivationAreasItemActivationAreaScaleTitle,
                        placement: .centered) {
                StepperValue(text: L10n.percent(settings.innerScale), value: settings.binding(\.innerScale, step: 0.1),
                             in: PreferenceRange.innerScale, step: 0.1)
            }
            SettingsRow(title: L10n.preferencesContentSectionActivationAreasItemActivationAreaEdgeWidthTitle,
                        placement: .centered) {
                StepperValue(text: L10n.points(settings.edgeWidth), value: settings.binding(\.edgeWidth),
                             in: PreferenceRange.edgeWidth)
            }
        }
    }

    @ViewBuilder private var targetAreas: some View {
        SectionTitle(L10n.preferencesContentSectionTargetAreasTitle)
        SettingsCard {
            SettingsRow(title: L10n.preferencesContentSectionTargetAreasItemTargetAreaAppearanceTitle,
                        placement: .centered) {
                AppearancePicker(selection: settings.binding(\.previewAppearance),
                                 color: settings.colorBinding(\.previewColor),
                                 showsColor: settings.previewAppearance == .custom, options: Self.previewAppearances)
            }
            SettingsRow(title: L10n.preferencesContentSectionTargetAreasItemTargetAreaOutlineTitle,
                        placement: .centered) {
                outlineStepper(\.previewOutline)
            }
        }
    }

    /// Wachttijd, weergave en toets horen bij het menu: grijs zolang het menu uit staat.
    @ViewBuilder private var greenButton: some View {
        SectionTitle(L10n.preferencesContentSectionGreenButtonTitle)
        SettingsCard {
            SettingsRow(title: L10n.preferencesContentSectionGreenButtonItemShowGreenButtonMenuTitle,
                        subtitle: L10n.preferencesContentSectionGreenButtonItemShowGreenButtonMenuSubtitle) {
                MiniSwitch(isOn: settings.binding(\.zoomButtonMenu))
            }
            SettingsRow(title: L10n.preferencesContentSectionGreenButtonItemGreenButtonDelayTitle,
                        placement: .centered) {
                StepperValue(text: L10n.seconds(settings.zoomHoverDelay),
                             value: settings.binding(\.zoomHoverDelay, step: 0.1), in: PreferenceRange.hoverDelay,
                             step: 0.1)
            }
            .disabled(!settings.zoomButtonMenu)
            SettingsRow(title: L10n.preferencesContentSectionGreenButtonItemGreenButtonMenuAppearanceTitle,
                        placement: .centered) {
                PopUp(selection: settings.binding(\.zoomMenuStyle), options: Self.zoomMenuStyles)
            }
            .disabled(!settings.zoomButtonMenu)
            SettingsRow(title: L10n.preferencesContentSectionGreenButtonItemGreenButtonMenuModifierTitle,
                        placement: .centered) {
                PopUp(selection: settings.binding(\.systemMenuModifier), options: Self.systemMenuModifiers)
            }
            .disabled(!settings.zoomButtonMenu)
        }
    }

    /// "Fit tightly" gaat over de marges: grijs zolang er geen marge is.
    @ViewBuilder private var spacing: some View {
        SectionTitle(L10n.preferencesContentSectionSpacingTitle)
        SettingsCard {
            SettingsRow(title: L10n.preferencesContentSectionSpacingItemPaddingAroundWindowsTitle,
                        placement: .centered) {
                StepperValue(text: L10n.points(settings.margin), value: settings.binding(\.margin),
                             in: PreferenceRange.margin)
            }
            SettingsRow(title: L10n.preferencesContentSectionSpacingItemFitTightlyToScreenEdgesTitle,
                        subtitle: L10n.preferencesContentSectionSpacingItemFitTightlyToScreenEdgesSubtitle) {
                MiniSwitch(isOn: settings.binding(\.fitTightly))
                    .disabled(settings.margin == 0)
            }
        }
    }

    /// Kaart met alleen de knop "Restore to defaults", rechts in een rij van 39 pt.
    @ViewBuilder private var defaults: some View {
        SectionTitle(L10n.preferencesContentSectionDefaultsTitle)
        SettingsCard {
            HStack {
                Spacer(minLength: 0)
                Button(L10n.preferencesContentSectionDefaultsButtonReset) {
                    PreferencesReset.confirm(commandsReadOnly: model.isReadOnly, window: window.window,
                                             onReset: onReset)
                }
                .padding(.trailing, 14)
            }
            .frame(height: 39)
        }
    }

    private func outlineStepper(_ keyPath: ReferenceWritableKeyPath<AppSettings, Double>) -> some View {
        StepperValue(text: L10n.points(settings[keyPath: keyPath]), value: settings.binding(keyPath, step: 0.5),
                     in: PreferenceRange.outlineWidth, step: 0.5)
    }

    // MARK: Bindings en keuzes

    /// "Snap windows by dragging" staat alleen aan als slepen aan staat én de muisbewaking draait. Weigerde macOS de
    /// bewaking, dan staat de schakelaar uit en probeert aanzetten het opnieuw (`set(true)` past slepen opnieuw toe).
    static func snappingBinding(_ snapping: SnappingSettings) -> Binding<Bool> {
        Binding(get: { snapping.state.isEnabled && snapping.state.isRunning },
                set: { snapping.set($0) })
    }

    /// Starten bij inloggen aan of uit; vraagt macOS daarna om goedkeuring, dan opent Systeeminstellingen ›
    /// Inlogonderdelen.
    static func loginItemBinding(_ loginItem: LoginItemState) -> Binding<Bool> {
        Binding(get: { loginItem.isOn }, set: { value in
            guard value != loginItem.isOn else { return }
            loginItem.toggle()
            if value && loginItem.needsApproval { LoginItem.openSettings() }
        })
    }

    static let zoneAppearances: [(value: ZoneAppearance, title: String)] = [
        (.automatic, L10n.highlightAreaActivationAppearanceDescriptionAutomatic),
        (.custom, L10n.highlightAreaActivationAppearanceDescriptionCustom),
    ]

    static let previewAppearances: [(value: PreviewAppearance, title: String)] = [
        (.automatic, L10n.highlightAreaTargetAppearanceDescriptionAutomatic),
        (.light, L10n.highlightAreaTargetAppearanceDescriptionLight),
        (.dark, L10n.highlightAreaTargetAppearanceDescriptionDark),
        (.inverse, L10n.highlightAreaTargetAppearanceDescriptionInverse),
        (.custom, L10n.highlightAreaTargetAppearanceDescriptionCustom),
    ]

    static let zoomMenuStyles: [(value: ZoomMenuStyle, title: String)] = [
        (.standard, L10n.greenButtonMenuAppearanceDescriptionStandard),
        (.compact, L10n.greenButtonMenuAppearanceDescriptionCompact),
        (.horizontal, L10n.greenButtonMenuAppearanceDescriptionHorizontal),
    ]

    static let systemMenuModifiers: [(value: SystemMenuModifier, title: String)] = [
        (.control, L10n.greenButtonMenuModifierDescriptionControl),
        (.command, L10n.greenButtonMenuModifierDescriptionCommand),
    ]
}

/// Pop-up met het uiterlijk en, bij "Custom", links ervan een kleurkiezer van het systeem. VoiceOver noemt de
/// pop-up met de titel van de rij en de kleurkiezer met die titel plus "custom color", zodat ze te onderscheiden zijn.
private struct AppearancePicker<Value: Hashable>: View {
    let selection: Binding<Value>
    let color: Binding<Color>
    let showsColor: Bool
    let options: [(value: Value, title: String)]

    @Environment(\.settingsRowTitle) private var rowTitle

    var body: some View {
        HStack(spacing: 8) {
            if showsColor {
                ColorPicker(L10n.customColor(rowTitle), selection: color, supportsOpacity: false)
                    .labelsHidden()
            }
            PopUp(selection: selection, options: options)
        }
    }
}

// Alleen voor VoiceOver: label van de kleurkiezer.
extension L10n {
    /// Label voor VoiceOver van de kleurkiezer naast een pop-up voor het uiterlijk.
    static func customColor(_ rowTitle: String) -> String { rowTitle + ", custom color" }
}
