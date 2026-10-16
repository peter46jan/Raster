/// De standaardcommando's voor liggende (Horizontal) en staande (Vertical) schermen.
/// Gebieden en sleepzones in rastercellen: Horizontal 24 × 12, Vertical 12 × 24.
public enum DefaultCommands {
    public static let horizontal: [Command] = [
        area("left", "Left", .halves, key: 123, r(0, 0, 12, 12), zones: [r(0, 3, 1, 6)]),
        area("right", "Right", .halves, key: 124, r(12, 0, 12, 12), zones: [r(23, 3, 1, 6)]),
        area("up", "Top", .halves, key: 126, r(0, 0, 24, 6), zones: [r(0, 1, 1, 2), r(23, 1, 1, 2)]),
        area("down", "Bottom", .halves, key: 125, r(0, 6, 24, 6), zones: [r(0, 9, 1, 2), r(23, 9, 1, 2)]),

        area("topLeft", "Top Left", .corners, key: 32, r(0, 0, 12, 6), zones: [r(0, 0, 1, 1)]),
        area("topRight", "Top Right", .corners, key: 34, r(12, 0, 12, 6), zones: [r(23, 0, 1, 1)]),
        area("bottomLeft", "Bottom Left", .corners, key: 38, r(0, 6, 12, 6), zones: [r(0, 11, 1, 1)]),
        area("bottomRight", "Bottom Right", .corners, key: 40, r(12, 6, 12, 6), zones: [r(23, 11, 1, 1)]),

        area("leftThird", "Left Third", .thirds, key: 2, r(0, 0, 8, 12), zones: [r(1, 11, 6, 1)]),
        area("centerThird", "Center Third", .thirds, key: 3, r(8, 0, 8, 12), zones: [r(9, 11, 6, 1)]),
        area("rightThird", "Right Third", .thirds, key: 5, r(16, 0, 8, 12), zones: [r(17, 11, 6, 1)]),

        area("leftTwoThirds", "Left Two Thirds", .twoThirds, key: 14, r(0, 0, 16, 12), zones: [r(7, 11, 2, 1)]),
        area("centerTwoThirds", "Center Two Thirds", .twoThirds, key: 15, r(4, 0, 16, 12), zones: [r(11, 10, 2, 1)]),
        area("rightTwoThirds", "Right Two Thirds", .twoThirds, key: 17, r(8, 0, 16, 12), zones: [r(15, 11, 2, 1)]),

        special("nextDisplay", "Next Display", .displays, .nextDisplay, key: 124, modifiers: Shortcut.controlOptionCommand),
        special("previousDisplay", "Previous Display", .displays, .previousDisplay, key: 123, modifiers: Shortcut.controlOptionCommand),

        area("maximize", "Maximize", .other, key: 36, r(0, 0, 24, 12), zones: [r(1, 0, 22, 1)]),
        special("center", "Center", .other, .center, key: 8, modifiers: Shortcut.controlOption),
        special("restore", "Restore", .other, .restore, key: 51, modifiers: Shortcut.controlOption),
    ]

