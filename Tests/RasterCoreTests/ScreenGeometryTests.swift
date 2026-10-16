import CoreGraphics
import Testing
@testable import RasterCore

struct ScreenGeometryTests {
    @Test func titleBarButtonStrip() {
        let window = CGRect(x: 100, y: 200, width: 800, height: 600)
        #expect(ScreenGeometry.isInTitleBarButtons(CGPoint(x: 150, y: 215), windowFrame: window))
        #expect(ScreenGeometry.isInTitleBarButtons(CGPoint(x: 190, y: 240), windowFrame: window))
        #expect(!ScreenGeometry.isInTitleBarButtons(CGPoint(x: 191, y: 215), windowFrame: window))
        #expect(!ScreenGeometry.isInTitleBarButtons(CGPoint(x: 150, y: 241), windowFrame: window))
        #expect(!ScreenGeometry.isInTitleBarButtons(CGPoint(x: 99, y: 215), windowFrame: window))
        // Een klein venster: de strook blijft binnen het venster.
        let tiny = CGRect(x: 0, y: 0, width: 50, height: 20)
        #expect(!ScreenGeometry.isInTitleBarButtons(CGPoint(x: 60, y: 10), windowFrame: tiny))
    }

    @Test func flipMainScreenVisibleFrame() {
        // Cocoa: oorsprong linksonder. Hoofdscherm 1117 hoog, menubalk 38.
        let cocoa = CGRect(x: 0, y: 0, width: 1728, height: 1079)
        #expect(ScreenGeometry.flip(cocoa, mainScreenHeight: 1117) == CGRect(x: 0, y: 38, width: 1728, height: 1079))
    }

    @Test func flipScreenAboveAndLeftBelow() {
        let above = CGRect(x: 0, y: 1117, width: 1920, height: 1080)
        #expect(ScreenGeometry.flip(above, mainScreenHeight: 1117) == CGRect(x: 0, y: -1080, width: 1920, height: 1080))
        let leftLow = CGRect(x: -1080, y: -500, width: 1080, height: 1920)
        #expect(ScreenGeometry.flip(leftLow, mainScreenHeight: 1117) == CGRect(x: -1080, y: -303, width: 1080, height: 1920))
    }

    @Test func flipTwiceIsIdentity() {
        let rect = CGRect(x: 12, y: -40, width: 300, height: 200)
        #expect(ScreenGeometry.flip(ScreenGeometry.flip(rect, mainScreenHeight: 900), mainScreenHeight: 900) == rect)
    }

    let a = ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1728, height: 1117), visibleFrame: CGRect(x: 0, y: 38, width: 1728, height: 1079))
    let b = ScreenInfo(frame: CGRect(x: 1728, y: 0, width: 1920, height: 1080), visibleFrame: CGRect(x: 1728, y: 0, width: 1920, height: 1080))
    let c = ScreenInfo(frame: CGRect(x: -1080, y: -303, width: 1080, height: 1920), visibleFrame: CGRect(x: -1080, y: -303, width: 1080, height: 1920))

    @Test func screenWithLargestOverlap() {
        let window = CGRect(x: 1600, y: 100, width: 400, height: 300)
        #expect(ScreenGeometry.screenIndex(for: window, in: [a, b]) == 1)
    }

    @Test func screenNearestWhenOffscreen() {
        #expect(ScreenGeometry.screenIndex(for: CGRect(x: 5000, y: 5000, width: 10, height: 10), in: [a, b]) == 1)
        #expect(ScreenGeometry.screenIndex(for: .zero, in: []) == nil)
    }

    @Test func neighborsLeftToRightWithWrap() {
        let screens = [b, a, c] // volgorde van links naar rechts: c (2), a (1), b (0)
        #expect(ScreenGeometry.neighbor(of: 1, in: screens, step: 1) == 0)
        #expect(ScreenGeometry.neighbor(of: 0, in: screens, step: 1) == 2)
        #expect(ScreenGeometry.neighbor(of: 2, in: screens, step: -1) == 0)
        #expect(ScreenGeometry.neighbor(of: 0, in: [a], step: 1) == 0)
    }

    @Test func translateKeepsRelativePlace() {
        let leftHalf = CGRect(x: 0, y: 38, width: 864, height: 1079)
        #expect(ScreenGeometry.translate(leftHalf, from: a.visibleFrame, to: b.visibleFrame) == CGRect(x: 1728, y: 0, width: 960, height: 1080))
        let rightThird = CGRect(x: 1152, y: 38, width: 576, height: 1079)
        #expect(ScreenGeometry.translate(rightThird, from: a.visibleFrame, to: b.visibleFrame) == CGRect(x: 3008, y: 0, width: 640, height: 1080))
    }

    @Test func translateFromPortraitToLandscape() {
        let portrait = CGRect(x: 1728, y: -200, width: 1080, height: 1890)
        let topHalf = CGRect(x: 1728, y: -200, width: 1080, height: 945)
        // 945 / 1890 * 1079 = 539,5 → 540.
        #expect(ScreenGeometry.translate(topHalf, from: portrait, to: a.visibleFrame) == CGRect(x: 0, y: 38, width: 1728, height: 540))
    }

    @Test func translateFromZeroSizeSourceOnlyClamps() {
        let source = CGRect(x: 0, y: 0, width: 0, height: 0)
        let frame = CGRect(x: 100, y: 100, width: 400, height: 300)
        #expect(ScreenGeometry.translate(frame, from: source, to: b.visibleFrame) == CGRect(x: 1728, y: 100, width: 400, height: 300))
    }

    @Test func translateClampsOversizedWindow() {
        let huge = CGRect(x: 0, y: 0, width: 2000, height: 1200)
        #expect(ScreenGeometry.translate(huge, from: a.visibleFrame, to: b.visibleFrame) == b.visibleFrame)
    }

    @Test func centered() {
        #expect(ScreenGeometry.centered(CGSize(width: 800, height: 600), in: a.visibleFrame) == CGRect(x: 464, y: 278, width: 800, height: 600))
        #expect(ScreenGeometry.centered(CGSize(width: 2000, height: 500), in: a.visibleFrame) == CGRect(x: 0, y: 328, width: 1728, height: 500))
    }
}
