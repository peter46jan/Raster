import Testing
@testable import RasterCore

struct DefaultCommandsTests {
    struct Row {
        let id: String
        let name: String
        let key: UInt32
        let modifiers: UInt32
        let area: GridRect?
    }

    static let co = Shortcut.controlOption
    static let coc = Shortcut.controlOptionCommand

    /// Gelijk aan de tabel in de spec, liggend gebied (zonder altijd bovenop).
    static let horizontal: [Row] = [
        Row(id: "left", name: "Left", key: 123, modifiers: co, area: GridRect(0, 0, 12, 12)),
        Row(id: "right", name: "Right", key: 124, modifiers: co, area: GridRect(12, 0, 12, 12)),
        Row(id: "up", name: "Top", key: 126, modifiers: co, area: GridRect(0, 0, 24, 6)),
        Row(id: "down", name: "Bottom", key: 125, modifiers: co, area: GridRect(0, 6, 24, 6)),
        Row(id: "topLeft", name: "Top Left", key: 32, modifiers: co, area: GridRect(0, 0, 12, 6)),
        Row(id: "topRight", name: "Top Right", key: 34, modifiers: co, area: GridRect(12, 0, 12, 6)),
        Row(id: "bottomLeft", name: "Bottom Left", key: 38, modifiers: co, area: GridRect(0, 6, 12, 6)),
        Row(id: "bottomRight", name: "Bottom Right", key: 40, modifiers: co, area: GridRect(12, 6, 12, 6)),
        Row(id: "leftThird", name: "Left Third", key: 2, modifiers: co, area: GridRect(0, 0, 8, 12)),
        Row(id: "centerThird", name: "Center Third", key: 3, modifiers: co, area: GridRect(8, 0, 8, 12)),
        Row(id: "rightThird", name: "Right Third", key: 5, modifiers: co, area: GridRect(16, 0, 8, 12)),
        Row(id: "leftTwoThirds", name: "Left Two Thirds", key: 14, modifiers: co, area: GridRect(0, 0, 16, 12)),
        Row(id: "centerTwoThirds", name: "Center Two Thirds", key: 15, modifiers: co, area: GridRect(4, 0, 16, 12)),
        Row(id: "rightTwoThirds", name: "Right Two Thirds", key: 17, modifiers: co, area: GridRect(8, 0, 16, 12)),
        Row(id: "nextDisplay", name: "Next Display", key: 124, modifiers: coc, area: nil),
        Row(id: "previousDisplay", name: "Previous Display", key: 123, modifiers: coc, area: nil),
        Row(id: "maximize", name: "Maximize", key: 36, modifiers: co, area: GridRect(0, 0, 24, 12)),
        Row(id: "center", name: "Center", key: 8, modifiers: co, area: nil),
        Row(id: "restore", name: "Restore", key: 51, modifiers: co, area: nil),
    ]

    /// Gelijk aan de tabel in de spec, staand gebied (`VerticalCommands.json`).
    static let vertical: [Row] = [
        Row(id: "vertical.left", name: "Left", key: 123, modifiers: co, area: GridRect(0, 0, 6, 24)),
        Row(id: "vertical.right", name: "Right", key: 124, modifiers: co, area: GridRect(6, 0, 6, 24)),
        Row(id: "vertical.up", name: "Top", key: 126, modifiers: co, area: GridRect(0, 0, 12, 12)),
        Row(id: "vertical.down", name: "Bottom", key: 125, modifiers: co, area: GridRect(0, 12, 12, 12)),
        Row(id: "vertical.topLeft", name: "Top Left", key: 32, modifiers: co, area: GridRect(0, 0, 6, 12)),
        Row(id: "vertical.topRight", name: "Top Right", key: 34, modifiers: co, area: GridRect(6, 0, 6, 12)),
        Row(id: "vertical.bottomLeft", name: "Bottom Left", key: 38, modifiers: co, area: GridRect(0, 12, 6, 12)),
        Row(id: "vertical.bottomRight", name: "Bottom Right", key: 40, modifiers: co, area: GridRect(6, 12, 6, 12)),
        Row(id: "vertical.topThird", name: "Top Third", key: 2, modifiers: co, area: GridRect(0, 0, 12, 8)),
        Row(id: "vertical.centerThird", name: "Center Third", key: 3, modifiers: co, area: GridRect(0, 8, 12, 8)),
        Row(id: "vertical.bottomThird", name: "Bottom Third", key: 5, modifiers: co, area: GridRect(0, 16, 12, 8)),
        Row(id: "vertical.topTwoThirds", name: "Top Two Thirds", key: 14, modifiers: co, area: GridRect(0, 0, 12, 16)),
        Row(id: "vertical.centerTwoThirds", name: "Center Two Thirds", key: 15, modifiers: co, area: GridRect(0, 4, 12, 16)),
        Row(id: "vertical.bottomTwoThirds", name: "Bottom Two Thirds", key: 17, modifiers: co, area: GridRect(0, 8, 12, 16)),
        Row(id: "vertical.nextDisplay", name: "Next Display", key: 124, modifiers: coc, area: nil),
        Row(id: "vertical.previousDisplay", name: "Previous Display", key: 123, modifiers: coc, area: nil),
        Row(id: "vertical.maximize", name: "Maximize", key: 36, modifiers: co, area: GridRect(0, 0, 12, 24)),
        Row(id: "vertical.center", name: "Center", key: 8, modifiers: co, area: nil),
        Row(id: "vertical.restore", name: "Restore", key: 51, modifiers: co, area: nil),
    ]

