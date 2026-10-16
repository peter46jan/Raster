import CoreGraphics
import Foundation
import Testing
@testable import RasterCore

struct CommandListTests {
    @Test func horizontalDefaultNames() {
        let names = DefaultCommands.horizontal.map(\.name)
        #expect(names == [
            "Left", "Right", "Top", "Bottom", "Top Left", "Top Right", "Bottom Left", "Bottom Right",
            "Left Third", "Center Third", "Right Third", "Left Two Thirds", "Center Two Thirds", "Right Two Thirds",
            "Next Display", "Previous Display", "Maximize", "Center", "Restore",
        ])
        #expect(DefaultCommands.horizontal.allSatisfy { $0.axis == .horizontal })
    }

    @Test func verticalDefaultsMatchVerticalCommandsJSON() {
        let names = DefaultCommands.vertical.map(\.name)
        #expect(names == [
            "Left", "Right", "Top", "Bottom", "Top Left", "Top Right", "Bottom Left", "Bottom Right",
            "Top Third", "Center Third", "Bottom Third", "Top Two Thirds", "Center Two Thirds", "Bottom Two Thirds",
            "Next Display", "Previous Display", "Maximize", "Center", "Restore",
        ])
        #expect(DefaultCommands.vertical.allSatisfy { $0.axis == .vertical && $0.id.hasPrefix("vertical.") })
        let topThird = DefaultCommands.command("vertical.topThird")
        #expect(topThird?.area == GridArea(GridRect(0, 0, 12, 8)))
        #expect(topThird?.dragZones == GridArea(GridRect(0, 5, 1, 3), GridRect(11, 5, 1, 3)))
        #expect(topThird?.shortcut == Shortcut(keyCode: 2, modifiers: Shortcut.controlOption))
        #expect(DefaultCommands.command("vertical.centerTwoThirds")?.dragZones == GridArea(GridRect(1, 11, 1, 2), GridRect(10, 11, 1, 2)))
    }

    @Test func idsAreUniqueOverBothLists() {
        let ids = (DefaultCommands.horizontal + DefaultCommands.vertical).map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func stayOnTopIsNotADefault() {
        #expect(!DefaultCommands.horizontal.contains { $0.action == .special(.stayOnTop) })
        #expect(!DefaultCommands.vertical.contains { $0.action == .special(.stayOnTop) })
        #expect(DefaultCommands.stayOnTop(axis: .vertical).id == "vertical.stayOnTop")
    }

    @Test func standardLayoutHasDefaultDividers() {
        let items = CommandLists.standard.vertical.menuItems { _ in true }
        let dividers = items.indices.filter { items[$0] == .divider }
        // Na Bottom, Bottom Right, Bottom Third, Bottom Two Thirds en Previous Display.
        #expect(dividers == [4, 9, 13, 17, 20])
    }

    @Test func shortcutPicksCommandOfAxis() {
        let lists = CommandLists.standard
        let key = Shortcut(keyCode: 2, modifiers: Shortcut.controlOption)
        #expect(lists.command(for: key, axis: .horizontal)?.name == "Left Third")
        #expect(lists.command(for: key, axis: .vertical)?.name == "Top Third")
    }

    @Test func disabledShortcutDoesNotFire() {
        var lists = CommandLists.standard
        lists.horizontal.commands[0].shortcutEnabled = false
        #expect(lists.command(for: Shortcut(keyCode: 123, modifiers: Shortcut.controlOption), axis: .horizontal) == nil)
        #expect(lists.activeShortcuts.contains(Shortcut(keyCode: 123, modifiers: Shortcut.controlOption))) // Vertical heeft hem nog
    }

    @Test func incompleteCommandsAreLeftOut() {
        var list = CommandList(commands: DefaultCommands.horizontal)
        var custom = Command(id: "x", name: "Command", axis: .horizontal, group: .custom, action: .area(GridArea(segments: [])))
        custom.shortcut = Shortcut(keyCode: 0, modifiers: Shortcut.controlOption)
        list.commands.append(custom)
        list = CommandList(commands: list.commands, layout: list.layout)
        #expect(!custom.isComplete)
        #expect(!list.menuItems { _ in true }.contains(.command(custom)))
        #expect(CommandLists(horizontal: list, vertical: CommandLists.standard.vertical)
            .command(for: custom.shortcut!, axis: .horizontal) == nil)
    }

    @Test func takenOnlyWithinSameAxis() {
        let lists = CommandLists.standard
        let left = Shortcut(keyCode: 123, modifiers: Shortcut.controlOption)
        #expect(lists.isTaken(left, axis: .horizontal, except: "right"))
        #expect(!lists.isTaken(left, axis: .horizontal, except: "left"))
        #expect(!lists.isTaken(Shortcut(keyCode: 0, modifiers: Shortcut.controlOption), axis: .vertical, except: "vertical.left"))
    }

    @Test func incompleteCommandDoesNotTakeAShortcut() {
        var lists = CommandLists.standard
        var custom = Command(id: "x", name: "Command", axis: .horizontal, group: .custom, action: .area(GridArea(segments: [])))
        custom.shortcut = Shortcut(keyCode: 0, modifiers: Shortcut.controlOption)
        lists.horizontal.commands.append(custom)
        #expect(!lists.isTaken(custom.shortcut!, axis: .horizontal, except: "left"))
        lists.horizontal.commands[lists.horizontal.commands.count - 1].setArea(GridArea(GridRect(0, 0, 4, 4)))
        #expect(lists.isTaken(custom.shortcut!, axis: .horizontal, except: "left"))
    }
}
