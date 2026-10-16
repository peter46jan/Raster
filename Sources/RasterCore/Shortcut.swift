/// Een sneltoets in Carbon-vorm: virtuele toetscode en Carbon-modifiers
/// (cmdKey 256, shiftKey 512, optionKey 2048, controlKey 4096).
public struct Shortcut: Codable, Hashable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public static let command: UInt32 = 256
    public static let shift: UInt32 = 512
    public static let option: UInt32 = 2048
    public static let control: UInt32 = 4096
    public static let controlOption: UInt32 = control | option
    public static let controlOptionCommand: UInt32 = control | option | command

    /// Teken voor `NSMenuItem.keyEquivalent`, of nil als de toets niet in de tabel staat.
    public var keyEquivalent: String? {
        Self.keys[keyCode]?.equivalent
    }

    /// Een sneltoets moet minstens ⌃, ⌥ of ⌘ hebben (alleen ⇧ botst met gewoon typen) en een bekende toets.
    public var isValid: Bool {
        modifiers & (Self.control | Self.option | Self.command) != 0 && Self.keys[keyCode] != nil
    }

    /// Weergave: ⌃⌥⇧⌘ en dan de toets, bijv. "⌃⌥◀".
    public var displayString: String {
        var text = ""
        if modifiers & Self.control != 0 { text += "⌃" }
        if modifiers & Self.option != 0 { text += "⌥" }
        if modifiers & Self.shift != 0 { text += "⇧" }
        if modifiers & Self.command != 0 { text += "⌘" }
        return text + (Self.keys[keyCode]?.name ?? "#\(keyCode)")
    }

    private struct Key {
        let name: String
        let equivalent: String
    }

    private static let keys: [UInt32: Key] = {
        var keys: [UInt32: Key] = [
            // Pijltjes zoals in het sneltoetsveld.
            123: Key(name: "◀", equivalent: "\u{F702}"), 124: Key(name: "▶", equivalent: "\u{F703}"),
            125: Key(name: "▼", equivalent: "\u{F701}"), 126: Key(name: "▲", equivalent: "\u{F700}"),
            36: Key(name: "↩", equivalent: "\r"), 51: Key(name: "⌫", equivalent: "\u{8}"),
            117: Key(name: "⌦", equivalent: "\u{F728}"), 48: Key(name: "⇥", equivalent: "\t"),
            53: Key(name: "⎋", equivalent: "\u{1B}"), 49: Key(name: "Space", equivalent: " "),
            115: Key(name: "↖", equivalent: "\u{F729}"), 119: Key(name: "↘", equivalent: "\u{F72B}"),
            116: Key(name: "⇞", equivalent: "\u{F72C}"), 121: Key(name: "⇟", equivalent: "\u{F72D}"),
        ]
        let characters: [UInt32: String] = [
            0: "a", 11: "b", 8: "c", 2: "d", 14: "e", 3: "f", 5: "g", 4: "h", 34: "i",
            38: "j", 40: "k", 37: "l", 46: "m", 45: "n", 31: "o", 35: "p", 12: "q",
            15: "r", 1: "s", 17: "t", 32: "u", 9: "v", 13: "w", 7: "x", 16: "y", 6: "z",
            29: "0", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9",
            27: "-", 24: "=", 33: "[", 30: "]", 41: ";", 39: "'", 43: ",", 47: ".", 44: "/", 42: "\\", 50: "`",
        ]
        for (code, character) in characters {
            keys[code] = Key(name: character.uppercased(), equivalent: character)
        }
        // F1–F12: NSF1FunctionKey (0xF704) en verder.
        let functionKeys: [UInt32] = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]
        for (index, code) in functionKeys.enumerated() {
            keys[code] = Key(name: "F\(index + 1)", equivalent: String(UnicodeScalar(0xF704 + index)!))
        }
        return keys
    }()
}
