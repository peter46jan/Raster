import CoreGraphics
import Testing
@testable import RasterCore

struct RestoreMemoryTests {
    let original = CGRect(x: 100, y: 100, width: 800, height: 600)
    let left = CGRect(x: 0, y: 38, width: 864, height: 1079)
    let right = CGRect(x: 864, y: 38, width: 864, height: 1079)

    @Test func restoreAfterOneAction() {
        var memory = RestoreMemory<String>(limit: 50)
        memory.record(before: original, after: left, for: "w")
        #expect(memory.take("w") == original)
        #expect(memory.take("w") == nil)
    }

    @Test func seriesKeepsFrameFromBeforeFirstAction() {
        var memory = RestoreMemory<String>(limit: 50)
        memory.record(before: original, after: left, for: "w")
        // Venster staat nog (binnen 2 pt) op `left` als de volgende actie komt.
        memory.record(before: left.offsetBy(dx: 1, dy: -1), after: right, for: "w")
        #expect(memory.take("w") == original)
    }

    @Test func manualMoveStartsNewSeries() {
        var memory = RestoreMemory<String>(limit: 50)
        memory.record(before: original, after: left, for: "w")
        let moved = CGRect(x: 300, y: 200, width: 864, height: 1079)
        memory.record(before: moved, after: right, for: "w")
        #expect(memory.take("w") == moved)
    }

    @Test func windowsAreSeparate() {
        var memory = RestoreMemory<String>(limit: 50)
        memory.record(before: original, after: left, for: "a")
        memory.record(before: right, after: left, for: "b")
        #expect(memory.take("a") == original)
        #expect(memory.take("b") == right)
    }

    @Test func limitDropsOldest() {
        var memory = RestoreMemory<Int>(limit: 2)
        memory.record(before: original, after: left, for: 1)
        memory.record(before: original, after: left, for: 2)
        memory.record(before: original, after: left, for: 3)
        #expect(memory.count == 2)
        #expect(memory.take(1) == nil)
        #expect(memory.take(3) == original)
    }

    @Test func usingAWindowAgainMakesItNewest() {
        var memory = RestoreMemory<Int>(limit: 2)
        memory.record(before: original, after: left, for: 1)
        memory.record(before: original, after: left, for: 2)
        memory.record(before: left, after: right, for: 1)
        memory.record(before: original, after: left, for: 3)
        #expect(memory.take(2) == nil)
        #expect(memory.take(1) == original)
    }

    @Test func snappedFrameOnlyWhileWindowStaysPut() {
        var memory = RestoreMemory<String>(limit: 50)
        memory.record(before: original, after: left, for: "w")
        #expect(memory.snappedFrame(for: "w", current: left.offsetBy(dx: 1, dy: 1)) == original)
        #expect(memory.snappedFrame(for: "w", current: right) == nil)
        #expect(memory.snappedFrame(for: "x", current: left) == nil)
        #expect(memory.count == 1) // alleen kijken, niet vergeten
    }

    @Test func containsOnlyRememberedWindows() {
        var memory = RestoreMemory<String>(limit: 50)
        #expect(!memory.contains("w"))
        memory.record(before: original, after: left, for: "w")
        #expect(memory.contains("w"))
        #expect(!memory.contains("x"))
        _ = memory.take("w")
        #expect(!memory.contains("w"))
    }
}