    private func check(_ commands: [Command], _ table: [Row], axis: CommandAxis) {
        #expect(commands.map(\.id) == table.map(\.id))
        for (command, row) in zip(commands, table) {
            #expect(command.axis == axis, "\(command.id)")
            #expect(command.name == row.name, "\(command.id)")
            #expect(command.shortcut == Shortcut(keyCode: row.key, modifiers: row.modifiers), "\(command.id)")
            #expect(command.shortcutEnabled && command.dragZonesEnabled, "\(command.id)")
            switch command.action {
            case .area(let area):
                #expect(area.segments == [row.area].compactMap { $0 }, "\(command.id)")
                #expect(command.dragZones != nil, "\(command.id)")
            case .special:
                #expect(row.area == nil, "\(command.id)")
                #expect(command.dragZones == nil, "\(command.id)")
            }
        }
    }

    @Test func horizontalMatchesDefaultTable() {
        check(DefaultCommands.horizontal, Self.horizontal, axis: .horizontal)
    }

    @Test func verticalMatchesDefaultTable() {
        check(DefaultCommands.vertical, Self.vertical, axis: .vertical)
    }

    @Test func dragZonesOfDefaults() {
        #expect(DefaultCommands.command("up")?.dragZones?.segments == [GridRect(0, 1, 1, 2), GridRect(23, 1, 1, 2)])
        #expect(DefaultCommands.command("centerTwoThirds")?.dragZones?.segments == [GridRect(11, 10, 2, 1)])
        #expect(DefaultCommands.command("vertical.centerTwoThirds")?.dragZones?.segments == [GridRect(1, 11, 1, 2), GridRect(10, 11, 1, 2)])
        #expect(DefaultCommands.command("vertical.maximize")?.dragZones?.segments == [GridRect(1, 0, 10, 1)])
    }

    @Test func shortcutsAreUniquePerList() {
        for list in [DefaultCommands.horizontal, DefaultCommands.vertical] {
            let shortcuts = list.compactMap(\.shortcut)
            #expect(Set(shortcuts).count == shortcuts.count)
        }
    }

    @Test func everyAreaFitsTheGridOfItsAxis() {
        func fits(_ area: GridArea, _ grid: GridSize) -> Bool {
            area.segments.allSatisfy {
                $0.x >= 0 && $0.y >= 0 && $0.width > 0 && $0.height > 0
                    && $0.x + $0.width <= grid.columns && $0.y + $0.height <= grid.rows
            }
        }
        for command in DefaultCommands.horizontal + DefaultCommands.vertical {
            if let area = command.area { #expect(fits(area, command.axis.grid), "\(command.id)") }
            if let zones = command.dragZones { #expect(fits(zones, command.axis.grid), "\(command.id)") }
        }
    }

    @Test func listForAxis() {
        #expect(DefaultCommands.list(for: .horizontal) == DefaultCommands.horizontal)
        #expect(DefaultCommands.list(for: .vertical) == DefaultCommands.vertical)
        #expect(DefaultCommands.command("nope") == nil)
        #expect(DefaultCommands.stayOnTop(axis: .horizontal).id == "stayOnTop")
        #expect(DefaultCommands.stayOnTop(axis: .horizontal).shortcut == Shortcut(keyCode: 126, modifiers: Self.coc))
    }
}
