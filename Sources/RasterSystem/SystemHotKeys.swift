import Carbon.HIToolbox
import Foundation
import RasterCore

/// Sneltoetsen die macOS zelf gebruikt (Mission Control, Spotlight, enzovoort).
public enum SystemHotKeys {
    static let modifierMask = Shortcut.command | Shortcut.shift | Shortcut.option | Shortcut.control

    public static func enabled() -> Set<Shortcut> {
        var array: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&array) == noErr,
              let list = array?.takeRetainedValue() as? [[String: Any]] else { return [] }
        return parse(list)
    }

    static func parse(_ list: [[String: Any]]) -> Set<Shortcut> {
        Set(list.compactMap { entry -> Shortcut? in
            guard (entry["kHISymbolicHotKeyEnabled"] as? Bool) == true,
                  let code = (entry["kHISymbolicHotKeyCode"] as? NSNumber)?.uint32Value,
                  let modifiers = (entry["kHISymbolicHotKeyModifiers"] as? NSNumber)?.uint32Value
            else { return nil }
            return Shortcut(keyCode: code, modifiers: modifiers & modifierMask)
        })
    }
}
