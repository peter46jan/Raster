import AppKit
import RasterCore
import RasterSystem

/// Menu met commando's naast de groene knop; een keuze werkt op het venster van die knop.
@MainActor
final class ZoomButtonMenu: NSObject {
    private let windows: WindowController
    private let lists: () -> CommandLists
    private let style: () -> ZoomMenuStyle
    private let panel = HorizontalCommandPanel()
    /// Alleen voor het blokkerende `NSMenu`; een nieuw horizontaal paneel vervangt het vorige.
    private var isShowing = false

    /// Wat een menu-item nodig heeft om zijn commando uit te voeren: het commando en het venster van die knop.
    private final class Choice {
        let commandID: String
        let window: AXWindow

        init(commandID: String, window: AXWindow) {
            self.commandID = commandID
            self.window = window
        }
    }

    init(
        windows: WindowController,
        lists: @escaping () -> CommandLists,
        style: @escaping () -> ZoomMenuStyle
    ) {
        self.windows = windows
        self.lists = lists
        self.style = style
    }

    /// `axPoint` is de cursorpositie in AX-coördinaten. Het standaard- en compacte menu blokkeren tot ze sluiten;
    /// het horizontale paneel komt meteen terug en vervangt een paneel dat nog open is.
    func show(for window: AXWindow, at axPoint: CGPoint) {
        // Een open paneel wordt vervangen (de muis rust op een andere knop); alleen het blokkerende menu wacht.
        guard !isShowing else { return }
        // De lijst van het scherm van dit venster: Horizontal of Vertical.
        let axis = CommandAxis.for(windows.grid(for: window) ?? .landscape)
        let items = lists()[axis].menuItems(include: { $0.inZoomButtonMenu })
        guard !items.isEmpty, let mainHeight = NSScreen.screens.first?.frame.height else { return }
        let pinned = windows.pins.isPinned(window)
        let style = style()
        if style == .horizontal {
            showPanel(items: items, window: window, pinned: pinned, at: axPoint)
            return
        }
        panel.close()
        isShowing = true
        defer { isShowing = false }
        let compact = style == .compact
        let menu = NSMenu()
        menu.autoenablesItems = false
        if compact { menu.font = NSFont.menuFont(ofSize: NSFont.smallSystemFontSize) }
        for entry in items {
            guard case .command(let command) = entry else {
                menu.addItem(.separator())
                continue
            }
            let item = NSMenuItem(title: command.menuTitle, action: #selector(run(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = Choice(commandID: command.id, window: window)
            item.image = RasterIcons.command(command, scale: compact ? 0.6 : 0.8)
            if command.action == .special(.stayOnTop) { item.state = pinned ? .on : .off }
            if !compact, let shortcut = command.activeShortcut, let key = shortcut.keyEquivalent {
                item.keyEquivalent = key
                item.keyEquivalentModifierMask = shortcut.modifierFlags
            }
            menu.addItem(item)
        }
        // Net onder de cursor, in Cocoa-coördinaten.
        menu.popUp(positioning: nil, at: NSPoint(x: axPoint.x, y: mainHeight - axPoint.y - 8), in: nil)
    }

    /// Een rij per deel tussen scheidingslijnen; een keuze werkt op het venster van de knop.
    private func showPanel(items: [MenuItem], window: AXWindow, pinned: Bool, at axPoint: CGPoint) {
        var rows: [[Command]] = [[]]
        for item in items {
            switch item {
            case .divider: rows.append([])
            case .command(let command): rows[rows.count - 1].append(command)
            }
        }
        let pinnedIDs = pinned ? Set(items.compactMap { item -> String? in
            guard case .command(let command) = item, command.action == .special(.stayOnTop) else { return nil }
            return command.id
        }) : []
        panel.show(rows: rows, pinnedIDs: pinnedIDs, at: axPoint) { [weak self] id in
            guard let self, let command = lists().command(id) else { return }
            windows.perform(command, on: window)
        }
    }

    /// Of het horizontale paneel open is.
    var isPanelOpen: Bool { panel.isOpen }

    /// Sluit een open horizontaal paneel (monitor gestopt, toestemming kwijt).
    func close() {
        panel.close()
    }

    @objc private func run(_ sender: NSMenuItem) {
        guard let choice = sender.representedObject as? Choice,
              let command = lists().command(choice.commandID) else { return }
        windows.perform(command, on: choice.window)
    }
}
