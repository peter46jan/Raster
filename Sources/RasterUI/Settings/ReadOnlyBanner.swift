import SwiftUI

/// Melding boven de commando's als ze niet bewaard kunnen worden.
struct ReadOnlyBanner: View {
    let model: CommandsModel

    var body: some View {
        switch model.readOnlyReason {
        case .newerFormat:
            Label(L10n.readOnlyNewerFormat, systemImage: "exclamationmark.triangle")
        case .unreadable:
            Label(L10n.readOnlyUnreadable, systemImage: "exclamationmark.triangle")
        case .backupFailed:
            Label(L10n.readOnlyBackupFailed, systemImage: "exclamationmark.triangle")
        case nil:
            EmptyView()
        }
    }
}

// Teksten van de melding boven de lijst als de commando's alleen te lezen zijn.
extension L10n {
    static let readOnlyNewerFormat = "Saved by a newer version of Raster. Changes won’t be saved."
    static let readOnlyUnreadable = "Raster can’t read the commands file. Changes won’t be saved."
    static let readOnlyBackupFailed = "Raster can’t back up the commands file. Changes won’t be saved."
}
