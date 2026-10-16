import Testing
@testable import RasterCore

struct PreferencesTests {
    @Test func hexColorsRoundTrip() {
        let color = RGBColor(hex: "#FF8000")
        #expect(color == RGBColor(red: 1, green: 128.0 / 255, blue: 0))
        #expect(color?.hex == "#FF8000")
        #expect(RGBColor(hex: "ff8000")?.hex == "#FF8000")
        #expect(RGBColor(red: 2, green: -1, blue: 0.5).hex == "#FF0080")
    }

    @Test func invalidHexIsNil() {
        #expect(RGBColor(hex: "") == nil)
        #expect(RGBColor(hex: "#12345") == nil)
        #expect(RGBColor(hex: "#GGGGGG") == nil)
    }

    @Test func valuesAreClampedToTheirRange() {
        #expect(70.clamped(to: PreferenceRange.margin) == 50)
        #expect((-3).clamped(to: PreferenceRange.margin) == 0)
        #expect(0.05.clamped(to: PreferenceRange.hoverDelay) == 0.1)
        #expect(0.clamped(to: PreferenceRange.edgeWidth) == 1)
        #expect(3.0.clamped(to: PreferenceRange.innerScale) == 2)
    }

    @Test func unknownRawValuesFallBack() {
        #expect(ZoomMenuStyle(rawValue: "x") == nil)
        #expect(ZoomMenuStyle.allCases.count == 3)
        #expect(PreviewAppearance.allCases.count == 5)
    }
}
