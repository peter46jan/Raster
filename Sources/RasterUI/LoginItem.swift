import Foundation
import Observation
import ServiceManagement

/// Starten bij inloggen via SMAppService (werkt het best als Raster.app in /Applications of ~/Applications staat).
@MainActor
enum LoginItem {
    static var status: SMAppService.Status { SMAppService.mainApp.status }

    static func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Raster: starten bij inloggen niet aangepast: %@", String(describing: error))
        }
    }

    static func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

/// Observeerbare stand van "Starten bij inloggen", zodat menu en instellingen gelijk lopen. De status kan
/// buiten Raster veranderen (Systeeminstellingen), dus `refresh()` bij openen van het menu, het instellingenvenster
/// en bij het actief worden van de app.
@MainActor
@Observable
package final class LoginItemState {
    private(set) var status = LoginItem.status

    package init() {}

    /// Ook een aanvraag die nog op goedkeuring wacht telt als aan, zodat die weer ingetrokken kan worden.
    var isOn: Bool { status == .enabled || status == .requiresApproval }
    var needsApproval: Bool { status == .requiresApproval }

    func refresh() {
        status = LoginItem.status
    }

    func toggle() {
        LoginItem.set(!isOn)
        refresh()
    }
}
