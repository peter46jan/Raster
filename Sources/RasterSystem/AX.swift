import ApplicationServices
import Foundation

/// Dunne helpers rond `AXUIElement`. Attribuutnamen als letterlijke tekst, zodat er geen
/// globale C-variabelen nodig zijn (strikte concurrency van Swift 6).
enum AX {
    static let position = "AXPosition"
    static let size = "AXSize"
    static let focusedWindow = "AXFocusedWindow"
    static let mainWindow = "AXMainWindow"
    static let minimized = "AXMinimized"
    static let subrole = "AXSubrole"
    static let role = "AXRole"
    static let parent = "AXParent"
    static let window = "AXWindow"
    static let fullScreen = "AXFullScreen"
    static let enhancedUserInterface = "AXEnhancedUserInterface"
    static let raise = "AXRaise"

    static func copy(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    /// De AX-fout van het lezen van een attribuut; `.invalidUIElement` betekent dat het element weg is.
    static func error(_ element: AXUIElement, _ attribute: String) -> AXError {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    }

    static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = copy(element, attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        copy(element, attribute) as? String
    }

    static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        (copy(element, attribute) as? NSNumber)?.boolValue
    }

    static func point(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        guard let value = copy(element, attribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(value as! AXValue, .cgPoint, &point) ? point : nil
    }

    static func size(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        guard let value = copy(element, attribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(value as! AXValue, .cgSize, &size) ? size : nil
    }

    static func isSettable(_ element: AXUIElement, _ attribute: String) -> Bool {
        var settable: DarwinBoolean = false
        return AXUIElementIsAttributeSettable(element, attribute as CFString, &settable) == .success && settable.boolValue
    }

    @discardableResult
    static func set(_ element: AXUIElement, _ attribute: String, point: CGPoint) -> Bool {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else { return false }
        return AXUIElementSetAttributeValue(element, attribute as CFString, value) == .success
    }

    @discardableResult
    static func set(_ element: AXUIElement, _ attribute: String, size: CGSize) -> Bool {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return false }
        return AXUIElementSetAttributeValue(element, attribute as CFString, value) == .success
    }

    @discardableResult
    static func set(_ element: AXUIElement, _ attribute: String, bool: Bool) -> Bool {
        AXUIElementSetAttributeValue(element, attribute as CFString, NSNumber(value: bool)) == .success
    }
}
