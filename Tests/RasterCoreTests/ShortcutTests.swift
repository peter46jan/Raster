import Testing
@testable import RasterCore

struct ShortcutTests {
    @Test func modifierConstantsMatchCarbon() {
        #expect(Shortcut.controlOption == 6144)       // controlKey 4096 + optionKey 2048
        #expect(Shortcut.controlOptionCommand == 6400) // + cmdKey 256
    }

    @Test func keyEquivalents() {
        func key(_ code: UInt32) -> String? { Shortcut(keyCode: code, modifiers: Shortcut.controlOption).keyEquivalent }
        #expect(key(123) == "\u{F702}") // ←
        #expect(key(124) == "\u{F703}") // →
        #expect(key(125) == "\u{F701}") // ↓
        #expect(key(126) == "\u{F700}") // ↑
        #expect(key(36) == "\r")
        #expect(key(51) == "\u{8}")
        #expect(key(32) == "u")
        #expect(key(2) == "d")
        #expect(key(8) == "c")
        #expect(key(999) == nil)
    }

    @Test func displayString() {
        #expect(Shortcut(keyCode: 123, modifiers: Shortcut.controlOption).displayString == "⌃⌥◀")
        #expect(Shortcut(keyCode: 124, modifiers: Shortcut.controlOptionCommand).displayString == "⌃⌥⌘▶")
        #expect(Shortcut(keyCode: 32, modifiers: Shortcut.controlOption | Shortcut.shift).displayString == "⌃⌥⇧U")
        #expect(Shortcut(keyCode: 36, modifiers: Shortcut.controlOption).displayString == "⌃⌥↩")
        #expect(Shortcut(keyCode: 51, modifiers: Shortcut.controlOption).displayString == "⌃⌥⌫")
        #expect(Shortcut(keyCode: 122, modifiers: Shortcut.command).displayString == "⌘F1")
        #expect(Shortcut(keyCode: 49, modifiers: Shortcut.option).displayString == "⌥Space")
        #expect(Shortcut(keyCode: 999, modifiers: Shortcut.option).displayString == "⌥#999")
    }

    @Test func arrowSymbols() {
        #expect(Shortcut(keyCode: 125, modifiers: Shortcut.controlOption).displayString == "⌃⌥▼")
        #expect(Shortcut(keyCode: 126, modifiers: Shortcut.controlOptionCommand).displayString == "⌃⌥⌘▲")
    }

    @Test func validity() {
        #expect(Shortcut(keyCode: 123, modifiers: Shortcut.controlOption).isValid)
        #expect(Shortcut(keyCode: 2, modifiers: Shortcut.command).isValid)
        #expect(!Shortcut(keyCode: 2, modifiers: 0).isValid)             // zonder modifier
        #expect(!Shortcut(keyCode: 2, modifiers: Shortcut.shift).isValid) // alleen shift
        #expect(!Shortcut(keyCode: 999, modifiers: Shortcut.command).isValid) // onbekende toets
    }

    @Test func extendedKeyEquivalents() {
        func key(_ code: UInt32) -> String? { Shortcut(keyCode: code, modifiers: Shortcut.command).keyEquivalent }
        #expect(key(122) == "\u{F704}") // F1
        #expect(key(111) == "\u{F70F}") // F12
        #expect(key(53) == "\u{1B}")
        #expect(key(48) == "\t")
        #expect(key(117) == "\u{F728}")
        #expect(key(27) == "-")
        #expect(key(47) == ".")
    }
}
