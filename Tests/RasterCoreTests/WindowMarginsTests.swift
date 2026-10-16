import CoreGraphics
import Testing
@testable import RasterCore

struct WindowMarginsTests {
    let visible = CGRect(x: 0, y: 38, width: 1728, height: 1079)

    func rect(_ area: GridArea) -> CGRect {
        GridModel.rect(for: area, grid: .landscape, in: visible)
    }

    @Test func zeroMarginChangesNothing() {
        let left = rect(GridArea(GridRect(0, 0, 12, 12)))
        #expect(WindowMargins.none.apply(to: left, in: visible) == left)
    }

    @Test func halvesGetFullMarginAtEdgesAndHalfInside() {
        let margins = WindowMargins(size: 10, fitTightly: false)
        #expect(margins.apply(to: rect(GridArea(GridRect(0, 0, 12, 12))), in: visible) == CGRect(x: 10, y: 48, width: 849, height: 1059))
        #expect(margins.apply(to: rect(GridArea(GridRect(12, 0, 12, 12))), in: visible) == CGRect(x: 869, y: 48, width: 849, height: 1059))
    }

    @Test func neighboursHaveExactlyOneMarginBetweenThem() {
        let margins = WindowMargins(size: 10, fitTightly: false)
        let left = margins.apply(to: rect(GridArea(GridRect(0, 0, 8, 12))), in: visible)
        let center = margins.apply(to: rect(GridArea(GridRect(8, 0, 8, 12))), in: visible)
        let right = margins.apply(to: rect(GridArea(GridRect(16, 0, 8, 12))), in: visible)
        #expect(center.minX - left.maxX == 10)
        #expect(right.minX - center.maxX == 10)
        #expect(center == CGRect(x: 581, y: 48, width: 566, height: 1059))
    }

    @Test func cornerGetsFullMarginOnTwoSides() {
        let margins = WindowMargins(size: 10, fitTightly: false)
        let topLeft = rect(GridArea(GridRect(0, 0, 12, 6)))
        #expect(margins.apply(to: topLeft, in: visible)
            == CGRect(x: 10, y: 48, width: topLeft.width - 15, height: topLeft.height - 15))
    }

    @Test func fitTightlyKeepsScreenEdges() {
        let margins = WindowMargins(size: 10, fitTightly: true)
        #expect(margins.apply(to: rect(GridArea(GridRect(0, 0, 12, 12))), in: visible) == CGRect(x: 0, y: 38, width: 859, height: 1079))
        #expect(margins.apply(to: visible, in: visible) == visible)
    }

    @Test func maximizeGetsMarginAllAround() {
        let margins = WindowMargins(size: 10, fitTightly: false)
        #expect(margins.apply(to: visible, in: visible) == CGRect(x: 10, y: 48, width: 1708, height: 1059))
    }

    @Test func tooSmallRectStaysUnchanged() {
        let small = CGRect(x: 500, y: 500, width: 40, height: 40)
        #expect(WindowMargins(size: 50, fitTightly: false).apply(to: small, in: visible) == small)
    }

    @Test func oddMarginsStayOnWholePointsAndKeepOneMarginBetweenNeighbours() {
        let margins = WindowMargins(size: 5, fitTightly: false)
        let left = margins.apply(to: rect(GridArea(GridRect(0, 0, 8, 12))), in: visible)
        let center = margins.apply(to: rect(GridArea(GridRect(8, 0, 8, 12))), in: visible)
        let right = margins.apply(to: rect(GridArea(GridRect(16, 0, 8, 12))), in: visible)
        #expect(center.minX - left.maxX == 5)
        #expect(right.minX - center.maxX == 5)
        #expect(center == CGRect(x: 578, y: 43, width: 571, height: 1069))
        for value in [left.minX, left.maxX, center.minX, center.maxX, right.minX, right.maxX] {
            #expect(value == value.rounded())
        }
    }
}
