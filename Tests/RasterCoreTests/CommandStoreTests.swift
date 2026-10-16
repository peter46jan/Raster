import Foundation
import Testing
@testable import RasterCore

struct CommandStoreTests {
    let fileURL = FileManager.default.temporaryDirectory
        .appending(path: "RasterTests-\(UUID().uuidString)")
        .appending(path: "commands.json")

    @Test func missingFileGivesTheStandardLists() {
        let store = CommandStore(fileURL: fileURL)
        #expect(store.lists == .standard)
        #expect(!store.isReadOnly)
    }

    @Test func roundTripKeepsChanges() throws {
        var store = CommandStore(fileURL: fileURL)
        store.setShortcut(Shortcut(keyCode: 37, modifiers: Shortcut.control), for: "left")
        store.setName("Smal", for: "vertical.topThird")
        store.setInMenuBar(false, for: "right")
        store.setInZoomButtonMenu(false, for: "vertical.right")
        store.setShortcutEnabled(false, for: "up")
        store.setDragZonesEnabled(false, for: "vertical.up")
        store.setArea(GridArea(GridRect(2, 2, 10, 8)), for: "maximize")
        store.insertDivider(.vertical, at: 3)
        try store.save()
        let loaded = CommandStore(fileURL: fileURL)
        #expect(loaded.lists == store.lists)
        #expect(loaded.command("maximize")?.area == GridArea(GridRect(2, 2, 10, 8)))
        #expect(loaded.command("vertical.topThird")?.name == "Smal")
        #expect(loaded.layout(for: .vertical).entries[3].kind == .divider)
        #expect(loaded.layout(for: .horizontal) == MenuLayout.standard(for: DefaultCommands.horizontal))
    }

