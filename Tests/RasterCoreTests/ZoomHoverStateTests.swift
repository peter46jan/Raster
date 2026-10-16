import Testing
@testable import RasterCore

struct ZoomHoverStateTests {
    typealias Rest = ZoomHoverState<Int>.Rest

    /// Of het menu verschijnt, per rustmoment.
    func shown(_ rests: [Rest]) -> [Bool] {
        var hover = ZoomHoverState<Int>(isSame: ==)
        return rests.map { hover.rest($0) }
    }

    @Test func menuAppearsOncePerButton() {
        #expect(shown([.button(1), .button(1), .button(2)]) == [true, false, true])
    }

    @Test func restingElsewhereOrWithTheModifierAllowsTheSameButtonAgain() {
        #expect(shown([.button(1), .elsewhere, .button(1), .suppressed, .button(1)]) == [true, false, true, false, true])
    }

    @Test func restingOnAnOwnWindowAllowsTheSameButtonAgain() {
        #expect(shown([.button(1), .ownWindow(menuOpen: false), .button(1)]) == [true, false, true])
    }

    @Test func restingOnTheOpenMenuKeepsTheButton() {
        // Van de knop naar het eigen menu en terug: geen tweede menu zolang het eerste open is.
        #expect(shown([.button(1), .ownWindow(menuOpen: true), .button(1)]) == [true, false, false])
    }

    @Test func resetForgetsTheButton() {
        var hover = ZoomHoverState<Int>(isSame: ==)
        let first = hover.rest(.button(1))
        hover.reset()
        let again = hover.rest(.button(1))
        #expect(first && again)
    }
}
