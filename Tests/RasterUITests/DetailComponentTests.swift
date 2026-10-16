import AppKit
import Foundation
import RasterCore
import Testing
@testable import RasterUI

/// De bouwstenen van de detailkolom: breuken, rastermaten, de beslissingen van het activeringsraster en het opnemen van
/// een sneltoets met "This combination is taken".
@MainActor
struct DetailComponentTests {
    // MARK: - Breuken

    @Test func fractionIsReduced() {
        #expect(GridFraction.reduced(12, of: 24) == (1, 2))
        #expect(GridFraction.reduced(12, of: 12) == (1, 1))
        #expect(GridFraction.reduced(8, of: 24) == (1, 3))
        #expect(GridFraction.reduced(16, of: 24) == (2, 3))
        #expect(GridFraction.reduced(6, of: 12) == (1, 2))
        #expect(GridFraction.reduced(5, of: 24) == (5, 24))
        #expect(GridFraction.reduced(0, of: 24) == (0, 1))
        #expect(GridFraction.reduced(3, of: 0) == (0, 1))
    }

    @Test func fractionText() {
        #expect(GridFraction.text(12, of: 24) == "1/2")
        #expect(GridFraction.text(12, of: 12) == "1/1")
        #expect(GridFraction.text(8, of: 24) == "1/3")
        #expect(GridFraction.text(18, of: 24) == "3/4")
    }

    @Test func areaBounds() {
        #expect(GridArea(segments: []).bounds == nil)
        #expect(GridArea(GridRect(0, 0, 12, 12)).bounds == GridRect(0, 0, 12, 12))
        #expect(GridArea(GridRect(0, 1, 1, 2), GridRect(23, 1, 1, 2)).bounds == GridRect(0, 1, 24, 2))
    }

    // MARK: - Maten

    @Test func gridSizes() {
        #expect(TargetAreaGrid.size(of: .landscape) == CGSize(width: 382, height: 190))
        #expect(TargetAreaGrid.size(of: .portrait) == CGSize(width: 190, height: 382))
        #expect(ActivationAreaGrid.size(of: .landscape) == CGSize(width: 384, height: 192))
        #expect(ActivationAreaGrid.size(of: .portrait) == CGSize(width: 192, height: 384))
    }

    @Test func cellUnderPointIsClamped() {
        #expect(gridCell(at: CGPoint(x: 0, y: 0), pitch: 16, grid: .landscape) == GridCell(column: 0, row: 0))
        #expect(gridCell(at: CGPoint(x: 15.9, y: 16), pitch: 16, grid: .landscape) == GridCell(column: 0, row: 1))
        #expect(gridCell(at: CGPoint(x: -20, y: 500), pitch: 16, grid: .landscape) == GridCell(column: 0, row: 11))
        #expect(gridCell(at: CGPoint(x: 1000, y: -1), pitch: 16, grid: .landscape) == GridCell(column: 23, row: 0))
    }

    // MARK: - Activeringsraster

    private let leftZones = GridArea(GridRect(0, 3, 1, 6))
    private var others: [ActivationAreaGrid.OtherZones] {
        ActivationAreaGrid.others(for: DefaultCommands.horizontal[0], in: DefaultCommands.horizontal)
    }

    @Test func othersExcludeSelfAndDisabled() {
        var commands = DefaultCommands.horizontal
        let ids = ActivationAreaGrid.others(for: commands[0], in: commands).map(\.id)
        #expect(!ids.contains("left"))
        #expect(ids.contains("right") && ids.contains("maximize"))
        // Speciale commando's hebben geen zones; uitgeschakelde zones tellen niet mee.
        #expect(!ids.contains("center"))
        commands[1].dragZonesEnabled = false
        #expect(!ActivationAreaGrid.others(for: commands[0], in: commands).map(\.id).contains("right"))
    }

    @Test func hitFindsOwnThenOthers() {
        #expect(ActivationAreaGrid.hit(GridCell(column: 0, row: 5), zones: leftZones, others: others) == .own(0))
        guard case .other(let other, _) = ActivationAreaGrid.hit(GridCell(column: 23, row: 5), zones: leftZones,
                                                                  others: others) else {
            Issue.record("rechts hoort bij Right")
            return
        }
        #expect(other.id == "right")
        #expect(ActivationAreaGrid.hit(GridCell(column: 5, row: 5), zones: leftZones, others: others) == .empty)
    }

