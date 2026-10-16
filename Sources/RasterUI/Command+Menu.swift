import RasterCore

extension Command {
    /// Titel in menu's en lijsten; een eigen commando zonder naam heet "Command".
    var menuTitle: String {
        name.isEmpty ? L10n.commandDefaultName : name
    }
}
