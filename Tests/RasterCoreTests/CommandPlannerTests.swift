import CoreGraphics
import Testing
@testable import RasterCore

struct CommandPlannerTests {
    let a = ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1728, height: 1117), visibleFrame: CGRect(x: 0, y: 38, width: 1728, height: 1079))
    let b = ScreenInfo(frame: CGRect(x: 1728, y: 0, width: 1920, height: 1080), visibleFrame: CGRect(x: 1728, y: 0, width: 1920, height: 1080))
    let portrait = ScreenInfo(frame: CGRect(x: 1728, y: -200, width: 1080, height: 1890), visibleFrame: CGRect(x: 1728, y: -200, width: 1080, height: 1890))
    let window = CGRect(x: 100, y: 100, width: 800, height: 600)

    func plan(_ id: String, frame: CGRect? = nil, screens: [ScreenInfo]? = nil, index: Int = 0, canResize: Bool = true) -> CGRect? {
        let command = DefaultCommands.command(id)!
        return CommandPlanner.target(
            for: command.action, grid: command.axis.grid, frame: frame ?? window, screens: screens ?? [a],
            screenIndex: index, canResize: canResize)
    }

    @Test func areaUsesGridOfItsAxis() {
        #expect(plan("left") == CGRect(x: 0, y: 38, width: 864, height: 1079))
        #expect(plan("vertical.left", screens: [a, portrait], index: 1) == CGRect(x: 1728, y: -200, width: 540, height: 1890))
        // Het raster komt van de as van het commando, niet van het scherm: 8 van 24 kolommen tegenover 8 van 24 rijen.
        #expect(plan("leftThird", screens: [a, portrait], index: 1) == CGRect(x: 1728, y: -200, width: 360, height: 1890))
        #expect(plan("vertical.topThird", screens: [a, portrait], index: 1) == CGRect(x: 1728, y: -200, width: 1080, height: 630))
    }

    @Test func emptyAreaPlacesNothing() {
        #expect(CommandPlanner.target(
            for: .area(GridArea(segments: [])), grid: .landscape, frame: window, screens: [a], screenIndex: 0, canResize: true) == nil)
    }

    @Test func centerKeepsSize() {
        #expect(plan("center") == CGRect(x: 464, y: 278, width: 800, height: 600))
    }

    @Test func displaySwitch() {
        #expect(plan("nextDisplay") == nil)
        let leftHalf = CGRect(x: 0, y: 38, width: 864, height: 1079)
        #expect(plan("nextDisplay", frame: leftHalf, screens: [a, b]) == CGRect(x: 1728, y: 0, width: 960, height: 1080))
        #expect(plan("previousDisplay", frame: leftHalf, screens: [a, b]) == CGRect(x: 1728, y: 0, width: 960, height: 1080))
    }

    @Test func restoreAndStayOnTopHaveNoTarget() {
        #expect(plan("restore") == nil)
        #expect(CommandPlanner.target(
            for: .special(.stayOnTop), grid: .landscape, frame: window, screens: [a], screenIndex: 0, canResize: true) == nil)
    }

    @Test func fixedSizeWindowKeepsSizeInsideDestination() {
        #expect(plan("right", canResize: false) == CGRect(x: 864, y: 38, width: 800, height: 600))
        // 100/1728·1920 = 111,1 → 1839; (100−38)/1079·1080 = 62,06 → 62
        #expect(plan("nextDisplay", screens: [a, b], canResize: false) == CGRect(x: 1839, y: 62, width: 800, height: 600))
    }

    @Test func invalidScreenIndex() {
        #expect(plan("left", index: 3) == nil)
    }

    @Test func areaCommandsGetMarginsButCenterDoesNot() {
        let margins = WindowMargins(size: 10, fitTightly: false)
        let left = DefaultCommands.command("left")!
        let target = CommandPlanner.target(
            for: left.action, grid: .landscape, frame: CGRect(x: 100, y: 100, width: 400, height: 300),
            screens: [a], screenIndex: 0, canResize: true, margins: margins)
        #expect(target?.minX == a.visibleFrame.minX + 10)
        let centered = CommandPlanner.target(
            for: .special(.center), grid: .landscape, frame: CGRect(x: 100, y: 100, width: 400, height: 300),
            screens: [a], screenIndex: 0, canResize: true, margins: margins)
        #expect(centered == ScreenGeometry.centered(CGSize(width: 400, height: 300), in: a.visibleFrame))
    }
}
