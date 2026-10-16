import CoreGraphics
import Testing
@testable import RasterCore

struct GridTests {
    // Liggend scherm: visibleFrame in AX-coördinaten, menubalk van 38 pt.
    let landscape = CGRect(x: 0, y: 38, width: 1728, height: 1079)
    // Staand scherm rechts van het hoofdscherm, deels erboven.
    let portrait = CGRect(x: 1728, y: -200, width: 1080, height: 1890)

    @Test func gridSizeFollowsOrientation() {
        #expect(GridSize.for(CGSize(width: 1728, height: 1079)) == .landscape)
        #expect(GridSize.for(CGSize(width: 1080, height: 1890)) == .portrait)
        #expect(GridSize.landscape == GridSize(columns: 24, rows: 12))
        #expect(GridSize.portrait == GridSize(columns: 12, rows: 24))
    }

    @Test func landscapeAreas() {
        func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int) -> CGRect {
            GridModel.rect(for: GridArea(GridRect(x, y, w, h)), grid: .landscape, in: landscape)
        }
        #expect(rect(0, 0, 12, 12) == CGRect(x: 0, y: 38, width: 864, height: 1079))
        #expect(rect(12, 0, 12, 12) == CGRect(x: 864, y: 38, width: 864, height: 1079))
        // 38 + 1079 / 2 = 577,5 → 578: bovenste helft 540 hoog, onderste 539.
        #expect(rect(0, 0, 24, 6) == CGRect(x: 0, y: 38, width: 1728, height: 540))
        #expect(rect(0, 6, 24, 6) == CGRect(x: 0, y: 578, width: 1728, height: 539))
        #expect(rect(8, 0, 8, 12) == CGRect(x: 576, y: 38, width: 576, height: 1079))
        #expect(rect(4, 0, 16, 12) == CGRect(x: 288, y: 38, width: 1152, height: 1079))
        #expect(rect(0, 0, 24, 12) == landscape)
    }

    @Test func portraitAreas() {
        func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int) -> CGRect {
            GridModel.rect(for: GridArea(GridRect(x, y, w, h)), grid: .portrait, in: portrait)
        }
        #expect(rect(0, 0, 12, 8) == CGRect(x: 1728, y: -200, width: 1080, height: 630))
        #expect(rect(0, 12, 12, 12) == CGRect(x: 1728, y: 745, width: 1080, height: 945))
        #expect(rect(0, 0, 6, 24) == CGRect(x: 1728, y: -200, width: 540, height: 1890))
    }

    @Test func multipleSegmentsUseBoundingBox() {
        let area = GridArea(GridRect(0, 0, 1, 1), GridRect(23, 11, 1, 1))
        #expect(GridModel.rect(for: area, grid: .landscape, in: landscape) == landscape)
    }

    @Test func lastEdgeAlwaysTouchesFrame() {
        let odd = CGRect(x: 10.5, y: 20.25, width: 1001, height: 777)
        let right = GridModel.rect(for: GridArea(GridRect(16, 0, 8, 12)), grid: .landscape, in: odd)
        #expect(right.maxX == odd.maxX)
        #expect(right.maxY == odd.maxY)
    }

    @Test func selectionIsNormalizedAndInclusive() {
        #expect(GridSelection.rect(from: GridCell(column: 5, row: 2), to: GridCell(column: 2, row: 7)) == GridRect(2, 2, 4, 6))
        #expect(GridSelection.rect(from: GridCell(column: 3, row: 3), to: GridCell(column: 3, row: 3)) == GridRect(3, 3, 1, 1))
    }

    @Test func rectContainsCell() {
        let rect = GridRect(2, 2, 4, 6)
        #expect(rect.contains(column: 2, row: 2))
        #expect(rect.contains(column: 5, row: 7))
        #expect(!rect.contains(column: 6, row: 7))
        #expect(!rect.contains(column: 5, row: 8))
    }
}
