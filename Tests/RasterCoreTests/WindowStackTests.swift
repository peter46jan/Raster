import CoreGraphics
import Testing
@testable import RasterCore

struct WindowStackTests {
    let own: Int32 = 99
    let point = CGPoint(x: 120, y: 110)
    let target = WindowListEntry(bounds: CGRect(x: 100, y: 100, width: 800, height: 600), layer: 0, alpha: 1, pid: 10)

    func top(_ windows: [WindowListEntry]) -> CGRect? {
        WindowStack.topWindowFrame(at: point, in: windows, ownPID: own)
    }

    @Test func frontmostWindowContainingThePointWins() {
        let behind = WindowListEntry(bounds: CGRect(x: 0, y: 0, width: 1000, height: 1000), layer: 0, alpha: 1, pid: 11)
        #expect(top([target, behind]) == target.bounds)
    }

    @Test func windowsElsewhereAndAboveLayerZeroAreSkipped() {
        let elsewhere = WindowListEntry(bounds: CGRect(x: 500, y: 500, width: 10, height: 10), layer: 0, alpha: 1, pid: 12)
        let menuBar = WindowListEntry(bounds: CGRect(x: 0, y: 0, width: 1728, height: 1117), layer: 25, alpha: 1, pid: 13)
        #expect(top([elsewhere, menuBar, target]) == target.bounds)
    }

    @Test func fullyTransparentWindowsAreSkipped() {
        let invisible = WindowListEntry(bounds: CGRect(x: 0, y: 0, width: 1728, height: 1117), layer: 0, alpha: 0, pid: 14)
        #expect(top([invisible, target]) == target.bounds)
        let faint = WindowListEntry(bounds: CGRect(x: 0, y: 0, width: 1728, height: 1117), layer: 0, alpha: 0.2, pid: 14)
        #expect(top([faint, target]) == faint.bounds)
    }

    @Test func ownWindowOnTopGivesNil() {
        let mine = WindowListEntry(bounds: CGRect(x: 0, y: 0, width: 400, height: 400), layer: 0, alpha: 1, pid: own)
        #expect(top([mine, target]) == nil)
        #expect(top([]) == nil)
        let mineInvisible = WindowListEntry(bounds: CGRect(x: 0, y: 0, width: 400, height: 400), layer: 0, alpha: 0, pid: own)
        #expect(top([mineInvisible, target]) == target.bounds)
    }
}
