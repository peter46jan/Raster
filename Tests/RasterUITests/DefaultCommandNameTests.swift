import RasterCore
import Testing
@testable import RasterUI

/// De namen van de standaardcommando's staan hard in RasterCore; ze moeten gelijk zijn aan de teksten in `L10n`.
struct DefaultCommandNameTests {
    /// Per id (zonder "vertical.") de tekst uit `L10n`.
    private static let names: [String: String] = [
        "left": L10n.commandDefaultNameLeft,
        "right": L10n.commandDefaultNameRight,
        "up": L10n.commandDefaultNameUp,
        "down": L10n.commandDefaultNameDown,
        "topLeft": L10n.commandDefaultNameTopLeft,
        "topRight": L10n.commandDefaultNameTopRight,
        "bottomLeft": L10n.commandDefaultNameBottomLeft,
        "bottomRight": L10n.commandDefaultNameBottomRight,
        "leftThird": L10n.commandDefaultNameLeftThird,
        "centerThird": L10n.commandDefaultNameCenterThird,
        "rightThird": L10n.commandDefaultNameRightThird,
        "topThird": L10n.commandDefaultNameTopThird,
        "bottomThird": L10n.commandDefaultNameBottomThird,
        "leftTwoThirds": L10n.commandDefaultNameLeftTwoThirds,
        "centerTwoThirds": L10n.commandDefaultNameCenterTwoThirds,
        "rightTwoThirds": L10n.commandDefaultNameRightTwoThirds,
        "topTwoThirds": L10n.commandDefaultNameTopTwoThirds,
        "bottomTwoThirds": L10n.commandDefaultNameBottomTwoThirds,
        "nextDisplay": L10n.commandDefaultNameNextDisplay,
        "previousDisplay": L10n.commandDefaultNamePreviousDisplay,
        "maximize": L10n.commandDefaultNameMaximize,
        "center": L10n.commandDefaultNameCenter,
        "restore": L10n.commandDefaultNameRestore,
        "stayOnTop": L10n.commandDefaultNameStayOnTop,
    ]

    @Test func defaultCommandNamesMatchTexts() {
        let commands = DefaultCommands.horizontal + DefaultCommands.vertical
            + CommandAxis.allCases.map(DefaultCommands.stayOnTop(axis:))
        for command in commands {
            let id = command.id.hasPrefix("vertical.") ? String(command.id.dropFirst("vertical.".count)) : command.id
            #expect(command.name == Self.names[id], "\(command.id)")
        }
    }
}
