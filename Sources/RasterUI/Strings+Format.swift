import Foundation

/// Teksten met een invulplek; de opmaak zelf staat in `Strings.swift`.
extension L10n {
    /// `Ignore “%@“` met de naam van de app.
    static func ignore(_ app: String) -> String { String(format: menuItemBlacklistAvailableTitle, app) }
    /// `✓ Ignore “%@“`: de app wordt al genegeerd.
    static func ignored(_ app: String) -> String { String(format: menuItemBlacklistUserTitle, app) }
    /// `“%@“ not supported`.
    static func notSupported(_ app: String) -> String { String(format: menuItemBlacklistNotSupportedTitle, app) }
}
