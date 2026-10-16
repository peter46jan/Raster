import Foundation
import Testing
@testable import RasterCore

struct MenuLayoutTests {
    let defaults = DefaultCommands.horizontal

    func commandIDs(_ layout: MenuLayout) -> [String] {
        layout.entries.filter { $0.kind == .command }.map(\.id)
    }

    @Test func standardLayoutFollowsGroups() {
        let layout = MenuLayout.standard(for: defaults)
        #expect(commandIDs(layout) == defaults.map(\.id))
        let groups = Set(defaults.map(\.group)).count
        #expect(layout.entries.filter { $0.kind == .divider }.count == groups - 1)
        #expect(layout.entries[4].kind == .divider) // na de vier helften
    }

    @Test func itemsSkipHiddenCommandsAndCollapseDividers() {
        let layout = MenuLayout.standard(for: defaults)
        // Alleen de hoeken verbergen: geen twee scheidingslijnen na elkaar.
        let items = layout.items(for: defaults) { $0.group != .corners }
        for (a, b) in zip(items, items.dropFirst()) {
            #expect(!(a == .divider && b == .divider))
        }
        #expect(items.first != .divider)
        #expect(items.last != .divider)
        // Alleen helften: geen enkele scheidingslijn.
        #expect(!layout.items(for: defaults) { $0.group == .halves }.contains(.divider))
    }

    @Test func resolvedAppendsNewCommandsAndDropsMissingOnes() {
        var layout = MenuLayout.standard(for: defaults)
        let custom = Command(id: "c1", name: "Eigen", axis: .horizontal, group: .custom,
                             action: .area(GridArea(GridRect(0, 0, 1, 1))))
        layout = layout.resolved(with: defaults + [custom])
        #expect(layout.entries.last == .command("c1"))
        #expect(layout.entries[layout.entries.count - 2].kind == .divider)
        layout = layout.resolved(with: defaults)
        #expect(!layout.entries.contains(.command("c1")))
    }

    @Test func resolvedKeepsEachCommandOnce() {
        let layout = MenuLayout(entries: [.command("left"), .command("left")]).resolved(with: defaults)
        #expect(layout.entries.filter { $0 == .command("left") }.count == 1)
    }

    @Test func moveAndDividers() {
        var layout = MenuLayout(entries: [.command("left"), .command("right"), .command("up")])
        layout.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        #expect(layout.entries.map(\.id) == ["up", "left", "right"])
        layout.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(layout.entries.map(\.id) == ["left", "right", "up"])
        layout.insertDivider(at: 1)
        #expect(layout.entries[1].kind == .divider)
        layout.removeDivider(id: layout.entries[1].id)
        #expect(layout.entries.map(\.id) == ["left", "right", "up"])
        layout.removeDivider(id: "left") // commando's zijn geen scheidingslijn
        #expect(layout.entries.count == 3)
    }

    @Test func resolvedCollapsesDuplicateAndConsecutiveDividersButKeepsTheEnds() {
        func divider(_ id: String) -> MenuEntry { MenuEntry(kind: .divider, id: id) }
        let two = defaults.filter { $0.id == "left" || $0.id == "right" }
        let messy = MenuLayout(entries: [divider("a"), .command("left"), divider("b"), divider("c"), .command("right"), divider("d")])
        #expect(messy.resolved(with: two).entries.map(\.id) == ["a", "left", "b", "right", "d"])
        let duplicated = MenuLayout(entries: [.command("left"), divider("x"), .command("right"), divider("x")])
        #expect(duplicated.resolved(with: two).entries.map(\.id) == ["left", "x", "right"])
    }

    @Test func resolvedDoesNotAddADividerAfterAnExistingOne() {
        func divider(_ id: String) -> MenuEntry { MenuEntry(kind: .divider, id: id) }
        let commands = defaults.filter { ["left", "topLeft"].contains($0.id) }
        let fresh = MenuLayout(entries: [divider("z")]).resolved(with: commands)
        #expect(fresh.entries.map(\.kind) == [.divider, .command, .divider, .command])
        let withDivider = MenuLayout(entries: [.command("left"), divider("z")]).resolved(with: commands)
        #expect(withDivider.entries.map(\.id) == ["left", "z", "topLeft"])
    }

