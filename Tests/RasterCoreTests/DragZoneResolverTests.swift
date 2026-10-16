import CoreGraphics
import Testing
@testable import RasterCore

struct DragZoneResolverTests {
    // Kolommen 72 pt breed, rijen 1117/12 ≈ 93,1 pt hoog.
    let a = ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1728, height: 1117), visibleFrame: CGRect(x: 0, y: 38, width: 1728, height: 1079))
    // Staand: kolommen 90 pt, rijen 78,75 pt.
    let portrait = ScreenInfo(frame: CGRect(x: 1728, y: -200, width: 1080, height: 1890), visibleFrame: CGRect(x: 1728, y: -200, width: 1080, height: 1890))

    func zone(_ x: CGFloat, _ y: CGFloat, lists: CommandLists = .standard) -> String? {
        DragZoneResolver.match(cursor: CGPoint(x: x, y: y), screens: [a, portrait], lists: lists)?.commandID
    }

    /// De standaardlijsten met `extra` onderaan Horizontal.
    func standard(plus extra: Command) -> CommandLists {
        var lists = CommandLists.standard
        lists.horizontal = CommandList(commands: lists.horizontal.commands + [extra])
        return lists
    }

    /// Alleen het standaardcommando `id`, in de lijst van zijn as.
    func only(_ id: String) -> CommandLists {
        let command = DefaultCommands.command(id)!
        var lists = CommandLists.empty
        lists[command.axis] = CommandList(commands: [command])
        return lists
    }

    @Test func customCommandsTakePriorityOverDefaults() {
        var custom = Command(
            id: "custom", name: "Eigen", axis: .horizontal, group: .custom,
            action: .area(GridArea(GridRect(0, 0, 4, 4))), dragZones: GridArea(GridRect(0, 3, 1, 6))
        )
        #expect(zone(0, 500, lists: standard(plus: custom)) == "custom")
        custom.dragZonesEnabled = false
        #expect(zone(0, 500, lists: standard(plus: custom)) == "left")
    }

    @Test func incompleteCommandsHaveNoZones() {
        let custom = Command(
            id: "custom", name: "Eigen", axis: .horizontal, group: .custom,
            action: .area(GridArea(segments: [])), dragZones: GridArea(GridRect(0, 3, 1, 6))
        )
        #expect(zone(0, 500, lists: standard(plus: custom)) == "left")
        #expect(DragZoneResolver.zoneRects(on: a, lists: CommandLists(
            horizontal: CommandList(commands: [custom]), vertical: CommandList(commands: []))).isEmpty)
    }

    @Test func portraitScreenOnlyUsesVertical() {
        // Een Horizontal-zone over het hele raster telt op een staand scherm niet mee.
        let everywhere = Command(
            id: "custom", name: "Eigen", axis: .horizontal, group: .custom,
            action: .area(GridArea(GridRect(0, 0, 4, 4))), dragZones: GridArea(GridRect(0, 0, 24, 12))
        )
        #expect(zone(2228, 1689, lists: standard(plus: everywhere)) == "vertical.left")
        #expect(zone(0, 500, lists: standard(plus: everywhere)) == "custom")
        var lists = CommandLists.standard
        lists.vertical.commands[0].dragZonesEnabled = false // vertical.left
        #expect(zone(2228, 1689, lists: lists) == nil)
    }

    @Test func sideEdges() {
        #expect(zone(0, 500) == "left")
        #expect(zone(1727, 500) == "right")
        #expect(zone(0, 150) == "up")
        #expect(zone(0, 900) == "down")
    }

    @Test func edgeWidthIsSixPoints() {
        #expect(zone(5, 500) == "left")
        #expect(zone(6, 500) == nil)
        #expect(zone(1722, 500) == "right")
        #expect(zone(1721, 500) == nil)
    }

    @Test func cornersAndTop() {
        #expect(zone(0, 0) == "topLeft")
        #expect(zone(1727, 1116) == "bottomRight")
        #expect(zone(864, 0) == "maximize")
    }

    @Test func bottomEdgeThirds() {
        #expect(zone(200, 1116) == "leftThird")
        #expect(zone(580, 1116) == "leftTwoThirds")
        #expect(zone(864, 1116) == "centerThird")
        #expect(zone(1100, 1116) == "rightTwoThirds") // kolom 15
        #expect(zone(1400, 1116) == "rightThird")
    }

    @Test func secondRingCountsWithoutEdge() {
        #expect(zone(864, 1000) == "centerTwoThirds") // rij 10, kolom 12
        #expect(zone(864, 500) == nil)                // rij 5: te diep
    }

    @Test func portraitScreen() {
        let match = DragZoneResolver.match(cursor: CGPoint(x: 2228, y: 1689), screens: [a, portrait], lists: .standard)
        #expect(match == DragMatch(commandID: "vertical.left", screenIndex: 1))
        #expect(zone(2278, 1689) == "vertical.right")
        // Staand centerTwoThirds heeft zones (1,11,1,2) en (10,11,1,2): kolom 1 = x 1818–1908, rij 11 = y 666–745.
        #expect(zone(1863, 706) == "vertical.centerTwoThirds")
    }

    @Test func disabledCommandsAndOffscreen() {
        var lists = CommandLists.standard
        lists.horizontal.commands[0].dragZonesEnabled = false // left
        #expect(zone(0, 500, lists: lists) == nil)
        #expect(zone(5000, 5000) == nil)
    }

    func zone(_ x: CGFloat, _ y: CGFloat, scale: CGFloat) -> String? {
        DragZoneResolver.match(cursor: CGPoint(x: x, y: y), screens: [a, portrait], lists: .standard, innerScale: scale)?.commandID
    }

    @Test func smallerInnerZonesOnlyCountNearTheCellCenter() {
        #expect(zone(828, 977, scale: 0.5) == "centerTwoThirds")
        #expect(zone(795, 935, scale: 0.5) == nil)
        #expect(zone(795, 935, scale: 1) == "centerTwoThirds")
    }

    @Test func largerInnerZonesReachIntoTheNeighbouringCell() {
        // Rij 9 ligt dieper dan de tweede ring en telt normaal niet.
        #expect(zone(828, 915, scale: 1) == nil)
        #expect(zone(828, 915, scale: 1.5) == "centerTwoThirds")
        #expect(zone(828, 850, scale: 1.5) == nil)
    }

    @Test func edgeZonesIgnoreTheInnerScale() {
        #expect(zone(0, 500, scale: 0.5) == "left")
        #expect(zone(0, 500, scale: 2) == "left")
    }

    @Test func zoneRectsShowEdgeStripsMerged() {
        let left = only("left")
        let rects = DragZoneResolver.zoneRects(on: a, lists: left)
        #expect(rects.count == 1)
        let strip = rects[0]
        #expect(strip.minX == 0 && strip.width == 6)
        #expect(abs(strip.minY - 1117.0 * 3 / 12) < 0.01)
        #expect(abs(strip.height - 1117.0 * 6 / 12) < 0.01)
    }

    @Test func zoneRectsForTopRowAreOneStrip() {
        let maximize = only("maximize")
        #expect(DragZoneResolver.zoneRects(on: a, lists: maximize) == [CGRect(x: 72, y: 0, width: 1584, height: 6)])
    }

    @Test func zoneRectsForInnerCellsFollowTheScale() {
        let center = only("centerTwoThirds")
        let whole = DragZoneResolver.zoneRects(on: a, lists: center)
        #expect(whole.count == 1)
        #expect(abs(whole[0].width - 144) < 0.01)
        let half = DragZoneResolver.zoneRects(on: a, lists: center, innerScale: 0.5)
        #expect(half.count == 2)
        #expect(half.allSatisfy { abs($0.width - 36) < 0.01 })
    }

    @Test func zoneRectsSkipDisabledCommands() {
        var lists = only("left")
        lists.horizontal.commands[0].dragZonesEnabled = false
        #expect(DragZoneResolver.zoneRects(on: a, lists: lists).isEmpty)
    }

    @Test func ownCellWithAZoneWinsOverANearerNeighbourWithout() {
        // (790, 915) ligt in het getekende gebied van centerTwoThirds (x 774–882), maar cel (10, 10) is dichterbij en heeft geen zone.
        #expect(zone(790, 915, scale: 1.5) == "centerTwoThirds")
    }

    @Test func overlappingScaledZonesAreMerged() {
        let center = only("centerTwoThirds")
        let rects = DragZoneResolver.zoneRects(on: a, lists: center, innerScale: 2)
        #expect(rects.count == 1)
        #expect(abs(rects[0].width - 216) < 0.01)
    }

    @Test func innerScaleIsClampedToItsRange() {
        #expect(zone(828, 850, scale: 10) == zone(828, 850, scale: 2))
        let center = only("centerTwoThirds")
        #expect(DragZoneResolver.zoneRects(on: a, lists: center, innerScale: 10)
            == DragZoneResolver.zoneRects(on: a, lists: center, innerScale: 2))
    }
}
