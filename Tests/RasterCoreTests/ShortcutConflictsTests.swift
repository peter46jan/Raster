import Testing
@testable import RasterCore

struct ShortcutConflictsTests {
    @Test func defaultsHaveNoDuplicates() {
        #expect(ShortcutConflicts.duplicates(in: DefaultCommands.horizontal).isEmpty)
        #expect(ShortcutConflicts.duplicates(in: DefaultCommands.vertical).isEmpty)
    }

    @Test func duplicateShortcutsAreReportedForEnabledShortcutsOnly() {
        var commands = DefaultCommands.horizontal
        commands[1].shortcut = commands[0].shortcut // right krijgt de sneltoets van left
        #expect(ShortcutConflicts.duplicates(in: commands) == ["left", "right"])
        commands[1].shortcutEnabled = false
        #expect(ShortcutConflicts.duplicates(in: commands).isEmpty)
    }

    @Test func sameShortcutInHorizontalAndVerticalIsNoConflict() {
        #expect(ShortcutConflicts.duplicates(in: CommandLists.standard).isEmpty)
        var lists = CommandLists.standard
        lists.vertical.commands[1].shortcut = lists.vertical.commands[0].shortcut
        #expect(ShortcutConflicts.duplicates(in: lists) == ["vertical.left", "vertical.right"])
    }

    @Test func incompleteCommandIsNoConflict() {
        var commands = DefaultCommands.horizontal
        var custom = Command(id: "x", name: "Command", axis: .horizontal, group: .custom, action: .area(GridArea(segments: [])))
        custom.shortcut = commands[0].shortcut
        commands.append(custom)
        #expect(ShortcutConflicts.duplicates(in: commands).isEmpty)
        commands[commands.count - 1].setArea(GridArea(GridRect(0, 0, 4, 4)))
        #expect(ShortcutConflicts.duplicates(in: commands) == ["left", "x"])
    }
}
