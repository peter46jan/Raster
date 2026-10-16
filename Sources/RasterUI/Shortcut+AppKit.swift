import AppKit
import RasterCore

extension Shortcut {
    var modifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & Shortcut.command != 0 { flags.insert(.command) }
        if modifiers & Shortcut.shift != 0 { flags.insert(.shift) }
        if modifiers & Shortcut.option != 0 { flags.insert(.option) }
        if modifiers & Shortcut.control != 0 { flags.insert(.control) }
        return flags
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= Shortcut.command }
        if flags.contains(.shift) { modifiers |= Shortcut.shift }
        if flags.contains(.option) { modifiers |= Shortcut.option }
        if flags.contains(.control) { modifiers |= Shortcut.control }
        return modifiers
    }
}
