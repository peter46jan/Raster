import AppKit
import RasterCore
import RasterSystem

/// Het menubalkmenu: commando's van de lijst van het actieve venster, Settings…, het
/// negeer-item voor de voorste app, Help, About… en Quit.
@MainActor
package final class StatusMenu: NSObject, NSMenuDelegate {
    private static let helpURL = URL(string: "https://github.com/peter46jan/Raster")!

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let windows: WindowController
    private let lists: () -> CommandLists
    private let settings: AppSettings
    private let onRequestPermission: () -> Void
    private let onOpenSettings: () -> Void
    /// Wat elk item doet, op `tag` van het menu-item; opnieuw gevuld bij elke keer openen.
    private var actions: [Action] = []
    /// Het venster waarop de commando's werken: bepaald bij het openen, zodat een klik geen nieuwe AX-ronde kost.
    private var menuWindow: AXWindow?

    init(
        windows: WindowController,
        lists: @escaping () -> CommandLists,
        settings: AppSettings,
        onRequestPermission: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.windows = windows
        self.lists = lists
        self.settings = settings
        self.onRequestPermission = onRequestPermission
        self.onOpenSettings = onOpenSettings
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        // Ook zonder toestemming hetzelfde icoon; de menu-items melden het.
        statusItem.button?.image = RasterIcons.statusBar
        statusItem.button?.setAccessibilityLabel(L10n.aboutWindowTextTitle)
    }

    /// Menubalkicoon verbergen; opnieuw openen van de app toont dan het instellingenvenster.
    func setIconHidden(_ hidden: Bool) {
        statusItem.isVisible = !hidden
    }

    package func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let trusted = Permissions.accessibility
        // Eén AX-ronde: het actieve venster met zijn raster; vastgepind en herstellen volgen zonder nieuwe vraag.
        let focused = trusted ? windows.focusedWindowAndGrid() : nil
        menuWindow = focused?.window
        // De lijst van het scherm van het actieve venster: Horizontal of Vertical.
        let axis = CommandAxis.for(focused?.grid ?? .landscape)
        let app = windows.targetApplication.map { app in
            let bundleID = app.bundleIdentifier
            let name = app.localizedName ?? bundleID.map(appName) ?? app.executableURL?.lastPathComponent ?? ""
            return TargetApp(name: name, bundleID: bundleID, isExcluded: bundleID.map(settings.isExcluded) ?? false)
        }
        let entries = Self.entries(
            lists: lists(), axis: axis, trusted: trusted,
            canRestore: focused.map { windows.canRestore($0.window) } ?? false,
            isPinned: focused.map { windows.pins.isPinned($0.window) } ?? false,
            app: app, ownBundleID: Bundle.main.bundleIdentifier
        )
        actions = []
        for entry in entries {
            guard case .item(let item) = entry else {
                menu.addItem(.separator())
                continue
            }
            menu.addItem(menuItem(item, axis: axis))
        }
    }

    private func menuItem(_ item: Item, axis: CommandAxis) -> NSMenuItem {
        let menuItem = NSMenuItem(title: item.title, action: nil, keyEquivalent: item.keyEquivalent)
        if let shortcut = item.shortcut { menuItem.keyEquivalentModifierMask = shortcut.modifierFlags }
        menuItem.isEnabled = item.isEnabled
        menuItem.state = item.isChecked ? .on : .off
        switch item.icon {
        case .command(let command): menuItem.image = RasterIcons.command(command, scale: 0.8)
        case .symbol(let symbol): menuItem.image = RasterIcons.symbol(symbol, axis: axis, scale: 0.8)
        case nil: break
        }
        if let action = item.action {
            menuItem.target = self
            menuItem.action = #selector(choose(_:))
            menuItem.tag = actions.count
            actions.append(action)
        }
        return menuItem
    }

    @objc private func choose(_ sender: NSMenuItem) {
        guard actions.indices.contains(sender.tag) else { return }
        switch actions[sender.tag] {
        case .authorize:
            onRequestPermission()
        case .command(let id):
            guard let command = lists().command(id), let window = menuWindow else { return }
            windows.perform(command, on: window)
        case .settings:
            onOpenSettings()
        case .ignore(let bundleID):
            settings.addExcluded(bundleID)
        case .unignore(let bundleID):
            settings.removeExcluded(bundleID)
        case .help:
            NSWorkspace.shared.open(Self.helpURL)
        case .about:
            showAbout()
        case .quit:
            NSApp.terminate(nil)
        }
    }

    /// Versie komt uit `CFBundleShortVersionString` van de bundle; daaronder alleen het copyright (MIT-licentie).
    private func showAbout() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: L10n.aboutWindowTextTitle,
            .credits: NSAttributedString(string: ""),
            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "© 2026 Jim Lindenburg",
        ])
    }
}

// MARK: - Opbouw

extension StatusMenu {
    /// Wat een menu-item doet.
    enum Action: Equatable {
        case authorize
        case command(String)
        case settings
        case ignore(String)
        case unignore(String)
        case help
        case about
        case quit
    }