    public static let vertical: [Command] = [
        area("vertical.left", "Left", .halves, key: 123, r(0, 0, 6, 24), zones: [r(1, 23, 5, 1)], axis: .vertical),
        area("vertical.right", "Right", .halves, key: 124, r(6, 0, 6, 24), zones: [r(6, 23, 5, 1)], axis: .vertical),
        area("vertical.up", "Top", .halves, key: 126, r(0, 0, 12, 12), zones: [r(0, 1, 1, 4), r(11, 1, 1, 4)], axis: .vertical),
        area("vertical.down", "Bottom", .halves, key: 125, r(0, 12, 12, 12), zones: [r(0, 19, 1, 4), r(11, 19, 1, 4)], axis: .vertical),

        area("vertical.topLeft", "Top Left", .corners, key: 32, r(0, 0, 6, 12), zones: [r(0, 0, 1, 1)], axis: .vertical),
        area("vertical.topRight", "Top Right", .corners, key: 34, r(6, 0, 6, 12), zones: [r(11, 0, 1, 1)], axis: .vertical),
        area("vertical.bottomLeft", "Bottom Left", .corners, key: 38, r(0, 12, 6, 12), zones: [r(0, 23, 1, 1)], axis: .vertical),
        area("vertical.bottomRight", "Bottom Right", .corners, key: 40, r(6, 12, 6, 12), zones: [r(11, 23, 1, 1)], axis: .vertical),

        area("vertical.topThird", "Top Third", .thirds, key: 2, r(0, 0, 12, 8), zones: [r(0, 5, 1, 3), r(11, 5, 1, 3)], axis: .vertical),
        area("vertical.centerThird", "Center Third", .thirds, key: 3, r(0, 8, 12, 8), zones: [r(0, 10, 1, 4), r(11, 10, 1, 4)], axis: .vertical),
        area("vertical.bottomThird", "Bottom Third", .thirds, key: 5, r(0, 16, 12, 8), zones: [r(0, 16, 1, 3), r(11, 16, 1, 3)], axis: .vertical),

        area("vertical.topTwoThirds", "Top Two Thirds", .twoThirds, key: 14, r(0, 0, 12, 16), zones: [r(0, 8, 1, 2), r(11, 8, 1, 2)], axis: .vertical),
        area("vertical.centerTwoThirds", "Center Two Thirds", .twoThirds, key: 15, r(0, 4, 12, 16), zones: [r(1, 11, 1, 2), r(10, 11, 1, 2)], axis: .vertical),
        area("vertical.bottomTwoThirds", "Bottom Two Thirds", .twoThirds, key: 17, r(0, 8, 12, 16), zones: [r(0, 14, 1, 2), r(11, 14, 1, 2)], axis: .vertical),

        special("vertical.nextDisplay", "Next Display", .displays, .nextDisplay, key: 124, modifiers: Shortcut.controlOptionCommand, axis: .vertical),
        special("vertical.previousDisplay", "Previous Display", .displays, .previousDisplay, key: 123, modifiers: Shortcut.controlOptionCommand, axis: .vertical),

        area("vertical.maximize", "Maximize", .other, key: 36, r(0, 0, 12, 24), zones: [r(1, 0, 10, 1)], axis: .vertical),
        special("vertical.center", "Center", .other, .center, key: 8, modifiers: Shortcut.controlOption, axis: .vertical),
        special("vertical.restore", "Restore", .other, .restore, key: 51, modifiers: Shortcut.controlOption, axis: .vertical),
    ]

    /// Altijd bovenop (⌃⌥⌘↑). De functie bestaat, maar staat niet in de standaardlijsten;
    /// alleen een in fase 4–5 aangepast exemplaar komt via de migratie in de lijsten.
    public static func stayOnTop(axis: CommandAxis) -> Command {
        special(axis == .vertical ? "vertical.stayOnTop" : "stayOnTop", "Stay On Top", .other, .stayOnTop,
                key: 126, modifiers: Shortcut.controlOptionCommand, axis: axis)
    }

    public static func list(for axis: CommandAxis) -> [Command] {
        axis == .vertical ? vertical : horizontal
    }

    /// Het standaardcommando met deze id uit een van beide lijsten.
    public static func command(_ id: String) -> Command? {
        horizontal.first { $0.id == id } ?? vertical.first { $0.id == id }
    }

    private static func r(_ x: Int, _ y: Int, _ width: Int, _ height: Int) -> GridRect {
        GridRect(x, y, width, height)
    }

    private static func area(
        _ id: String, _ name: String, _ group: CommandGroup, key: UInt32, _ area: GridRect, zones: [GridRect],
        axis: CommandAxis = .horizontal
    ) -> Command {
        Command(
            id: id, name: name, axis: axis, group: group, action: .area(GridArea(area)),
            dragZones: GridArea(segments: zones), shortcut: Shortcut(keyCode: key, modifiers: Shortcut.controlOption)
        )
    }

    private static func special(
        _ id: String, _ name: String, _ group: CommandGroup, _ action: SpecialAction,
        key: UInt32, modifiers: UInt32, axis: CommandAxis = .horizontal
    ) -> Command {
        Command(id: id, name: name, axis: axis, group: group, action: .special(action),
                shortcut: Shortcut(keyCode: key, modifiers: modifiers))
    }
}
