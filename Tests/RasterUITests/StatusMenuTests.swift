import AppKit
import Testing
@testable import RasterUI
import RasterCore

/// Opbouw van het menubalkmenu (`StatusMenu.entries`). Draait bij elke
/// `swift test` (geen `RASTER_RENDER` nodig).
@MainActor
struct StatusMenuTests {
    private static let terminal = StatusMenu.TargetApp(name: "Terminal", bundleID: "com.apple.Terminal", isExcluded: false)
    private static let own = "nl.jimlindenburg.raster"

    private static func entries(
        lists: CommandLists = .standard, axis: CommandAxis = .horizontal, trusted: Bool = true,
        canRestore: Bool = false, isPinned: Bool = false, app: StatusMenu.TargetApp? = terminal
    ) -> [StatusMenu.Entry] {
        StatusMenu.entries(lists: lists, axis: axis, trusted: trusted, canRestore: canRestore, isPinned: isPinned,
                           app: app, ownBundleID: own)
    }

    private static func dump(_ entries: [StatusMenu.Entry]) -> [String] { StatusMenu.outline(entries) }

    private static func items(_ entries: [StatusMenu.Entry]) -> [StatusMenu.Item] {
        entries.compactMap { entry in
            if case .item(let item) = entry { item } else { nil }
        }
    }

    private static func item(_ title: String, in entries: [StatusMenu.Entry]) -> StatusMenu.Item? {
        items(entries).first { $0.title == title }
    }

    /// Regel voor regel het standaardmenu: volgorde, titels, sneltoetsen, scheidingslijnen, Restore grijs.
    @Test func matchesDefaultMenu() {
        let expected = [
            "Left  ⌃⌥◀", "Right  ⌃⌥▶", "Top  ⌃⌥▲", "Bottom  ⌃⌥▼", "---",
            "Top Left  ⌃⌥U", "Top Right  ⌃⌥I", "Bottom Left  ⌃⌥J", "Bottom Right  ⌃⌥K", "---",
            "Left Third  ⌃⌥D", "Center Third  ⌃⌥F", "Right Third  ⌃⌥G", "---",
            "Left Two Thirds  ⌃⌥E", "Center Two Thirds  ⌃⌥R", "Right Two Thirds  ⌃⌥T", "---",
            "Next Display  ⌃⌥⌘▶", "Previous Display  ⌃⌥⌘◀", "---",
            "Maximize  ⌃⌥↩", "Center  ⌃⌥C", "Restore  ⌃⌥⌫  [grijs]", "---",
            "Settings…", "---",
            "Ignore “Terminal”", "---",
            "Help", "About Raster", "---",
            "Quit",
        ]
        #expect(Self.dump(Self.entries()) == expected)
    }

    @Test func everyItemHasAnIconAndAnAction() {
        for item in Self.items(Self.entries()) {
            #expect(item.icon != nil, "\(item.title)")
            #expect(item.action != nil, "\(item.title)")
        }
        let entries = Self.entries()
        #expect(Self.item("Left", in: entries)?.action == .command("left"))
        #expect(Self.item("Left", in: entries)?.keyEquivalent == "\u{F702}")
        #expect(Self.item("Settings…", in: entries)?.icon == .symbol(.settings))
        #expect(Self.item("Help", in: entries)?.action == .help)
        #expect(Self.item("About Raster", in: entries)?.action == .about)
        #expect(Self.item("Quit", in: entries)?.action == .quit)
    }

    /// Settings… en Quit hebben geen sneltoets.
    @Test func settingsAndQuitHaveNoShortcut() {
        let entries = Self.entries()
        for title in [L10n.menuItemSettingsTitle, L10n.menuItemQuitTitle] {
            let item = Self.item(title, in: entries)
            #expect(item?.shortcut == nil, "\(title)")
            #expect(item?.keyEquivalent == "", "\(title)")
        }
    }

    @Test func restoreFollowsCanRestore() {
        #expect(Self.item("Restore", in: Self.entries(canRestore: false))?.isEnabled == false)
        #expect(Self.item("Restore", in: Self.entries(canRestore: true))?.isEnabled == true)
    }

