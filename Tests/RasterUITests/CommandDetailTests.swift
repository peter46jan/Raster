import AppKit
import Foundation
import RasterCore
import Testing
@testable import RasterUI

/// Detailkolom van Commands: welke kaarten, hun maten, de selectie in `SettingsNavigation` en het titelveld in de
/// titelbalkzone.
@MainActor
struct CommandDetailTests {
    // MARK: - Kaarten en maten

    @Test func cardsPerKindOfCommand() throws {
        let left = try #require(DefaultCommands.command("left"))
        let center = try #require(DefaultCommands.command("center"))
        let new = Command(id: "new", name: "Command", axis: .horizontal, group: .custom,
                          action: .area(GridArea(segments: [])), dragZones: GridArea(segments: []))
        #expect(CommandDetailCards.cards(for: left) == [.target, .shortcut, .activation, .menuBar, .greenButton])
        #expect(CommandDetailCards.cards(for: center) == [.shortcut, .menuBar, .greenButton])
        #expect(CommandDetailCards.cards(for: new) == [.target, .shortcut, .activation, .menuBar, .greenButton])
        // Een gebied zonder sleepzones: geen activeringsraster.
        var noZones = left
        noZones.dragZones = nil
        #expect(CommandDetailCards.cards(for: noZones) == [.target, .shortcut, .menuBar, .greenButton])
    }

    /// Vaste maten: kaarten 306, 86 en 296 hoog, raster op x 52 en 51, sneltoetsveld 458 breed.
    @Test func metricsMatchLayout() {
        #expect(CommandDetailMetrics.targetHeight(.landscape) == 306)
        #expect(CommandDetailMetrics.targetHeight(.portrait) == 498)
        #expect(CommandDetailMetrics.shortcutHeight == 86)
        #expect(CommandDetailMetrics.shortcutWidth == 458)
        #expect(CommandDetailMetrics.activationHeight(.landscape) == 296)
        #expect(CommandDetailMetrics.activationHeight(.portrait) == 488)
        #expect(CommandDetailMetrics.centered(TargetAreaGrid.size(of: .landscape).width) == 52)
        #expect(CommandDetailMetrics.centered(ActivationAreaGrid.size(of: .landscape).width) == 51)
        // Kaarten op venster-y 74 / 398 / 502 (koplijn 51, inhoud vanaf 52).
        let first = SettingsMetrics.headerHeight + 1 + CommandDetail.topInset
        let second = first + CommandDetailMetrics.targetHeight(.landscape) + CommandDetail.cardSpacing
        let third = second + CommandDetailMetrics.shortcutHeight + CommandDetail.cardSpacing
        #expect([first, second, third] == [74, 398, 502])
    }

    // MARK: - Selectie en weggaan

    @Test func selectionSurvivesSwitchingPanels() {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let controller = fixture.controller
        #expect(controller.navigation.selectedCommandID == "left")
        controller.select(.commands, animate: false)
        controller.navigation.selectedCommandID = "vertical.topThird"
        controller.select(.preferences, animate: false)
        controller.select(.commands, animate: false)
        #expect(controller.navigation.selectedCommandID == "vertical.topThird")
    }

    /// De (verborgen) venstertitel volgt het paneel, voor het Venster-menu en Mission Control.
    @Test func windowTitleFollowsThePanel() {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let controller = fixture.controller
        let window = fixture.window()
        #expect(window.title == "Preferences")
        controller.select(.commands, animate: false)
        #expect(window.title == "Commands")
        controller.select(.preferences, animate: false)
        #expect(window.title == "Preferences")

        // Een venster dat in Commands begint, heeft meteen die titel.
        let other = Fixture()
        defer { other.tearDown() }
        other.controller.navigation.panel = .commands
        #expect(other.window().title == "Commands")
    }

    @Test func switchingPanelsDiscardsAnIncompleteSelectionAndStopsRecording() throws {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let controller = fixture.controller, model = fixture.model
        controller.select(.commands, animate: false)
        let new = model.addCustom(axis: .horizontal)
        controller.navigation.selectedCommandID = new.id
        model.startRecording(for: new.id)
        controller.select(.preferences, animate: false)
        #expect(model.command(new.id) == nil)
        #expect(!model.isRecording)
        // De buur (het laatste commando van Horizontal) is gekozen.
        let selected = try #require(controller.navigation.selectedCommandID)
        #expect(model.command(selected)?.axis == .horizontal)
        #expect(selected == model.lists.horizontal.commands.last?.id)
    }

    @Test func closingTheWindowDiscardsAnIncompleteCommand() {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let controller = fixture.controller, model = fixture.model
        let window = fixture.window()
        controller.select(.commands, animate: false)
        let new = model.addCustom(axis: .vertical)
        controller.navigation.selectedCommandID = new.id
        NotificationCenter.default.post(name: NSWindow.willCloseNotification, object: window)
        #expect(model.command(new.id) == nil)
        #expect(controller.navigation.selectedCommandID.flatMap(model.command)?.axis == .vertical)
    }

