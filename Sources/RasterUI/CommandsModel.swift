import AppKit
import RasterCore
import Observation

/// Commando's voor de interface: elke wijziging wordt meteen bewaard en gemeld, zodat de app de
/// sneltoetsen opnieuw registreert. Tijdens het opnemen van een sneltoets staan die even uit.
@MainActor
@Observable
package final class CommandsModel {
    private(set) var store: CommandStore
    /// Sneltoetsen die macOS of een andere app al gebruikt (van `HotkeyManager`).
    private(set) var systemConflicts: Set<Shortcut> = []
    /// Het commando waarvan de sneltoets nu wordt opgenomen; er is er maximaal één tegelijk.
    private(set) var recordingID: String?
    /// Waarom de laatste toets tijdens het opnemen niet is toegewezen; de opname loopt dan door. De volgende toets
    /// (of stoppen met opnemen) wist hem.
    private(set) var recordingError: RecordingError?

    /// Fout tijdens het opnemen.
    enum RecordingError: Equatable {
        /// Een ander commando op dezelfde as gebruikt de combinatie al ("This combination is taken").
        case taken
    }

    /// Wat een toets tijdens het opnemen doet.
    enum RecordingDecision: Equatable {
        /// ⎋: stoppen zonder iets te wijzigen.
        case cancel
        /// ⌫ of ⌦ zonder modifiers: de sneltoets wissen en stoppen.
        case clear
        /// Geen geldige sneltoets (geen ⌃, ⌥ of ⌘, of een onbekende toets): piepen, de opname loopt door.
        case invalid
        /// Al in gebruik op dezelfde as: niet toewijzen, de opname loopt door.
        case taken
        /// Toewijzen en stoppen.
        case assign(Shortcut)
    }

    @ObservationIgnored var onCommandsChange: (() -> Void)?
    @ObservationIgnored var onRecordingChange: ((Bool) -> Void)?
    @ObservationIgnored private var monitor: Any?

    package init(store: CommandStore) {
        self.store = store
    }

    var lists: CommandLists { store.lists }
    func commands(for axis: CommandAxis) -> [Command] { store.commands(for: axis) }
    func command(_ id: String) -> Command? { store.command(id) }
    var isReadOnly: Bool { store.isReadOnly }
    var readOnlyReason: CommandStore.ReadOnlyReason? { store.readOnlyReason }
    var isRecording: Bool { recordingID != nil }

    /// Id's van commando's (beide lijsten) met een sneltoets die al in gebruik is: bij macOS of een andere app,
    /// of bij een ander commando op dezelfde as.
    var conflicts: Set<String> {
        let all = store.lists.horizontal.commands + store.lists.vertical.commands
        let system = all.filter { command in
            command.activeShortcut.map { systemConflicts.contains($0) } ?? false
        }.map(\.id)
        return Set(system).union(ShortcutConflicts.duplicates(in: store.lists))
    }

    func setSystemConflicts(_ shortcuts: Set<Shortcut>) {
        if systemConflicts != shortcuts { systemConflicts = shortcuts }
    }

    func setShortcut(_ shortcut: Shortcut?, for id: String) { mutate { $0.setShortcut(shortcut, for: id) } }
    func setShortcutEnabled(_ enabled: Bool, for id: String) { mutate { $0.setShortcutEnabled(enabled, for: id) } }
    func setDragZonesEnabled(_ enabled: Bool, for id: String) { mutate { $0.setDragZonesEnabled(enabled, for: id) } }
    func setInMenuBar(_ value: Bool, for id: String) { mutate { $0.setInMenuBar(value, for: id) } }
    func setInZoomButtonMenu(_ value: Bool, for id: String) { mutate { $0.setInZoomButtonMenu(value, for: id) } }
    func setArea(_ area: GridArea, for id: String) { mutate { $0.setArea(area, for: id) } }
    func setDragZones(_ zones: GridArea, for id: String) { mutate { $0.setDragZones(zones, for: id) } }
    func setName(_ name: String, for id: String) { mutate { $0.setName(name, for: id) } }
    func removeDragZone(at cell: GridCell, from id: String) { mutate { $0.removeDragZone(at: cell, from: id) } }
    func remove(_ id: String) { mutate { $0.remove(id) } }
    func isRemovable(_ id: String) -> Bool { store.isRemovable(id) }
    func discardIncomplete() { mutate { $0.discardIncomplete() } }
    func moveLayout(_ axis: CommandAxis, fromOffsets source: IndexSet, toOffset destination: Int) {
        mutate { $0.moveLayoutEntries(axis, fromOffsets: source, toOffset: destination) }
    }
    func insertDivider(_ axis: CommandAxis, at index: Int) { mutate { $0.insertDivider(axis, at: index) } }
    func removeDivider(_ axis: CommandAxis, id: String) { mutate { $0.removeDivider(axis, id: id) } }
    func resetAll() { mutate { $0.resetAll() } }

    /// Nieuw, nog leeg eigen commando onderaan de lijst van `axis`.
    @discardableResult
    func addCustom(axis: CommandAxis) -> Command {
        var added: Command?
        mutate { added = $0.addCustom(axis: axis, name: L10n.commandDefaultName) }
        return added!
    }

    /// Begint met opnemen voor één commando; een lopende opname stopt eerst. ⎋ annuleert, ⌫/⌦ zonder
    /// modifiers wist de sneltoets, een ongeldige combinatie geeft een piep.
    package func startRecording(for id: String) {
        // Wisselen van recorder: de oude stopt stilletjes, zodat `onRecordingChange` één keer true en één keer false meldt.
        let wasRecording = isRecording
        removeMonitor()
        recordingID = id
        recordingError = nil
        if !wasRecording { onRecordingChange?(true) }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
            return nil
        }
    }

    package func cancelRecording() {
        removeMonitor()
        recordingError = nil
        guard recordingID != nil else { return }
        recordingID = nil
        onRecordingChange?(false)
    }

    private func removeMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func handle(_ event: NSEvent) {
        handleKey(keyCode: event.keyCode, flags: event.modifierFlags)
    }

    /// Verwerkt één toets tijdens het opnemen (los van NSEvent, zodat het te testen en te renderen is).
    package func handleKey(keyCode: UInt16, flags: NSEvent.ModifierFlags) {
        guard let id = recordingID else { return }
        recordingError = nil
        switch Self.decision(keyCode: keyCode, flags: flags, for: id, in: store.lists) {
        case .cancel:
            cancelRecording()
        case .clear:
            setShortcut(nil, for: id)
            cancelRecording()
        case .invalid:
            NSSound.beep()
        case .taken:
            recordingError = .taken
        case .assign(let shortcut):
            setShortcut(shortcut, for: id)
            cancelRecording()
        }
    }

    /// Wat een toets met `flags` doet bij het opnemen voor commando `id`: ⎋ annuleert, ⌫/⌦ zonder modifiers wist,
    /// een ongeldige combinatie piept en een combinatie die een ander commando op dezelfde as al gebruikt, wordt niet
    /// toegewezen.
    static func decision(keyCode: UInt16, flags: NSEvent.ModifierFlags, for id: String,
                         in lists: CommandLists) -> RecordingDecision {
        let flags = flags.intersection([.command, .option, .control, .shift])
        if flags.isEmpty && keyCode == 53 { return .cancel } // ⎋
        if flags.isEmpty && (keyCode == 51 || keyCode == 117) { return .clear } // ⌫ / ⌦
        let candidate = Shortcut(keyCode: UInt32(keyCode), modifiers: Shortcut.carbonModifiers(from: flags))
        guard candidate.isValid else { return .invalid }
        if let axis = lists.command(id)?.axis, lists.isTaken(candidate, axis: axis, except: id) { return .taken }
        return .assign(candidate)
    }

    /// Wat de sneltoetsregistratie nodig heeft: de sneltoetsen van beide lijsten die werken.
    private var hotkeySignature: Set<Shortcut> {
        store.lists.activeShortcuts
    }

    private func mutate(_ change: (inout CommandStore) -> Void) {
        let before = hotkeySignature
        change(&store)
        do {
            try store.save()
        } catch {
            NSLog("Raster: commando's niet bewaard: %@", String(describing: error))
        }
        if hotkeySignature != before { onCommandsChange?() }
    }
}