    @Test func clickOnOwnZoneRemovesIt() {
        let cell = GridCell(column: 0, row: 4)
        #expect(ActivationAreaGrid.action(from: cell, to: cell, zones: leftZones, others: others)
                == .change(GridArea(segments: [])))
    }

    @Test func clickOnOtherZoneAsks() {
        let cell = GridCell(column: 5, row: 11)
        guard case .askRemoveOther(let other, let at) = ActivationAreaGrid.action(from: cell, to: cell, zones: leftZones,
                                                                                    others: others) else {
            Issue.record("klik op een grijze zone vraagt eerst")
            return
        }
        #expect(other.id == "leftThird")
        #expect(at == cell)
    }

    @Test func clickOnEmptyCellAddsOneCell() {
        let cell = GridCell(column: 5, row: 5)
        #expect(ActivationAreaGrid.action(from: cell, to: cell, zones: leftZones, others: others)
                == .change(GridArea(GridRect(0, 3, 1, 6), GridRect(5, 5, 1, 1))))
    }

    @Test func dragAddsRectangle() {
        // Ook een sleep die op een eigen zone begint, voegt toe; eigen zones die erin vallen gaan erin op.
        let action = ActivationAreaGrid.action(from: GridCell(column: 0, row: 2), to: GridCell(column: 1, row: 9),
                                               zones: leftZones, others: others)
        #expect(action == .change(GridArea(GridRect(0, 2, 2, 8))))
        #expect(ActivationAreaGrid.adding(GridRect(5, 5, 2, 2), to: leftZones)
                == GridArea(GridRect(0, 3, 1, 6), GridRect(5, 5, 2, 2)))
    }

    @Test func removingIgnoresBadIndex() {
        #expect(ActivationAreaGrid.removing(3, from: leftZones) == leftZones)
        #expect(ActivationAreaGrid.removing(0, from: leftZones) == GridArea(segments: []))
    }

    // MARK: - Sneltoets opnemen

    private let controlOption: NSEvent.ModifierFlags = [.control, .option]

    private func makeModel() -> (CommandsModel, URL) {
        let url = FileManager.default.temporaryDirectory.appending(path: "detail-tests-\(UUID().uuidString).json")
        return (CommandsModel(store: CommandStore(fileURL: url)), url)
    }

    @Test func decisionPerKey() {
        let lists = CommandStore(fileURL: FileManager.default.temporaryDirectory
            .appending(path: "detail-tests-\(UUID().uuidString).json")).lists
        let decide = { (key: UInt16, flags: NSEvent.ModifierFlags, id: String) in
            CommandsModel.decision(keyCode: key, flags: flags, for: id, in: lists)
        }
        #expect(decide(53, [], "left") == .cancel)
        #expect(decide(51, [], "left") == .clear)
        #expect(decide(117, [], "left") == .clear)
        #expect(decide(37, [.shift], "left") == .invalid)
        // ⌃⌥▶ is van Right (Horizontal): bezet.
        #expect(decide(124, controlOption, "left") == .taken)
        // De eigen sneltoets opnieuw is niet bezet.
        #expect(decide(123, controlOption, "left") == .assign(Shortcut(keyCode: 123, modifiers: Shortcut.controlOption)))
        #expect(decide(37, controlOption, "left") == .assign(Shortcut(keyCode: 37, modifiers: Shortcut.controlOption)))
        // ⇧ en ⌘ tellen mee: ⌃⌥⇧▶ is vrij.
        #expect(decide(124, [.control, .option, .shift], "left")
                == .assign(Shortcut(keyCode: 124, modifiers: Shortcut.controlOption | Shortcut.shift)))
    }

    @Test func takenOnlyOnSameAxis() {
        let (model, url) = makeModel()
        defer { try? FileManager.default.removeItem(at: url) }
        let shortcut = Shortcut(keyCode: 37, modifiers: Shortcut.controlOption)
        model.setShortcut(shortcut, for: "vertical.left")
        // Op Horizontal vrij, op Vertical bezet.
        #expect(CommandsModel.decision(keyCode: 37, flags: controlOption, for: "left", in: model.lists)
                == .assign(shortcut))
        #expect(CommandsModel.decision(keyCode: 37, flags: controlOption, for: "vertical.right", in: model.lists)
                == .taken)
        // Een uitgeschakelde sneltoets is niet bezet.
        model.setShortcutEnabled(false, for: "vertical.left")
        #expect(CommandsModel.decision(keyCode: 37, flags: controlOption, for: "vertical.right", in: model.lists)
                == .assign(shortcut))
    }

    @Test func takenKeepsRecordingUntilNextKey() {
        let (model, url) = makeModel()
        defer { try? FileManager.default.removeItem(at: url) }
        let original = model.command("left")?.shortcut
        model.startRecording(for: "left")
        model.handleKey(keyCode: 124, flags: controlOption)
        #expect(model.recordingError == .taken)
        #expect(model.recordingID == "left")
        #expect(model.command("left")?.shortcut == original)

        // De volgende toets wist de fout en wijst toe.
        model.handleKey(keyCode: 37, flags: controlOption)
        #expect(model.recordingError == nil)
        #expect(model.recordingID == nil)
        #expect(model.command("left")?.shortcut == Shortcut(keyCode: 37, modifiers: Shortcut.controlOption))
    }

    @Test func cancelAndRestartClearError() {
        let (model, url) = makeModel()
        defer { try? FileManager.default.removeItem(at: url) }
        model.startRecording(for: "left")
        model.handleKey(keyCode: 124, flags: controlOption)
        #expect(model.recordingError == .taken)
        model.cancelRecording()
        #expect(model.recordingError == nil)
        model.startRecording(for: "left")
        model.handleKey(keyCode: 124, flags: controlOption)
        model.startRecording(for: "right")
        #expect(model.recordingError == nil)
        // ⎋ stopt zonder te wijzigen.
        model.handleKey(keyCode: 53, flags: [])
        #expect(model.recordingID == nil)
        #expect(model.command("right")?.shortcut == Shortcut(keyCode: 124, modifiers: Shortcut.controlOption))
    }

    // MARK: - Sneltoetsveld

    @Test func shortcutFieldTitle() {
        let shortcut = Shortcut(keyCode: 123, modifiers: Shortcut.controlOption)
        #expect(ShortcutField.title(shortcut: shortcut, isRecording: false, error: nil) == ("⌃⌥◀", .shortcut))
        #expect(ShortcutField.title(shortcut: nil, isRecording: false, error: nil)
                == (L10n.shortcutsFieldTitleView, .placeholder))
        #expect(ShortcutField.title(shortcut: shortcut, isRecording: true, error: nil)
                == (L10n.shortcutsFieldTitleEdit, .placeholder))
        #expect(ShortcutField.title(shortcut: shortcut, isRecording: true, error: .taken)
                == (L10n.shortcutsFieldTitleErrorTaken, .error))
    }
}
