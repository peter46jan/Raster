import Testing
import RasterCore
@testable import RasterSystem

struct SystemHotKeysTests {
    @Test func parsesOnlyEnabledEntries() {
        let list: [[String: Any]] = [
            ["kHISymbolicHotKeyEnabled": true, "kHISymbolicHotKeyCode": 53, "kHISymbolicHotKeyModifiers": 2304],
            ["kHISymbolicHotKeyEnabled": false, "kHISymbolicHotKeyCode": 123, "kHISymbolicHotKeyModifiers": 4096],
            ["kHISymbolicHotKeyEnabled": true, "kHISymbolicHotKeyCode": 124],
        ]
        #expect(SystemHotKeys.parse(list) == [Shortcut(keyCode: 53, modifiers: 2304)])
    }

    @Test func ignoresNonModifierBits() {
        // 0x800000 (functietoets) en andere bits tellen niet mee.
        let list: [[String: Any]] = [
            ["kHISymbolicHotKeyEnabled": true, "kHISymbolicHotKeyCode": 123, "kHISymbolicHotKeyModifiers": 6144 | 0x800000],
        ]
        #expect(SystemHotKeys.parse(list) == [Shortcut(keyCode: 123, modifiers: 6144)])
    }
}
