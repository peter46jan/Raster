import Carbon.HIToolbox
import RasterCore

/// Registreert elke sneltoets één keer; Horizontal en Vertical delen ze. Welk commando een sneltoets uitvoert,
/// kiest de app bij het indrukken aan de hand van het scherm van het actieve venster. Een sneltoets die macOS al
/// gebruikt of die niet te registreren is, komt in `conflicts`; de rest werkt gewoon.
@MainActor
public final class HotkeyManager {
    public var onHotkey: ((Shortcut) -> Void)?
    public private(set) var conflicts: Set<Shortcut> = []

    private var registered: [EventHotKeyRef] = []
    private var shortcuts: [UInt32: Shortcut] = [:]
    private var handlerRef: EventHandlerRef?
    /// Loopt door over alle `register`-aanroepen heen, zodat een wachtende gebeurtenis van een
    /// eerdere registratie nooit een andere sneltoets start.
    private var nextNumber: UInt32 = 0

    public init() {}

    isolated deinit {
        unregisterAll()
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }

    public func register(_ shortcuts: Set<Shortcut>) {
        unregisterAll()
        guard installHandler() else {
            conflicts = shortcuts
            return
        }
        let system = SystemHotKeys.enabled()
        var conflicts = Set<Shortcut>()
        // Vaste volgorde, zodat registreren voorspelbaar is.
        for shortcut in shortcuts.sorted(by: { ($0.modifiers, $0.keyCode) < ($1.modifiers, $1.keyCode) }) {
            nextNumber += 1
            let number = nextNumber
            if system.contains(shortcut) { conflicts.insert(shortcut) }
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: number)
            let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref {
                registered.append(ref)
                self.shortcuts[number] = shortcut
            } else {
                conflicts.insert(shortcut)
            }
        }
        self.conflicts = conflicts
    }

    public func unregisterAll() {
        for ref in registered { UnregisterEventHotKey(ref) }
        registered = []
        shortcuts = [:]
    }

    fileprivate func handle(_ number: UInt32) {
        guard let shortcut = shortcuts[number] else { return }
        onHotkey?(shortcut)
    }

    private func installHandler() -> Bool {
        if handlerRef != nil { return true }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetApplicationEventTarget(), hotKeyHandler, 1, &eventType,
            Unmanaged.passUnretained(self).toOpaque(), &handlerRef
        )
        if status != noErr { handlerRef = nil }
        return status == noErr
    }
}

/// "MGNT"
private let hotKeySignature: OSType = 0x4D47_4E54

/// Carbon roept dit aan op de hoofdthread.
private func hotKeyHandler(_ next: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
        nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
    )
    guard status == noErr, hotKeyID.signature == hotKeySignature else { return OSStatus(eventNotHandledErr) }
    let number = hotKeyID.id
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData)
    MainActor.assumeIsolated {
        manager.takeUnretainedValue().handle(number)
    }
    return noErr
}