    @Test func aCompleteSelectionStaysWhenLeaving() {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let controller = fixture.controller, model = fixture.model
        controller.select(.commands, animate: false)
        controller.navigation.selectedCommandID = "right"
        model.startRecording(for: "right")
        controller.select(.preferences, animate: false)
        #expect(controller.navigation.selectedCommandID == "right")
        #expect(!model.isRecording)
    }

    /// Verdwijnt het gekozen commando terwijl Preferences open is (Restore Defaults), dan kiest Commands het eerste
    /// commando van dezelfde as.
    @Test func vanishedSelectionFallsBackToTheFirstCommandOfItsAxis() {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let controller = fixture.controller, model = fixture.model
        controller.select(.commands, animate: false)
        let custom = model.addCustom(axis: .vertical)
        model.setArea(GridArea(GridRect(0, 0, 2, 2)), for: custom.id)
        controller.navigation.selectedCommandID = custom.id
        controller.select(.preferences, animate: false)
        model.resetAll()
        controller.navigation.ensureCommandSelection(in: model)
        #expect(controller.navigation.selectedCommandID == "vertical.left")
        // Een bestaande selectie blijft.
        controller.navigation.selectedCommandID = "right"
        controller.navigation.ensureCommandSelection(in: model)
        #expect(controller.navigation.selectedCommandID == "right")
    }

    // MARK: - Titelveld in de titelbalkzone

    /// Sluiten tijdens het bewerken van de naam bewaart de getypte naam (het venster blijft bestaan, dus zonder
    /// `makeFirstResponder(nil)` zou het veld zijn focus nooit kwijtraken).
    @Test func closingWhileRenamingKeepsTheTypedName() throws {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let window = fixture.window()
        fixture.controller.select(.commands, animate: false)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        let fields = (window.contentView?.subviewsRecursively ?? []).compactMap { $0 as? NSTextField }
        let field = try #require(fields.first { $0.isEditable })
        #expect(window.makeFirstResponder(field))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.selectAll(nil)
        editor.insertText("Links", replacementRange: editor.selectedRange())
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        #expect(fixture.model.command("left")?.name == "Left", "nog niet bewaard tijdens het typen")
        NotificationCenter.default.post(name: NSWindow.willCloseNotification, object: window)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        #expect(fixture.model.command("left")?.name == "Links")
    }

    /// De naam staat in de titelbalkzone (0–52) van een venster met `fullSizeContentView`: een klik erop moet bij het
    /// tekstveld aankomen en niet bij de titelbalk (die het venster zou verslepen).
    @Test func clickOnTheTitleReachesTheTextField() throws {
        let fixture = Fixture()
        defer { fixture.tearDown() }
        let window = fixture.window()
        fixture.controller.select(.commands, animate: false)
        window.contentView?.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        let fields = (window.contentView?.subviewsRecursively ?? []).compactMap { $0 as? NSTextField }
            .filter(\.isEditable)
        let field = try #require(fields.first, "het titelveld is een NSTextField")
        let frame = field.convert(field.bounds, to: nil)
        // Venstercoördinaten (oorsprong linksonder): de kop beslaat de bovenste 51 pt.
        let height = window.contentLayoutRect.maxY
        #expect(frame.minY >= height - SettingsMetrics.headerHeight - 1, "het veld staat in de kop")
        let themeFrame = try #require(window.contentView?.superview)
        for point in [CGPoint(x: frame.minX + 8, y: frame.midY), CGPoint(x: frame.midX, y: frame.midY)] {
            let hit = try #require(themeFrame.hitTest(point), "\(point)")
            #expect(hit === field || hit.isDescendant(of: field), "\(point): \(type(of: hit))")
            #expect(!hit.mouseDownCanMoveWindow, "\(point)")
        }
    }
}

/// Controller met een eigen commands.json en voorkeuren in het geheugen (niets in ~/Library/Preferences).
@MainActor
private struct Fixture {
    let file = FileManager.default.temporaryDirectory.appending(path: "raster-detail-\(UUID().uuidString).json")
    let model: CommandsModel
    let controller: SettingsWindowController

    init() {
        _ = NSApplication.shared
        model = CommandsModel(store: CommandStore(fileURL: file))
        controller = SettingsWindowController(
            model: model, snapping: SnappingSettings(state: SnappingState(), set: { _ in }),
            settings: AppSettings(storage: InMemorySettingsStorage()),
            loginItem: LoginItemState(), onShow: {}, onReset: { _ in })
    }

    /// Een (niet getoond) instellingenvenster.
    func window() -> NSWindow {
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: SettingsPanel.preferences.width,
                                                  height: SettingsMetrics.height),
                              styleMask: SettingsWindowController.styleMask, backing: .buffered, defer: false)
        controller.install(in: window)
        return window
    }

    func tearDown() {
        model.cancelRecording()
        try? FileManager.default.removeItem(at: file)
    }
}

private extension NSView {
    var subviewsRecursively: [NSView] { subviews + subviews.flatMap(\.subviewsRecursively) }
}
