import AppKit
import RasterCore
import SwiftUI

/// Paneel Commands: lijstkolom (275 pt, `listBackground`, kop "Commands" op x 24), de kolomlijn die door de kopbalk
/// loopt, en de detailkolom van het gekozen commando (`SettingsNavigation.selectedCommandID`, blijft bewaard bij
/// wisselen van paneel).
///
/// Weggaan van een nieuw commando zonder gebied vraagt "Incomplete Command" (Discard gooit het weg, Edit blijft).
/// Sluiten van het venster of wisselen naar Preferences gooit zo'n commando zonder vraag weg
/// (`SettingsWindowController`).
struct CommandsPanel: View {
    let model: CommandsModel
    let navigation: SettingsNavigation

    @State private var window = WindowReference()

    private var selectedID: String? { navigation.selectedCommandID }

    var body: some View {
        HStack(spacing: 0) {
            CommandListColumn(model: model, selectedID: selectedID, select: select, addCommand: addCommand,
                              remove: confirmRemove)
            // De kolomlijn loopt door de kopbalk heen.
            SeparatorLine(axis: .vertical)
            CommandDetail(model: model, commandID: selectedID)
        }
        .background(HostWindowReader(reference: window))
        .onAppear { navigation.ensureCommandSelection(in: model) }
        .onChange(of: selectedID) {
            // Een lopende opname hoort bij het vorige commando: stoppen, anders gaat de volgende toets naar een
            // commando dat niet meer in beeld is.
            model.cancelRecording()
        }
        .onChange(of: model.lists) { old, _ in
            navigation.repairCommandSelection(after: old, in: model)
        }
    }

    // MARK: - Kiezen

    /// Kiest `id`; staat er een onvolledig commando open, dan eerst "Incomplete Command".
    private func select(_ id: String) {
        leaveCurrent(towards: id) { navigation.selectedCommandID = id }
    }

    /// Nieuw commando onderaan `axis` en meteen kiezen (na "Incomplete Command" als dat nodig is).
    private func addCommand(_ axis: CommandAxis) {
        leaveCurrent(towards: nil) {
            navigation.selectedCommandID = model.addCustom(axis: axis).id
        }
    }

    /// Voert `proceed` uit als het huidige commando verlaten mag worden: meteen als het compleet is, anders na
    /// "Discard" in de melding (het onvolledige commando verdwijnt eerst). "Edit" laat alles zoals het is.
    /// `next` nil: er komt een nieuw commando.
    private func leaveCurrent(towards next: String?, proceed: @escaping () -> Void) {
        let current = selectedID.flatMap(model.command)
        guard CommandListLogic.needsLeaveConfirmation(current: current, next: next) else {
            proceed()
            return
        }
        CommandListAlert.show(title: L10n.commandContentSheetLeaveTitle, message: L10n.commandContentSheetLeaveSubtitle,
                              confirm: L10n.commandContentSheetLeavePrimaryTitle,
                              cancel: L10n.commandContentSheetLeaveCancelTitle, window: window.window) {
            model.discardIncomplete()
            proceed()
        }
    }

    // MARK: - Verwijderen

    /// "Remove Command" of "Divider" vragen en dan verwijderen; was het gekozen commando weg, dan de buur kiezen.
    private func confirmRemove(_ row: CommandListRow) {
        let title: String, message: String
        switch row {
        case .command(let command):
            guard model.isRemovable(command.id) else { return }
            title = L10n.commandListSectionDeleteSheetTitleCommand
            message = L10n.commandListSectionDeleteSheetSubtitleCommand
        case .divider:
            title = L10n.commandListSectionDeleteSheetTitleDivider
            message = L10n.commandListSectionDeleteSheetSubtitleDivider
        }
        CommandListAlert.show(title: title, message: message, confirm: L10n.commandListSectionDeleteSheetPrimaryTitle,
                              cancel: L10n.coreSheetButtonCancel, isDestructive: true, window: window.window) {
            if let command = row.command, selectedID == command.id {
                // Kiezen vóór het verwijderen, zodat de detailkolom nooit een verdwenen commando toont.
                navigation.selectedCommandID = CommandListLogic.selectionAfterRemoving(
                    command.id, rows: CommandListRow.rows(of: model.lists, axis: command.axis))
            }
            model.remove(row)
        }
    }
}

/// Melding van de lijst als sheet op het instellingenvenster (zonder venster als losse melding): `confirm` is de
/// standaardknop en voert `onConfirm` uit, `cancel` doet niets. `isDestructive`: `confirm` verwijdert iets (rood).
@MainActor
enum CommandListAlert {
    static func show(title: String, message: String, confirm: String, cancel: String, isDestructive: Bool = false,
                     window: NSWindow?, onConfirm: @escaping @MainActor () -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: confirm).hasDestructiveAction = isDestructive
        alert.addButton(withTitle: cancel)
        if let window {
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn { MainActor.assumeIsolated { onConfirm() } }
            }
        } else if alert.runModal() == .alertFirstButtonReturn {
            onConfirm()
        }
    }
}

extension SettingsNavigation {
    /// Na een wijziging van de lijsten (`old` is de toestand ervoor): bestaat het gekozen commando niet meer
    /// (weggegooid of verwijderd buiten de lijst om), dan de buur kiezen, anders het eerste commando van die as.
    func repairCommandSelection(after old: CommandLists, in model: CommandsModel) {
        guard let id = selectedCommandID, model.command(id) == nil else { return }
        let axis = old.command(id)?.axis ?? .horizontal
        selectedCommandID = CommandListLogic.selectionAfterRemoving(id, rows: CommandListRow.rows(of: old, axis: axis))
            .flatMap { model.command($0) != nil ? $0 : nil }
            ?? model.lists[axis].commands.first?.id
    }

    /// Bij het openen van Commands: is het gekozen commando verdwenen terwijl een ander paneel open was (bijv. door
    /// "Restore Defaults"), dan het eerste commando van dezelfde as kiezen.
    func ensureCommandSelection(in model: CommandsModel) {
        guard selectedCommandID.flatMap(model.command) == nil else { return }
        selectedCommandID = model.lists[lastCommandAxis].commands.first?.id ?? model.lists.horizontal.commands.first?.id
    }
}
