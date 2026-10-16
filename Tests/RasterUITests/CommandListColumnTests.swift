import Foundation
import RasterCore
import Testing
import UniformTypeIdentifiers
@testable import RasterUI

/// Logica van de lijstkolom in Commands: rijen, rijknoppen, tooltips, kiezen en verplaatsen.
@MainActor
struct CommandListColumnTests {
    private static func custom(_ id: String, complete: Bool) -> Command {
        Command(id: id, name: "Command", axis: .horizontal, group: .custom,
                action: .area(GridArea(segments: complete ? [GridRect(x: 0, y: 0, width: 1, height: 1)] : [])))
    }

    @Test func rowsFollowTheLayoutWithDividers() {
        let rows = CommandListRow.rows(of: CommandLists.standard, axis: .horizontal)
        #expect(rows.prefix(5).map(\.id) == ["left", "right", "up", "down", "divider:horizontal:divider-1"])
        #expect(rows.count == CommandLists.standard.horizontal.layout.entries.count)
        #expect(rows.compactMap(\.command).count == CommandLists.standard.horizontal.commands.count)
    }

    @Test func rowButtonsOfADefaultCommand() throws {
        var command = try #require(DefaultCommands.command("left"))
        command.inZoomButtonMenu = false
        let buttons = CommandRowButton.buttons(for: command, isRemovable: false)
        #expect(buttons.map(\.kind) == [.greenMenu, .menuBar, .remove])
        #expect(buttons.map(\.isOn) == [false, true, true])
        #expect(buttons.map(\.isEnabled) == [true, true, false])
        #expect(buttons.map(\.tooltip) == [
            "Hidden from green button menu", "Shown in menu bar", "Built-in commands can’t be removed",
        ])
    }

    @Test func rowButtonsOfACustomCommandAndReadOnly() {
        let command = Self.custom("x", complete: true)
        let buttons = CommandRowButton.buttons(for: command, isRemovable: true)
        #expect(buttons.map(\.isEnabled) == [true, true, true])
        #expect(buttons.last?.tooltip == "Remove")
        let readOnly = CommandRowButton.buttons(for: command, isRemovable: true, isReadOnly: true)
        #expect(readOnly.allSatisfy { !$0.isEnabled })
        // In alleen-lezen-modus blijft de tooltip "Remove": het commando is wel te verwijderen, alleen nu niet.
        #expect(readOnly.last?.tooltip == "Remove")
    }

    @Test func dividerHasOnlyRemove() {
        #expect(CommandRowButton.dividerButtons().map(\.kind) == [.remove])
        #expect(CommandRowButton.dividerButtons().first?.isEnabled == true)
        #expect(CommandRowButton.dividerButtons(isReadOnly: true).first?.isEnabled == false)
    }

    @Test func chevronTooltipAndAngle() {
        #expect(CommandListLogic.chevronTooltip(isExpanded: true) == "Collapse")
        #expect(CommandListLogic.chevronTooltip(isExpanded: false) == "Expand")
        #expect(CommandListLogic.chevronAngle(isExpanded: false) == 0)
        #expect(CommandListLogic.chevronAngle(isExpanded: true) == 90)
    }

    @Test func leavingAnIncompleteCommandAsks() {
        let incomplete = Self.custom("new", complete: false)
        #expect(CommandListLogic.needsLeaveConfirmation(current: incomplete, next: "left"))
        // Een nieuw commando toevoegen (nil) vraagt ook.
        #expect(CommandListLogic.needsLeaveConfirmation(current: incomplete, next: nil))
        #expect(!CommandListLogic.needsLeaveConfirmation(current: incomplete, next: "new"))
        #expect(!CommandListLogic.needsLeaveConfirmation(current: Self.custom("done", complete: true), next: "left"))
        #expect(!CommandListLogic.needsLeaveConfirmation(current: nil, next: "left"))
        // Speciale commando's hebben geen gebied en zijn altijd compleet.
        #expect(!CommandListLogic.needsLeaveConfirmation(current: DefaultCommands.command("center"), next: "left"))
    }

    @Test func selectionAfterRemovingSkipsDividers() {
        let rows: [CommandListRow] = [
            .command(Self.custom("a", complete: true)), .divider(axis: .horizontal, id: "divider-1"),
            .command(Self.custom("b", complete: true)), .divider(axis: .horizontal, id: "divider-2"),
        ]
        #expect(CommandListLogic.selectionAfterRemoving("a", rows: rows) == "b")
        #expect(CommandListLogic.selectionAfterRemoving("b", rows: rows) == "a")
        #expect(CommandListLogic.selectionAfterRemoving("c", rows: rows) == nil)
        #expect(CommandListLogic.selectionAfterRemoving("a", rows: [rows[0]]) == nil)
    }

    @Test func insertionIndexRoundsToTheNearestBoundary() {
        #expect(CommandListLogic.insertionIndex(y: -10, count: 4) == 0)
        #expect(CommandListLogic.insertionIndex(y: 14, count: 4) == 0)
        #expect(CommandListLogic.insertionIndex(y: 16, count: 4) == 1)
        #expect(CommandListLogic.insertionIndex(y: 75, count: 4) == 3)
        #expect(CommandListLogic.insertionIndex(y: 500, count: 4) == 4)
    }

    @Test func movingOntoItselfIsNoMove() {
        #expect(!CommandListLogic.isMove(from: 2, to: 2))
        #expect(!CommandListLogic.isMove(from: 2, to: 3))
        #expect(CommandListLogic.isMove(from: 2, to: 0))
        #expect(CommandListLogic.isMove(from: 2, to: 4))
    }

    @Test func entryMoveMatchesListOnMove() throws {
        let list = CommandLists.standard.horizontal
        let rows = CommandListRow.rows(of: CommandLists.standard, axis: .horizontal)
        // "Left" (rij 0) onder "Bottom" (vóór de eerste scheidingsrij, plaats 4).
        let change = try #require(CommandListLogic.entryMove(from: 0, to: 4, rows: rows, entries: list.layout.entries))
        var layout = list.layout
        layout.move(fromOffsets: IndexSet(integer: change.source), toOffset: change.destination)
        #expect(layout.entries.prefix(5).map(\.id) == ["right", "up", "down", "left", "divider-1"])
        // Naar het eind.
        let toEnd = try #require(CommandListLogic.entryMove(from: 0, to: rows.count, rows: rows,
                                                             entries: list.layout.entries))
        #expect(toEnd.destination == list.layout.entries.count)
        #expect(CommandListLogic.entryMove(from: 1, to: 2, rows: rows, entries: list.layout.entries) == nil)
    }

    /// Rij-ids zijn uniek over beide lijsten, ook de scheidingsrijen ("divider-1" staat in allebei).
    @Test func rowIDsAreUniqueAcrossBothLists() {
        let ids = CommandAxis.allCases.flatMap { CommandListRow.rows(of: CommandLists.standard, axis: $0).map(\.id) }
        #expect(Set(ids).count == ids.count)
        #expect(ids.contains("divider:vertical:divider-1"))
    }

    /// Een scheidingsrij verwijderen laat de scheidingsrij met dezelfde id in de andere lijst staan.
    @Test func removingADividerLeavesTheOtherList() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "commandlist-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let model = CommandsModel(store: CommandStore(fileURL: folder.appending(path: "commands.json")))
        let vertical = model.lists.vertical
        let row = try #require(CommandListRow.rows(of: model.lists, axis: .horizontal)
            .first { $0.id == "divider:horizontal:divider-1" })
        model.remove(row)
        #expect(!model.lists.horizontal.layout.entries.contains(MenuEntry(kind: .divider, id: "divider-1")))
        #expect(model.lists.vertical == vertical)
    }

    /// De sectie neemt precies het type aan dat een gesleepte rij aanbiedt, en geen tekst: de id gaat niet naar
    /// andere apps en tekst van buiten verplaatst niets.
    @Test func dropZoneAcceptsWhatTheDragOffers() async throws {
        let provider = CommandListDrag.itemProvider(for: "divider:horizontal:divider-1")
        #expect(provider.registeredTypeIdentifiers == CommandListDrag.types.map(\.identifier))
        #expect(CommandListDrag.types.map(\.identifier) == ["nl.jimlindenburg.raster.command-list-row"])
        #expect(!CommandListDrag.types.contains { $0.conforms(to: .text) })
        #expect(CommandListDrag.types.allSatisfy { provider.hasItemConformingToTypeIdentifier($0.identifier) })
        let data: Data = try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.rasterCommandListRow.identifier) { data, error in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: error ?? CocoaError(.fileReadUnknown))
                }
            }
        }
        #expect(String(data: data, encoding: .utf8) == "divider:horizontal:divider-1")
    }
}
