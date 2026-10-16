import AppKit

/// De vraag achter "Restore to defaults": wat terug naar de standaard moet.
enum PreferencesReset {
    /// Knoppen van de melding met wat ze herstellen, in vaste volgorde. Kunnen de commando's niet bewaard
    /// worden (alleen-lezen), dan alleen de voorkeuren. "Cancel" komt er altijd achter.
    static func choices(commandsReadOnly: Bool) -> [(scope: ResetScope, title: String)] {
        if commandsReadOnly {
            return [(.preferences, L10n.preferencesContentSectionDefaultsSheetResetOptionPreferences)]
        }
        return [
            (.all, L10n.preferencesContentSectionDefaultsSheetResetOptionAll),
            (.commands, L10n.preferencesContentSectionDefaultsSheetResetOptionCommands),
            (.preferences, L10n.preferencesContentSectionDefaultsSheetResetOptionPreferences),
        ]
    }

    /// De melding zelf (titel "Restore", de uitleg, de keuzes en "Cancel" met ⎋).
    @MainActor
    static func alert(commandsReadOnly: Bool) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = L10n.preferencesContentSectionDefaultsSheetResetTitle
        alert.informativeText = L10n.preferencesContentSectionDefaultsSheetResetSubtitle
        for choice in choices(commandsReadOnly: commandsReadOnly) {
            alert.addButton(withTitle: choice.title)
        }
        alert.addButton(withTitle: L10n.coreSheetButtonCancel).keyEquivalent = "\u{1b}"
        return alert
    }

    /// Wat de knop met `response` herstelt; nil bij "Cancel" (of een onbekend antwoord).
    static func scope(for response: NSApplication.ModalResponse, commandsReadOnly: Bool) -> ResetScope? {
        let index = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        let choices = choices(commandsReadOnly: commandsReadOnly)
        return choices.indices.contains(index) ? choices[index].scope : nil
    }

    /// Vraagt het als blad aan `window` (anders als los venster) en geeft de keuze aan `onReset`.
    @MainActor
    static func confirm(commandsReadOnly: Bool, window: NSWindow?, onReset: @escaping (ResetScope) -> Void) {
        let alert = alert(commandsReadOnly: commandsReadOnly)
        let finish = { (response: NSApplication.ModalResponse) in
            if let scope = scope(for: response, commandsReadOnly: commandsReadOnly) { onReset(scope) }
        }
        if let window, window.isVisible {
            alert.beginSheetModal(for: window, completionHandler: finish)
        } else {
            NSApp.activate()
            finish(alert.runModal())
            NSApp.yieldFocusIfIdle()
        }
    }
}
