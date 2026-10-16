import AppKit

/// Hoofdmenu van een app zonder Dock-icoon: niet zichtbaar, maar de sneltoetsen (⌘C, ⌘V, ⌘W …)
/// werken zo wel in het instellingenvenster.
@MainActor
enum MainMenu {
    static func make(openSettings: Selector, target: AnyObject) -> NSMenu {
        let main = NSMenu()

        let appMenu = NSMenu()
        let settings = appMenu.addItem(withTitle: L10n.menuItemPreferencesTitle, action: openSettings, keyEquivalent: ",")
        settings.target = target
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L10n.menuItemQuitTitle, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        add(appMenu, titled: L10n.menuAppTitle, to: main)

        // Edit- en Window-menu: standaardteksten van macOS.
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        add(editMenu, titled: "Edit", to: main)

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        add(windowMenu, titled: "Window", to: main)

        return main
    }

    private static func add(_ submenu: NSMenu, titled title: String, to main: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        main.addItem(item)
    }
}