    /// Stay On Top (als het in de lijst staat) heeft een vinkje als het venster vastgepind is.
    @Test func stayOnTopIsCheckedWhenPinned() {
        var lists = CommandLists.standard
        lists.horizontal = CommandList(commands: DefaultCommands.horizontal + [DefaultCommands.stayOnTop(axis: .horizontal)])
        #expect(Self.item("Stay On Top", in: Self.entries(lists: lists, isPinned: true))?.isChecked == true)
        #expect(Self.item("Stay On Top", in: Self.entries(lists: lists, isPinned: false))?.isChecked == false)
        #expect(Self.item("Stay On Top", in: Self.entries(lists: lists, trusted: false, isPinned: true))?.isChecked == false)
        #expect(Self.items(Self.entries(lists: lists, isPinned: true)).filter(\.isChecked).count == 1)
    }

    @Test func ignoreAvailable() {
        let item = Self.item(L10n.ignore("Terminal"), in: Self.entries())
        #expect(item?.isEnabled == true)
        #expect(item?.action == .ignore("com.apple.Terminal"))
        #expect(item?.icon == .symbol(.ignore))
    }

    /// Al genegeerd: ✓ in de titel en geen vinkje; een klik haalt de app uit de lijst.
    @Test func ignoreAlreadyIgnored() {
        var app = Self.terminal
        app.isExcluded = true
        let item = Self.item("✓ Ignore “Terminal”", in: Self.entries(app: app))
        #expect(item?.isEnabled == true)
        #expect(item?.isChecked == false)
        #expect(item?.action == .unignore("com.apple.Terminal"))
    }

    /// Zonder bundle-id of voor Raster zelf: "can’t be ignored", uitgeschakeld.
    @Test func ignoreNotSupported() {
        for app in [StatusMenu.TargetApp(name: "tool", bundleID: nil, isExcluded: false),
                    StatusMenu.TargetApp(name: "Raster", bundleID: Self.own, isExcluded: false)] {
            let item = Self.item(L10n.notSupported(app.name), in: Self.entries(app: app))
            #expect(item?.isEnabled == false, "\(app.name)")
            #expect(item?.action == nil, "\(app.name)")
            #expect(item?.icon == .symbol(.ignore), "\(app.name)")
        }
    }

    /// Geen app: het negeer-item valt weg met zijn scheidingslijn; nergens twee scheidingslijnen achter elkaar.
    @Test func noAppNoIgnoreItem() {
        let lines = Self.dump(Self.entries(app: nil))
        #expect(Array(lines.suffix(7)) == ["---", "Settings…", "---", "Help", "About Raster", "---", "Quit"])
        #expect(!Self.items(Self.entries(app: nil)).contains { $0.icon == .symbol(.ignore) })
        for (a, b) in zip(lines, lines.dropFirst()) {
            #expect(!(a == "---" && b == "---"))
        }
        #expect(lines.first != "---" && lines.last != "---")
    }

    /// Zonder toestemming: de melding (grijs, zonder actie) en Grant Access… bovenaan, de commando's grijs.
    @Test func notAuthorized() {
        let entries = Self.entries(trusted: false, canRestore: true)
        let lines = Self.dump(entries)
        #expect(Array(lines.prefix(4)) == ["No Permission to Manage Windows  [grijs]  [geen icoon]",
                                           "Grant Access…  [geen icoon]", "---", "Left  ⌃⌥◀  [grijs]"])
        #expect(Self.item(L10n.menuItemAuthorizeTitle, in: entries)?.action == .authorize)
        #expect(Self.item(L10n.menuItemNotAuthorizedTitle, in: entries)?.action == nil)
        for item in Self.items(entries) {
            if case .command = item.action { #expect(!item.isEnabled, "\(item.title)") }
        }
        #expect(Self.item("Settings…", in: entries)?.isEnabled == true)
        #expect(Self.item("Quit", in: entries)?.isEnabled == true)
    }

    /// De lijst van de as: Vertical toont de commando's van Vertical; verborgen commando's ontbreken.
    @Test func usesListOfAxisAndInMenuBar() {
        let vertical = Self.items(Self.entries(axis: .vertical)).compactMap { item -> String? in
            if case .command(let id) = item.action { id } else { nil }
        }
        #expect(vertical == CommandLists.standard.vertical.menuItems(include: { $0.inMenuBar }).compactMap { item in
            if case .command(let command) = item { command.id } else { nil }
        })
        #expect(vertical.allSatisfy { $0.hasPrefix("vertical.") })

        var lists = CommandLists.standard
        lists.horizontal.commands[0].inMenuBar = false
        let hidden = lists.horizontal.commands[0].id
        #expect(!Self.items(Self.entries(lists: lists)).contains { $0.action == .command(hidden) })
    }
}
