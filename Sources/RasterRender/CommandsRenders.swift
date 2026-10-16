import AppKit
import RasterCore
import RasterUI

/// Paneel Commands, lijstkolom (taak 9): het hele venster met "Left" gekozen, als `commands-…` (naast
/// `referentie-commands.png` te leggen met een verschuiving van (−6, −3) pt). Verder, alleen actief en @2x:
/// - `commands-hover-…`: de muis boven "Top" (id "up", rijknoppen) en boven het gekozen "Left" in een tweede opname;
/// - `commands-vertical-…`: Horizontal ingeklapt, Vertical uitgeklapt met "Top Third" gekozen;
/// - `commands-divider-hover-…`: de muis boven de eerste scheidingsrij.
@MainActor
func renderCommands(to directory: String) throws {
    Render.directory = directory
    try SettingsRenders.renderWindow(panel: .commands, name: "commands", commandID: "left")

    try withPreview(hovered: "up") {
        try SettingsRenders.renderWindow(panel: .commands, name: "commands-hover", commandID: "left",
                                         actives: [true], scales: [2])
    }
    try withPreview(hovered: "left") {
        try SettingsRenders.renderWindow(panel: .commands, name: "commands-hover-selected", commandID: "left",
                                         actives: [true], scales: [2])
    }
    try withPreview(hovered: "divider:horizontal:divider-1") {
        try SettingsRenders.renderWindow(panel: .commands, name: "commands-divider-hover", commandID: "left",
                                         actives: [true], scales: [2])
    }
    try withPreview(collapsed: [.horizontal]) {
        try SettingsRenders.renderWindow(panel: .commands, name: "commands-vertical", commandID: "vertical.topThird",
                                         actives: [true], scales: [2])
    }
}

/// Zet de render-toestand van de lijstkolom voor de duur van `body`.
@MainActor
private func withPreview(hovered: String? = nil, collapsed: Set<CommandAxis> = [], _ body: () throws -> Void) rethrows {
    CommandListPreview.hoveredRowID = hovered
    CommandListPreview.collapsed = collapsed
    defer {
        CommandListPreview.hoveredRowID = nil
        CommandListPreview.collapsed = []
    }
    try body()
}
