import Foundation
import Testing
@testable import RasterCore

struct CommandMigrationTests {
    /// Eén oud commando als JSON, in het formaat van fase 1–5.
    private static func old(
        _ id: String, _ name: String, group: String, landscape: String? = nil, portrait: String? = nil,
        special: String? = nil, zones: (String, String)? = nil, key: Int? = nil, modifiers: Int = 6144,
        portraitName: String? = nil, enabled: Bool = true, inMenuBar: Bool = true, inZoomButtonMenu: Bool = true
    ) -> String {
        let action = special.map { #"{"special":{"_0":"\#($0)"}}"# }
            ?? #"{"area":{"landscape":{"segments":[\#(landscape!)]},"portrait":{"segments":[\#(portrait!)]}}}"#
        var fields = [#""id":"\#(id)""#, #""name":"\#(name)""#, #""group":"\#(group)""#, #""action":\#(action)"#,
                      #""enabled":\#(enabled)"#, #""inMenuBar":\#(inMenuBar)"#, #""inZoomButtonMenu":\#(inZoomButtonMenu)"#]
        if let zones { fields.append(#""dragZones":{"landscape":{"segments":[\#(zones.0)]},"portrait":{"segments":[\#(zones.1)]}}"#) }
        if let key { fields.append(#""shortcut":{"keyCode":\#(key),"modifiers":\#(modifiers)}"#) }
        if let portraitName { fields.append(#""portraitName":"\#(portraitName)""#) }
        return "{" + fields.joined(separator: ",") + "}"
    }

    private static func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int) -> String {
        #"{"x":\#(x),"y":\#(y),"width":\#(w),"height":\#(h)}"#
    }

    private static func file(_ commands: [String], layout: String? = nil) -> Data {
        var text = #"{"version":1,"commands":["# + commands.joined(separator: ",") + "]"
        if let layout { text += #","layout":"# + layout }
        return Data((text + "}").utf8)
    }

    @Test func untouchedDefaultsBecomeCurrentDefaults() throws {
        let data = Self.file([
            Self.old("left", "Links", group: "halves", landscape: Self.rect(0, 0, 12, 12), portrait: Self.rect(0, 0, 6, 24),
                     zones: (Self.rect(0, 3, 1, 6), Self.rect(1, 23, 5, 1)), key: 123),
            Self.old("leftThird", "Linkerderde", group: "thirds", landscape: Self.rect(0, 0, 8, 12), portrait: Self.rect(0, 0, 12, 8),
                     zones: (Self.rect(1, 11, 6, 1), Self.rect(0, 5, 1, 3) + "," + Self.rect(11, 5, 1, 3)), key: 2,
                     portraitName: "Bovenste derde"),
            Self.old("stayOnTop", "Altijd bovenop", group: "other", special: "stayOnTop", key: 126, modifiers: 6400),
        ])
        let lists = try CommandMigration.migrate(data)
        #expect(lists == CommandLists.standard)
    }

    @Test func renamedCommandKeepsNameInBothLists() throws {
        let data = Self.file([
            Self.old("leftThird", "Links smal", group: "thirds", landscape: Self.rect(0, 0, 8, 12), portrait: Self.rect(0, 0, 12, 8), key: 2),
        ])
        let lists = try CommandMigration.migrate(data)
        #expect(lists.command("leftThird")?.name == "Links smal")
        #expect(lists.command("vertical.topThird")?.name == "Links smal")
    }

    @Test func shortcutAndVisibilityGoToBothLists() throws {
        let data = Self.file([
            Self.old("maximize", "Maximaliseren", group: "other", landscape: Self.rect(0, 0, 24, 12), portrait: Self.rect(0, 0, 12, 24),
                     key: 46, modifiers: 6400, inZoomButtonMenu: false),
        ])
        let lists = try CommandMigration.migrate(data)
        for id in ["maximize", "vertical.maximize"] {
            let command = try #require(lists.command(id))
            #expect(command.shortcut == Shortcut(keyCode: 46, modifiers: 6400))
            #expect(command.inMenuBar)
            #expect(!command.inZoomButtonMenu)
        }
    }

    @Test func disabledCommandKeepsShortcutAndZonesButDoesNothing() throws {
        let data = Self.file([
            Self.old("right", "Rechts", group: "halves", landscape: Self.rect(12, 0, 12, 12), portrait: Self.rect(6, 0, 6, 24),
                     zones: (Self.rect(23, 2, 1, 8), Self.rect(6, 23, 5, 1)), key: 124, enabled: false),
        ])
        let command = try #require(try CommandMigration.migrate(data).command("right"))
        #expect(command.shortcut == Shortcut(keyCode: 124, modifiers: 6144))
        #expect(command.dragZones == GridArea(GridRect(23, 2, 1, 8)))
        #expect(!command.shortcutEnabled && !command.dragZonesEnabled && !command.inMenuBar && !command.inZoomButtonMenu)
    }

    @Test func customCommandGoesToBothListsWithItsOwnAreas() throws {
        let id = "5A0E7B3C-0000-4000-8000-000000000001"
        let data = Self.file([
            Self.old(id, "Mijn vak", group: "custom", landscape: Self.rect(6, 3, 12, 6), portrait: Self.rect(3, 6, 6, 12),
                     zones: (Self.rect(0, 0, 1, 1), ""), key: 0),
        ])
        let lists = try CommandMigration.migrate(data)
        let horizontal = try #require(lists.horizontal.command(id))
        let vertical = try #require(lists.vertical.command("vertical." + id))
        #expect(horizontal.area == GridArea(GridRect(6, 3, 12, 6)) && horizontal.dragZones == GridArea(GridRect(0, 0, 1, 1)))
        #expect(vertical.area == GridArea(GridRect(3, 6, 6, 12)) && vertical.dragZones == GridArea(segments: []))
        #expect(horizontal.name == "Mijn vak" && vertical.name == "Mijn vak" && vertical.axis == .vertical)
        #expect(horizontal.shortcut == Shortcut(keyCode: 0, modifiers: 6144) && vertical.shortcut == horizontal.shortcut)
    }

    @Test func layoutComesBackInBothLists() throws {
        let id = "5A0E7B3C-0000-4000-8000-000000000002"
        let data = Self.file([
            Self.old("left", "Links", group: "halves", landscape: Self.rect(0, 0, 12, 12), portrait: Self.rect(0, 0, 6, 24), key: 123),
            Self.old("leftThird", "Linkerderde", group: "thirds", landscape: Self.rect(0, 0, 8, 12), portrait: Self.rect(0, 0, 12, 8), key: 2),
            Self.old(id, "Mijn vak", group: "custom", landscape: Self.rect(6, 3, 12, 6), portrait: Self.rect(3, 6, 6, 12)),
        ], layout: #"{"entries":[{"kind":"command","id":"\#(id)"},{"kind":"divider","id":"divider-9"},{"kind":"command","id":"leftThird"},{"kind":"command","id":"left"}]}"#)
        let lists = try CommandMigration.migrate(data)
        #expect(Array(lists.horizontal.layout.entries.prefix(4)) == [
            .command(id), MenuEntry(kind: .divider, id: "divider-9"), .command("leftThird"), .command("left"),
        ])
        #expect(Array(lists.vertical.layout.entries.prefix(4)) == [
            .command("vertical." + id), MenuEntry(kind: .divider, id: "divider-9"), .command("vertical.topThird"), .command("vertical.left"),
        ])
    }

    @Test func customizedStayOnTopStays() throws {
        let data = Self.file([
            Self.old("stayOnTop", "Altijd bovenop", group: "other", special: "stayOnTop", key: 35, modifiers: 6400),
        ])
        let lists = try CommandMigration.migrate(data)
        #expect(lists.command("stayOnTop")?.shortcut == Shortcut(keyCode: 35, modifiers: 6400))
        #expect(lists.command("stayOnTop")?.name == "Stay On Top")
        #expect(lists.command("vertical.stayOnTop") != nil)
    }

    @Test func storeMigratesBacksUpAndSavesVersion2() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "commands.json")
        let original = Self.file([
            Self.old("left", "Links", group: "halves", landscape: Self.rect(0, 0, 12, 12), portrait: Self.rect(0, 0, 6, 24), key: 33),
        ])
        try original.write(to: url)
        let store = CommandStore(fileURL: url)
        #expect(!store.isReadOnly)
        #expect(store.command("left")?.shortcut == Shortcut(keyCode: 33, modifiers: 6144))
        #expect(try Data(contentsOf: directory.appending(path: "commands-v1.json.bak")) == original)
        #expect(try String(contentsOf: url, encoding: .utf8).contains(#""version" : 2"#))
        #expect(CommandStore(fileURL: url).lists == store.lists)
    }

    @Test func incompleteSideOfAMigratedCustomCommandIsDropped() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "commands.json")
        // Eigen commando met alleen een staand gebied: na de migratie alleen in Vertical.
        let id = "5A0E7B3C-0000-4000-8000-000000000003"
        try Self.file([
            Self.old(id, "Alleen staand", group: "custom", landscape: "", portrait: Self.rect(0, 0, 6, 6)),
        ]).write(to: url)
        let store = CommandStore(fileURL: url)
        #expect(store.command(id) == nil)
        #expect(store.command("vertical." + id)?.axis == .vertical)
        #expect(store.commands(for: .horizontal) == DefaultCommands.horizontal)
    }

    @Test func unreadableCommandCostsOnlyThatCommand() throws {
        var data = String(decoding: Self.file([
            Self.old("left", "Links", group: "halves", landscape: Self.rect(0, 0, 12, 12), portrait: Self.rect(0, 0, 6, 24), key: 33),
        ]), as: UTF8.self)
        data = data.replacingOccurrences(of: #""commands":["#, with: #""commands":[{"id":"kapot"},"#)
        let lists = try CommandMigration.migrate(Data(data.utf8))
        #expect(lists.command("left")?.shortcut == Shortcut(keyCode: 33, modifiers: 6144))
        #expect(lists.command("vertical.left")?.shortcut == Shortcut(keyCode: 33, modifiers: 6144))
        #expect(lists.command("kapot") == nil)
    }

    @Test func unreadableLayoutGivesTheStandardOrder() throws {
        let data = Self.file([
            Self.old("left", "Links", group: "halves", landscape: Self.rect(0, 0, 12, 12), portrait: Self.rect(0, 0, 6, 24), key: 33),
        ], layout: "5")
        let lists = try CommandMigration.migrate(data)
        #expect(lists.horizontal.layout == CommandLists.standard.horizontal.layout)
        #expect(lists.vertical.layout == CommandLists.standard.vertical.layout)
        #expect(lists.command("left")?.shortcut == Shortcut(keyCode: 33, modifiers: 6144))
    }

    @Test func disabledStayOnTopIsDroppedEvenWhenCustomized() throws {
        let data = Self.file([
            Self.old("stayOnTop", "Bovenop", group: "other", special: "stayOnTop", key: 35, modifiers: 6400, enabled: false),
        ])
        let lists = try CommandMigration.migrate(data)
        #expect(lists.command("stayOnTop") == nil)
        #expect(lists.command("vertical.stayOnTop") == nil)
        #expect(lists == CommandLists.standard)
    }

    @Test func verticalIDsOfThirds() {
        #expect(CommandMigration.verticalID("leftThird") == "vertical.topThird")
        #expect(CommandMigration.verticalID("rightThird") == "vertical.bottomThird")
        #expect(CommandMigration.verticalID("leftTwoThirds") == "vertical.topTwoThirds")
        #expect(CommandMigration.verticalID("rightTwoThirds") == "vertical.bottomTwoThirds")
        #expect(CommandMigration.verticalID("centerThird") == "vertical.centerThird")
        #expect(CommandMigration.verticalID("ABC") == "vertical.ABC")
    }
}
