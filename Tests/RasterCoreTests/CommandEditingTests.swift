import Testing
@testable import RasterCore

struct CommandEditingTests {
    static func makeCustom(_ area: GridArea = GridArea(GridRect(0, 0, 12, 12))) -> Command {
        Command(id: "c", name: "Eigen", axis: .horizontal, group: .custom, action: .area(area))
    }

    @Test func setArea() {
        var custom = Self.makeCustom()
        custom.setArea(GridArea(GridRect(1, 1, 2, 2)))
        #expect(custom.area == GridArea(GridRect(1, 1, 2, 2)))
        #expect(custom.action == .area(GridArea(GridRect(1, 1, 2, 2))))
    }

    @Test func setAreaIgnoresSpecialCommands() {
        var center = DefaultCommands.command("center")!
        center.setArea(GridArea(GridRect(1, 1, 2, 2)))
        #expect(center.action == .special(.center))
        #expect(center.area == nil)
    }

    @Test func emptyAreaIsIncompleteAndSpecialCommandsAreComplete() {
        #expect(Self.makeCustom().isComplete)
        #expect(!Self.makeCustom(GridArea(segments: [])).isComplete)
        #expect(DefaultCommands.command("center")!.isComplete)
    }

    @Test func switchesHideShortcutAndDragZones() {
        var left = DefaultCommands.command("left")!
        #expect(left.activeShortcut == left.shortcut)
        #expect(left.activeDragZones == left.dragZones)
        left.shortcutEnabled = false
        left.dragZonesEnabled = false
        #expect(left.activeShortcut == nil)
        #expect(left.activeDragZones.segments.isEmpty)
        #expect(left.shortcut != nil) // bewaard, alleen uit
        #expect(DefaultCommands.command("center")!.activeDragZones.segments.isEmpty)
    }

    @Test func axisGrid() {
        #expect(CommandAxis.horizontal.grid == .landscape)
        #expect(CommandAxis.vertical.grid == .portrait)
        #expect(CommandAxis.for(.portrait) == .vertical)
        #expect(CommandAxis.for(.landscape) == .horizontal)
    }
}