    /// Icoon van een menu-item; symbolen volgen de as van de lijst (Vertical staand).
    package enum Icon: Equatable {
        case command(Command)
        case symbol(RasterIcons.Symbol)
    }

    package struct Item: Equatable {
        package var title: String
        package var isEnabled = true
        package var icon: Icon?
        package var shortcut: Shortcut?
        /// Vinkje (`state = .on`); alleen voor Stay On Top op een vastgepind venster.
        package var isChecked = false
        /// nil: alleen tekst (de melding "Not Authorized…").
        var action: Action?

        /// Teken voor `NSMenuItem.keyEquivalent`; leeg zonder (bekende) sneltoets.
        var keyEquivalent: String { shortcut?.keyEquivalent ?? "" }
    }

    package enum Entry: Equatable {
        case item(Item)
        case separator
    }

    /// De voorste app, voor het negeer-item.
    package struct TargetApp: Equatable {
        package var name: String
        package var bundleID: String?
        package var isExcluded: Bool

        package init(name: String, bundleID: String?, isExcluded: Bool) {
            self.name = name
            self.bundleID = bundleID
            self.isExcluded = isExcluded
        }
    }

    /// De opbouw van het menu, zonder AppKit-toestand (testbaar):
    /// - zonder toestemming bovenaan "Not Authorized…" (uitgeschakeld) en "Authorize…", en de commando's grijs;
    /// - de commando's van de lijst van `axis` die in de menubalk horen, met hun scheidingslijnen en actieve sneltoets;
    ///   Restore grijs als er niets te herstellen is, Stay On Top met vinkje als het venster vastgepind is;
    /// - Settings… (zonder sneltoets);
    /// - het negeer-item voor `app` (weg zonder app);
    /// - Help en About…; Quit (zonder sneltoets).
    package static func entries(
        lists: CommandLists, axis: CommandAxis, trusted: Bool, canRestore: Bool, isPinned: Bool,
        app: TargetApp?, ownBundleID: String?
    ) -> [Entry] {
        var entries: [Entry] = []
        if !trusted {
            entries.append(.item(Item(title: L10n.menuItemNotAuthorizedTitle, isEnabled: false)))
            entries.append(.item(Item(title: L10n.menuItemAuthorizeTitle, action: .authorize)))
            entries.append(.separator)
        }
        for menuItem in lists[axis].menuItems(include: { $0.inMenuBar }) {
            guard case .command(let command) = menuItem else {
                entries.append(.separator)
                continue
            }
            var item = Item(title: command.menuTitle, isEnabled: trusted, icon: .command(command),
                            shortcut: command.activeShortcut, action: .command(command.id))
            switch command.action {
            case .special(.restore): item.isEnabled = trusted && canRestore
            case .special(.stayOnTop): item.isChecked = trusted && isPinned
            default: break
            }
            entries.append(.item(item))
        }
        entries.append(.separator)
        entries.append(.item(Item(title: L10n.menuItemSettingsTitle, icon: .symbol(.settings), action: .settings)))
        if let app {
            entries.append(.separator)
            entries.append(.item(ignoreItem(for: app, ownBundleID: ownBundleID)))
        }
        entries.append(.separator)
        entries.append(.item(Item(title: L10n.menuItemHelpTitle, icon: .symbol(.help), action: .help)))
        entries.append(.item(Item(title: L10n.menuItemAboutTitle, icon: .symbol(.about), action: .about)))
        entries.append(.separator)
        entries.append(.item(Item(title: L10n.menuItemQuitTitle, icon: .symbol(.quit), action: .quit)))
        return entries
    }

    /// Negeren kan alleen voor een app met bundle-id die niet Raster zelf is; al genegeerd staat er een ✓ in de
    /// titel (geen vinkje) en haalt een klik hem uit de lijst.
    private static func ignoreItem(for app: TargetApp, ownBundleID: String?) -> Item {
        guard let bundleID = app.bundleID, !bundleID.isEmpty, bundleID != ownBundleID else {
            return Item(title: L10n.notSupported(app.name), isEnabled: false, icon: .symbol(.ignore))
        }
        if app.isExcluded {
            return Item(title: L10n.ignored(app.name), icon: .symbol(.ignore), action: .unignore(bundleID))
        }
        return Item(title: L10n.ignore(app.name), icon: .symbol(.ignore), action: .ignore(bundleID))
    }
}

extension StatusMenu {
    /// Het menu als tekst, één regel per item: titel, sneltoets zoals het menu hem toont, en `[grijs]`, `[✓]` of
    /// `[geen icoon]` waar dat geldt; `---` voor een scheidingslijn. Voor de tests en `raster-render`.
    package static func outline(_ entries: [Entry]) -> [String] {
        entries.map { entry in
            guard case .item(let item) = entry else { return "---" }
            var line = item.title
            if let shortcut = item.shortcut { line += "  " + shortcut.displayString }
            if !item.isEnabled { line += "  [grijs]" }
            if item.isChecked { line += "  [✓]" }
            if item.icon == nil { line += "  [geen icoon]" }
            return line
        }
    }
}