    @Test func fileIsVersionTwoWithBothLists() throws {
        try CommandStore(fileURL: fileURL).save()
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(text.contains(#""version" : 2"#))
        #expect(text.contains(#""horizontal""#))
        #expect(text.contains(#""vertical""#))
    }

    @Test func newerVersionGivesReadOnlyDefaults() throws {
        let raw = #"{"version": 3, "horizontal": {"commands": []}, "toekomst": true}"#
        try writeRaw(raw)
        let store = CommandStore(fileURL: fileURL)
        #expect(store.lists == .standard)
        #expect(store.isReadOnly)
        #expect(store.readOnlyReason == .newerFormat)
        #expect(try backupURLs().isEmpty)
        #expect(throws: CommandStore.Error.readOnly) { try store.save() }
        #expect(try String(contentsOf: fileURL, encoding: .utf8) == raw)
    }

    @Test func corruptFileIsBackedUp() throws {
        try writeRaw("{")
        #expect(CommandStore(fileURL: fileURL).lists == .standard)
        let backups = try backupURLs()
        #expect(backups.count == 1)
        #expect(try String(contentsOf: #require(backups.first), encoding: .utf8) == "{")
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func secondCorruptFileKeepsEarlierBackup() throws {
        try writeRaw("eerste")
        _ = CommandStore(fileURL: fileURL)
        try writeRaw("tweede")
        _ = CommandStore(fileURL: fileURL)
        let contents = try backupURLs().map { try String(contentsOf: $0, encoding: .utf8) }
        #expect(contents.sorted() == ["eerste", "tweede"])
    }

    @Test func undecodableCommandCostsOnlyThatCommand() throws {
        var store = CommandStore(fileURL: fileURL)
        let custom = store.addCustom(axis: .horizontal, name: "Goed")
        store.setArea(GridArea(GridRect(2, 2, 20, 8)), for: custom.id)
        try store.save()
        // Een kapot commando erbij in Horizontal.
        var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any])
        var horizontal = try #require(json["horizontal"] as? [String: Any])
        var commands = try #require(horizontal["commands"] as? [Any])
        commands.append(["id": "B", "name": "Kapot", "axis": "horizontal", "group": "custom", "action": ["special": "teleport"]])
        horizontal["commands"] = commands
        json["horizontal"] = horizontal
        try JSONSerialization.data(withJSONObject: json).write(to: fileURL)
        let original = try Data(contentsOf: fileURL)

        let loaded = CommandStore(fileURL: fileURL)
        #expect(loaded.commands(for: .horizontal).count == DefaultCommands.horizontal.count + 1)
        #expect(loaded.commands(for: .horizontal).last?.id == custom.id)
        #expect(loaded.command("B") == nil)
        #expect(loaded.lists.vertical == CommandLists.standard.vertical)
        // Er viel iets weg: eerst een back-up met het kapotte commando, dan pas overschrijven.
        #expect(!loaded.isReadOnly)
        let backups = try backupURLs()
        #expect(backups.count == 1)
        #expect(try Data(contentsOf: #require(backups.first)) == original)
        #expect(CommandStore(fileURL: fileURL).lists == loaded.lists)
        #expect(try backupURLs().count == 1)
    }

    @Test func unreadableLayoutIsBackedUp() throws {
        var store = CommandStore(fileURL: fileURL)
        store.setName("Smal", for: "vertical.topThird")
        try store.save()
        try editJSON { json in
            var vertical = try #require(json["vertical"] as? [String: Any])
            vertical["layout"] = 5
            json["vertical"] = vertical
        }
        let original = try Data(contentsOf: fileURL)
        let loaded = CommandStore(fileURL: fileURL)
        #expect(loaded.lists == store.lists)
        let backups = try backupURLs()
        #expect(backups.count == 1)
        #expect(try Data(contentsOf: #require(backups.first)) == original)
    }

    @Test func missingDefaultCommandIsAddedAtTheEnd() throws {
        try CommandStore(fileURL: fileURL).save()
        try editJSON { json in
            var horizontal = try #require(json["horizontal"] as? [String: Any])
            var commands = try #require(horizontal["commands"] as? [[String: Any]])
            commands.removeAll { $0["id"] as? String == "left" }
            horizontal["commands"] = commands
            horizontal["layout"] = nil
            json["horizontal"] = horizontal
        }
        let loaded = CommandStore(fileURL: fileURL)
        #expect(loaded.commands(for: .horizontal).count == DefaultCommands.horizontal.count)
        #expect(loaded.commands(for: .horizontal).last == DefaultCommands.command("left"))
        #expect(loaded.layout(for: .horizontal).entries.suffix(2).map(\.kind) == [.divider, .command])
        #expect(loaded.layout(for: .horizontal).entries.last == .command("left"))
    }

    @Test func listWithOnlyUnreadableCommandsBecomesTheStandardAgain() throws {
        try CommandStore(fileURL: fileURL).save()
        try editJSON { json in
            var horizontal = try #require(json["horizontal"] as? [String: Any])
            let count = try #require(horizontal["commands"] as? [Any]).count
            horizontal["commands"] = Array(repeating: ["kapot": true], count: count)
            json["horizontal"] = horizontal
        }
        let loaded = CommandStore(fileURL: fileURL)
        #expect(loaded.lists == .standard)
        #expect(try backupURLs().count == 1)
    }

    @Test func failedBackupMakesTheStoreReadOnly() throws {
        let directory = fileURL.deletingLastPathComponent()
        // Versie 1, een v2-bestand met een kapot commando en een onleesbaar bestand: zonder back-up nooit overschrijven.
        let damaged: () throws -> Void = {
            try CommandStore(fileURL: fileURL).save()
            try editJSON { json in
                var horizontal = try #require(json["horizontal"] as? [String: Any])
                var commands = try #require(horizontal["commands"] as? [Any])
                commands.append(["kapot": true])
                horizontal["commands"] = commands
                json["horizontal"] = horizontal
            }
        }
        let versionOne: () throws -> Void = { try writeRaw(#"{"version": 1, "commands": []}"#) }
        let corrupt: () throws -> Void = { try writeRaw("{") }
        for prepare in [versionOne, damaged, corrupt] {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
            try? FileManager.default.removeItem(at: directory)
            try prepare()
            let original = try Data(contentsOf: fileURL)
            try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
            defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path) }

            var store = CommandStore(fileURL: fileURL)
            #expect(store.isReadOnly)
            #expect(store.readOnlyReason == .backupFailed)
            store.setShortcut(nil, for: "left")
            #expect(throws: CommandStore.Error.readOnly) { try store.save() }
            #expect(try Data(contentsOf: fileURL) == original)
            #expect(try backupURLs().isEmpty)
        }
    }

    @Test func anUnreadableLayoutEntryIsSkippedAndTheRestKept() throws {
        try CommandStore(fileURL: fileURL).save()
        var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any])
        var vertical = try #require(json["vertical"] as? [String: Any])
        vertical["layout"] = ["entries": [
            ["kind": "command", "id": "vertical.right"],
            ["kind": "bogus", "id": "x"],
            ["id": "no-kind"],
            NSNull(),
            ["kind": "divider", "id": "mine"],
            ["kind": "command", "id": "vertical.left"],
        ]]
        json["vertical"] = vertical
        try JSONSerialization.data(withJSONObject: json).write(to: fileURL)
        let layout = CommandStore(fileURL: fileURL).layout(for: .vertical)
        #expect(Array(layout.entries.prefix(3)) == [.command("vertical.right"), MenuEntry(kind: .divider, id: "mine"), .command("vertical.left")])
        #expect(layout.entries.filter { $0.kind == .command }.count == DefaultCommands.vertical.count)
        #expect(try backupURLs().count == 1) // er vielen regels weg
    }

    @Test func addCustomGoesToItsAxisOnlyAndIncompleteCanBeDiscarded() {
        var store = CommandStore(fileURL: fileURL)
        let added = store.addCustom(axis: .vertical, name: "Command")
        #expect(added.axis == .vertical)
        #expect(added.group == .custom)
        #expect(added.shortcut == nil)
        #expect(added.area == GridArea(segments: []))
        #expect(added.dragZones == GridArea(segments: []))
        #expect(!added.isComplete)
        #expect(store.commands(for: .vertical).last == added)
        #expect(store.commands(for: .horizontal) == DefaultCommands.horizontal)
        #expect(store.layout(for: .vertical).entries.last == .command(added.id))
        store.discardIncomplete()
        #expect(store.command(added.id) == nil)
        #expect(store.lists == .standard)
    }

    /// `hasIncomplete` gebruikt hetzelfde criterium als het weggooien: alleen eigen commando's zonder gebied.
    @Test func hasIncompleteMatchesDiscarding() throws {
        var store = CommandStore(fileURL: fileURL)
        #expect(!store.lists.hasIncomplete)
        // Een standaardcommando met een leeg gebied telt niet (en wordt ook niet weggegooid).
        store.setArea(GridArea(segments: []), for: "left")
        #expect(!store.lists.hasIncomplete)
        let added = store.addCustom(axis: .vertical, name: "Leeg")
        #expect(store.lists.hasIncomplete)
        store.setArea(GridArea(GridRect(0, 0, 2, 2)), for: added.id)
        #expect(!store.lists.hasIncomplete)
        store.setArea(GridArea(segments: []), for: added.id)
        store.discardIncomplete()
        #expect(!store.lists.hasIncomplete)
        #expect(store.command("left") != nil)
    }

    @Test func incompleteCustomCommandIsDroppedWhenLoading() throws {
        var store = CommandStore(fileURL: fileURL)
        let incomplete = store.addCustom(axis: .horizontal, name: "Leeg")
        let complete = store.addCustom(axis: .horizontal, name: "Vol")
        store.setArea(GridArea(GridRect(0, 0, 4, 4)), for: complete.id)
        try store.save()
        let loaded = CommandStore(fileURL: fileURL)
        #expect(loaded.command(incomplete.id) == nil)
        #expect(loaded.command(complete.id) != nil)
        #expect(!loaded.layout(for: .horizontal).entries.contains(.command(incomplete.id)))
    }

    @Test func defaultCommandsCannotBeRemoved() {
        var store = CommandStore(fileURL: fileURL)
        #expect(!store.isRemovable("left"))
        #expect(!store.isRemovable("vertical.left"))
        #expect(!store.isRemovable("onbekend"))
        store.remove("left")
        #expect(store.lists == .standard)
        let custom = store.addCustom(axis: .horizontal, name: "Eigen")
        store.setArea(GridArea(GridRect(0, 0, 4, 4)), for: custom.id)
        #expect(store.isRemovable(custom.id))
        store.remove(custom.id)
        #expect(store.command(custom.id) == nil)
        #expect(!store.layout(for: .horizontal).entries.contains(.command(custom.id)))
        #expect(store.lists == .standard)
    }

    @Test func emptyNameRestoresTheDefaultNameButNotForCustomCommands() {
        var store = CommandStore(fileURL: fileURL)
        store.setName("X", for: "vertical.topThird")
        #expect(store.command("vertical.topThird")?.name == "X")
        store.setName("  ", for: "vertical.topThird")
        #expect(store.command("vertical.topThird")?.name == "Top Third")
        let custom = store.addCustom(axis: .horizontal, name: "Eigen")
        store.setName(" Smal ", for: custom.id)
        #expect(store.command(custom.id)?.name == "Smal")
        store.setName("", for: custom.id)
        #expect(store.command(custom.id)?.name == "Smal")
    }

    @Test func dragZoneOfADefaultCommandCanBeRemoved() {
        var store = CommandStore(fileURL: fileURL)
        store.removeDragZone(at: GridCell(column: 0, row: 4), from: "left")
        #expect(store.command("left")?.dragZones == GridArea(segments: []))
        #expect(store.lists.vertical == CommandLists.standard.vertical)
        store.removeDragZone(at: GridCell(column: 0, row: 0), from: "center") // zonder zones: niets
        #expect(store.command("center") == DefaultCommands.command("center"))
    }

    @Test func resetAllGivesTheStandardLists() {
        var store = CommandStore(fileURL: fileURL)
        store.addCustom(axis: .vertical, name: "Eigen")
        store.setShortcut(nil, for: "left")
        store.insertDivider(.horizontal, at: 0)
        store.resetAll()
        #expect(store.lists == .standard)
    }

    @Test func specialCommandsGetNoDragZonesOrArea() {
        var store = CommandStore(fileURL: fileURL)
        store.setDragZones(GridArea(GridRect(0, 0, 1, 1)), for: "center")
        store.setArea(GridArea(GridRect(0, 0, 1, 1)), for: "center")
        #expect(store.command("center") == DefaultCommands.command("center"))
        store.setDragZones(GridArea(GridRect(0, 0, 1, 1)), for: "vertical.left")
        #expect(store.command("vertical.left")?.dragZones == GridArea(GridRect(0, 0, 1, 1)))
    }

    @Test func layoutCanBeEditedPerAxis() throws {
        var store = CommandStore(fileURL: fileURL)
        store.moveLayoutEntries(.horizontal, fromOffsets: IndexSet(integer: 1), toOffset: 0)
        #expect(store.layout(for: .horizontal).entries.prefix(2).map(\.id) == ["right", "left"])
        store.insertDivider(.vertical, at: store.layout(for: .vertical).entries.count)
        let divider = try #require(store.layout(for: .vertical).entries.last)
        #expect(divider.kind == .divider)
        try store.save()
        #expect(CommandStore(fileURL: fileURL).lists == store.lists)
        store.removeDivider(.vertical, id: divider.id)
        #expect(store.lists.vertical == CommandLists.standard.vertical)
    }

    @Test func versionOneFileWithoutVersionNumberIsMigrated() throws {
        let raw = #"{"commands": []}"#
        try writeRaw(raw)
        let store = CommandStore(fileURL: fileURL)
        #expect(!store.isReadOnly)
        #expect(store.lists == .standard)
        #expect(try String(contentsOf: fileURL, encoding: .utf8).contains(#""version" : 2"#))
        let backup = fileURL.deletingLastPathComponent().appending(path: "commands-v1.json.bak")
        #expect(try Data(contentsOf: backup) == Data(raw.utf8))
        #expect(try backupURLs().map(\.lastPathComponent) == ["commands-v1.json.bak"])
    }

    @Test func existingVersionOneBackupIsNotOverwritten() throws {
        let backup = fileURL.deletingLastPathComponent().appending(path: "commands-v1.json.bak")
        try writeRaw(#"{"version": 1, "commands": []}"#)
        try Data("eerder".utf8).write(to: backup)
        let store = CommandStore(fileURL: fileURL)
        #expect(!store.isReadOnly)
        #expect(try String(contentsOf: backup, encoding: .utf8) == "eerder")
        // Het nieuwe origineel krijgt een eigen back-up met datum en tijd.
        let others = try backupURLs().filter { $0.lastPathComponent != "commands-v1.json.bak" }
        #expect(others.count == 1)
        #expect(try String(contentsOf: #require(others.first), encoding: .utf8) == #"{"version": 1, "commands": []}"#)
        #expect(try String(contentsOf: fileURL, encoding: .utf8).contains(#""version" : 2"#))
    }

    @Test func unreadableVersionOneFileIsBackedUp() throws {
        let raw = #"{"version": 1, "commands": 5}"#
        try writeRaw(raw)
        let store = CommandStore(fileURL: fileURL)
        #expect(store.lists == .standard)
        #expect(!store.isReadOnly)
        let backups = try backupURLs()
        #expect(backups.count == 1)
        #expect(try String(contentsOf: #require(backups.first), encoding: .utf8) == raw)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func commandGetsTheAxisOfItsList() throws {
        try CommandStore(fileURL: fileURL).save()
        try editJSON { json in
            var horizontal = try #require(json["horizontal"] as? [String: Any])
            var commands = try #require(horizontal["commands"] as? [[String: Any]])
            commands[0]["axis"] = "vertical"
            horizontal["commands"] = commands
            json["horizontal"] = horizontal
        }
        let store = CommandStore(fileURL: fileURL)
        #expect(store.command("left")?.axis == .horizontal)
        #expect(store.lists == .standard)
    }

    @Test func unreadableFileIsReadOnlyAndUntouched() throws {
        var store = CommandStore(fileURL: fileURL)
        store.setShortcut(nil, for: "left")
        try store.save()
        let original = try Data(contentsOf: fileURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: fileURL.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: fileURL.path) }

        var loaded = CommandStore(fileURL: fileURL)
        #expect(loaded.lists == .standard)
        #expect(loaded.isReadOnly)
        #expect(loaded.readOnlyReason == .unreadable)
        loaded.setShortcut(nil, for: "right")
        #expect(throws: CommandStore.Error.readOnly) { try loaded.save() }
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: fileURL.path)
        #expect(try Data(contentsOf: fileURL) == original)
        #expect(try backupURLs().isEmpty)
    }

    @Test func standardCommandInTheWrongListIsDroppedAndTheStandardReturnsInItsOwnList() throws {
        try CommandStore(fileURL: fileURL).save()
        try editJSON { json in
            var horizontal = try #require(json["horizontal"] as? [String: Any])
            var vertical = try #require(json["vertical"] as? [String: Any])
            var verticalCommands = try #require(vertical["commands"] as? [[String: Any]])
            var horizontalCommands = try #require(horizontal["commands"] as? [[String: Any]])
            horizontalCommands.append(verticalCommands.removeFirst()) // vertical.left in Horizontal
            horizontal["commands"] = horizontalCommands
            vertical["commands"] = verticalCommands
            json["horizontal"] = horizontal
            json["vertical"] = vertical
        }
        let loaded = CommandStore(fileURL: fileURL)
        #expect(loaded.lists.horizontal == CommandLists.standard.horizontal)
        #expect(loaded.commands(for: .vertical).last == DefaultCommands.command("vertical.left"))
        #expect(try backupURLs().count == 1)
    }

    @Test func duplicateIDIsKeptOnlyOnceAndHorizontalWins() throws {
        try CommandStore(fileURL: fileURL).save()
        try editJSON { json in
            let horizontal = try #require(json["horizontal"] as? [String: Any])
            let left = try #require((horizontal["commands"] as? [[String: Any]])?.first)
            var vertical = try #require(json["vertical"] as? [String: Any])
            var commands = try #require(vertical["commands"] as? [[String: Any]])
            commands.insert(left, at: 0)
            commands.append(commands[1]) // vertical.left nog een keer
            vertical["commands"] = commands
            json["vertical"] = vertical
        }
        let store = CommandStore(fileURL: fileURL)
        #expect(store.commands(for: .horizontal).filter { $0.id == "left" }.count == 1)
        #expect(!store.commands(for: .vertical).contains { $0.id == "left" })
        #expect(store.commands(for: .vertical).filter { $0.id == "vertical.left" }.count == 1)
        #expect(store.lists == .standard)
        #expect(try backupURLs().count == 1) // er viel iets weg
    }

    @Test func discardedIncompleteCustomCommandIsNoLoss() throws {
        var store = CommandStore(fileURL: fileURL)
        store.addCustom(axis: .horizontal, name: "Leeg")
        try store.save()
        #expect(CommandStore(fileURL: fileURL).lists == .standard)
        #expect(try backupURLs().isEmpty)
    }

    @Test func unreadableListFallsBackForThatAxisOnlyAndIsBackedUp() throws {
        let replacements: [Any?] = [5, ["commands": "geen lijst"], nil]
        for replacement in replacements {
            try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
            var store = CommandStore(fileURL: fileURL)
            store.setShortcut(Shortcut(keyCode: 37, modifiers: Shortcut.control), for: "left")
            store.setName("Smal", for: "vertical.topThird")
            try store.save()
            try editJSON { json in json["vertical"] = replacement }
            let original = try Data(contentsOf: fileURL)

            let loaded = CommandStore(fileURL: fileURL)
            #expect(!loaded.isReadOnly)
            #expect(loaded.lists.horizontal == store.lists.horizontal)
            #expect(loaded.lists.vertical == CommandLists.standard.vertical)
            let backups = try backupURLs()
            #expect(backups.count == 1)
            #expect(try Data(contentsOf: #require(backups.first)) == original)
            // Het bestand is meteen hersteld: opnieuw laden geeft hetzelfde en geen nieuwe back-up.
            #expect(CommandStore(fileURL: fileURL).lists == loaded.lists)
            #expect(try backupURLs().count == 1)
        }
    }

    private func editJSON(_ change: (inout [String: Any]) throws -> Void) throws {
        var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any])
        try change(&json)
        try JSONSerialization.data(withJSONObject: json).write(to: fileURL)
    }

    private func writeRaw(_ text: String) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: fileURL)
    }

    private func backupURLs() throws -> [URL] {
        let directory = fileURL.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasSuffix(".bak") }
    }
}