    @Test func removingTheLastCustomCommandLeavesNoTrailingDivider() {
        let custom = Command(id: "c1", name: "Eigen", axis: .horizontal, group: .custom,
                             action: .area(GridArea(GridRect(0, 0, 1, 1))))
        let layout = MenuLayout.standard(for: defaults).resolved(with: defaults + [custom]).resolved(with: defaults)
        #expect(layout.entries.last?.kind == .command)
        #expect(layout == MenuLayout.standard(for: defaults))
    }

    @Test func aDividerAtTheEndSurvives() {
        var layout = MenuLayout.standard(for: defaults)
        layout.insertDivider(at: layout.entries.count)
        #expect(layout.resolved(with: defaults) == layout)
    }

    @Test func removingACommandKeepsTheDividerOnlyWhereItStillSeparates() {
        func divider(_ id: String) -> MenuEntry { MenuEntry(kind: .divider, id: id) }
        let two = defaults.filter { $0.id == "left" || $0.id == "right" }
        // Weggevallen commando tussen een scheidingslijn en een commando: de lijn scheidt nog iets.
        let between = MenuLayout(entries: [.command("left"), divider("d"), .command("gone"), .command("right")])
        #expect(between.resolved(with: two).entries.map(\.id) == ["left", "d", "right"])
        // Gevolgd door een andere scheidingslijn of het eind: de lijn ervoor hoorde bij het weggevallen commando.
        let beforeDivider = MenuLayout(entries: [.command("left"), divider("d1"), .command("gone"), divider("d2"), .command("right")])
        #expect(beforeDivider.resolved(with: two).entries.map(\.id) == ["left", "d2", "right"])
        let atEnd = MenuLayout(entries: [.command("left"), .command("right"), divider("d"), .command("gone")])
        #expect(atEnd.resolved(with: two).entries.map(\.id) == ["left", "right"])
        // Een keten van weggevallen commando's telt als één.
        let chain = MenuLayout(entries: [.command("left"), .command("right"), divider("d"), .command("gone1"), .command("gone2")])
        #expect(chain.resolved(with: two).entries.map(\.id) == ["left", "right"])
        let chainThenCommand = MenuLayout(entries: [.command("left"), divider("d"), .command("gone1"), .command("gone2"), .command("right")])
        #expect(chainThenCommand.resolved(with: two).entries.map(\.id) == ["left", "d", "right"])
        // Dubbele id in een beschadigd bestand: de latere lijn die nog iets scheidt blijft.
        let duplicateID = MenuLayout(entries: [.command("left"), divider("x"), .command("gone"), divider("x"), .command("right")])
        #expect(duplicateID.resolved(with: two).entries.map(\.id) == ["left", "x", "right"])
        // Een dubbel commando valt weg zoals een ontbrekend.
        let duplicateCommand = MenuLayout(entries: [.command("left"), .command("right"), divider("d"), .command("left")])
        #expect(duplicateCommand.resolved(with: two).entries.map(\.id) == ["left", "right"])
        let duplicateAfterDivider = MenuLayout(entries: [.command("left"), divider("d"), .command("left")])
        #expect(duplicateAfterDivider.resolved(with: two).entries.map(\.id) == ["left", "right"])
    }

    @Test func addingACustomCommandMatchesTheStandardForAllCommands() {
        let custom = Command(id: "c1", name: "Eigen", axis: .horizontal, group: .custom,
                             action: .area(GridArea(GridRect(0, 0, 1, 1))))
        let added = MenuLayout.standard(for: defaults).resolved(with: defaults + [custom])
        #expect(added == MenuLayout.standard(for: defaults + [custom]))
        #expect(added.resolved(with: defaults) == MenuLayout.standard(for: defaults))
        var layout = MenuLayout(entries: [.command("left"), MenuEntry(kind: .divider, id: "divider-1"), .command("right")])
        layout.insertDivider(at: 1)
        #expect(layout.entries[1].id == "divider-2")
    }

    @Test func moveWithNonContiguousOffsets() {
        let ids = ["left", "right", "up", "down", "topLeft"]
        var layout = MenuLayout(entries: ids.map { .command($0) })
        layout.move(fromOffsets: IndexSet([0, 2]), toOffset: 5)
        #expect(layout.entries.map(\.id) == ["right", "down", "topLeft", "left", "up"])
        layout.move(fromOffsets: IndexSet([1, 3]), toOffset: 0)
        #expect(layout.entries.map(\.id) == ["down", "left", "right", "topLeft", "up"])
    }
}
