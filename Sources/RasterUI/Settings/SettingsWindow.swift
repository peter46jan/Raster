import AppKit
import RasterCore
import Observation
import SwiftUI

/// Of slepen naar rand aan staat en of de muisbewaking ook echt draait.
@MainActor
@Observable
package final class SnappingState {
    var isEnabled = false
    var isRunning = false

    package init() {}
}

/// Wat "Herstellen naar standaard" terugzet.
package enum ResetScope {
    case all, commands, preferences
}

/// Wat het paneel Preferences van de app nodig heeft voor slepen naar rand.
package struct SnappingSettings {
    let state: SnappingState
    let set: @MainActor (Bool) -> Void

    package init(state: SnappingState, set: @escaping @MainActor (Bool) -> Void) {
        self.state = state
        self.set = set
    }
}

@MainActor
func appName(_ bundleID: String) -> String {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
    return FileManager.default.displayName(atPath: url.path)
}

/// De twee panelen van het instellingenvenster, in de volgorde van de zijbalk.
package enum SettingsPanel: CaseIterable, Hashable {
    case preferences, commands

    /// Vensterbreedte: Preferences gemeten, Commands geschat (70 + 1 + 275 + 1 + 528; de rechterrand stond niet in
    /// de opname).
    package var width: CGFloat {
        switch self {
        case .preferences: 601
        case .commands: 875
        }
    }

    /// Venstertitel (verborgen, maar zichtbaar in het Venster-menu en Mission Control).
    var title: String {
        switch self {
        case .preferences: L10n.settingsContentTitlePreferences
        case .commands: L10n.settingsContentTitleCommands
        }
    }

    var tooltip: String {
        switch self {
        case .preferences: L10n.navigationPathPreferencesTitle
        case .commands: L10n.navigationPathCommandsTitle
        }
    }

    @MainActor var icon: NSImage {
        switch self {
        case .preferences: RasterIcons.preferences
        case .commands: RasterIcons.commands
        }
    }
}

/// Maten van het venster die meerdere views delen (pt).
package enum SettingsMetrics {
    package static let height: CGFloat = 830
    /// Zijbalk zonder de lijn rechts ervan.
    static let sidebarWidth: CGFloat = 70
    /// Kopbalk zonder de lijn eronder; de inhoud begint op 52.
    static let headerHeight: CGFloat = 51
    /// Lijstkolom van Commands, zonder de kolomlijn.
    static let listWidth: CGFloat = 275
}

/// Het gekozen paneel en het gekozen commando, gedeeld door het venster (breedte, weggooien bij sluiten) en de inhoud.
@MainActor
@Observable
package final class SettingsNavigation {
    package var panel = SettingsPanel.preferences
    /// Het commando in Commands; blijft bewaard bij wisselen van paneel en sluiten (standaard "Left").
    package var selectedCommandID: String? = "left"
    /// As van het gekozen commando bij het verlaten van Commands: verdwijnt het commando intussen (bijv. door
    /// "Restore Defaults"), dan kiest Commands het eerste commando van deze as.
    var lastCommandAxis = CommandAxis.horizontal
}

/// Inhoud van het instellingenvenster: zijbalk, lijn en het gekozen paneel, over de hele hoogte (ook onder de
/// doorzichtige titelbalk met de verkeerslichten). De panelen tekenen zelf hun kop en inhoud.
struct SettingsRoot: View {
    let navigation: SettingsNavigation
    let model: CommandsModel
    let snapping: SnappingSettings
    let settings: AppSettings
    let loginItem: LoginItemState
    let onReset: (ResetScope) -> Void
    let select: (SettingsPanel) -> Void

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: navigation.panel, select: select)
            SeparatorLine(axis: .vertical, isSidebarEdge: true)
            switch navigation.panel {
            case .preferences:
                PreferencesPanel(model: model, snapping: snapping, settings: settings, loginItem: loginItem,
                                 onReset: onReset)
            case .commands:
                CommandsPanel(model: model, navigation: navigation)
            }
        }
        .ignoresSafeArea()
    }
}

/// Kopbalk van een paneel of kolom: 51 pt `toolbar` met de titel (SF 15 semibold, basislijn 31) op `leading` pt
/// van de linkerkant, en een lijn eronder. In een inactief venster is de titel grijs, zoals bij AppKit.
struct PanelHeader: View {
    let title: String
    let leading: CGFloat

    @Environment(\.controlActiveState) private var activeState

    var body: some View {
        VStack(spacing: 0) {
            BaselineStack(baselines: [31], bottom: SettingsMetrics.headerHeight - 31) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(nsColor: activeState == .inactive ? .secondaryLabelColor : .labelColor))
                    .lineLimit(1)
            }
            .padding(.leading, leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: SettingsMetrics.headerHeight)
            .background(RasterColor.toolbar.color)
            SeparatorLine(axis: .horizontal)
        }
    }
}

/// Lijn van 1 pt (kopbalk, kolommen, zijbalk): `separatorColor` (zwart 10 %) op de kleur van de kopbalk, zodat hij
/// overal 225 is en niet afhangt van wat er achter het venster ligt. De lijn naast de zijbalk is
/// donkerder (gemeten 218, op het zijbalkmateriaal); donker geschat.
struct SeparatorLine: View {
    let axis: Axis
    var isSidebarEdge = false

    var body: some View {
        Group {
            if isSidebarEdge {
                Rectangle().fill(Color(nsColor: Self.sidebarEdge))
            } else {
                Rectangle().fill(Color(nsColor: .separatorColor)).background(RasterColor.toolbar.color)
            }
        }
        .frame(width: axis == .vertical ? 1 : nil, height: axis == .horizontal ? 1 : nil)
    }

    private static let sidebarEdge = NSColor(name: nil) { appearance in
        NSColor(white: appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? 0.2 : 218 / 255, alpha: 1)
    }
}

/// Zijbalk van 70 pt met zijbalkmateriaal en een knop per paneel: 44 × 44 op x 13, de eerste op y 62 (onder de
/// verkeerslichten), 5 pt ertussen.
private struct SettingsSidebar: View {
    let selection: SettingsPanel
    let select: (SettingsPanel) -> Void

    var body: some View {
        VStack(spacing: 5) {
            ForEach(SettingsPanel.allCases, id: \.self) { panel in
                SidebarButton(panel: panel, isSelected: panel == selection) { select(panel) }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 62)
        .frame(width: SettingsMetrics.sidebarWidth)
        .frame(maxHeight: .infinity)
        .background(VisualEffectBackground(material: .sidebar))
    }
}

/// Knop in de zijbalk: icoon 24 × 24 in het midden. Geselecteerd: gevuld met de accentkleur (inactief venster:
/// grijs) en het icoon in `sidebarItemIcon`; anders het icoon zwart (donker: wit) 70 %, in een inactief venster 42 %,
/// en bij hover `sidebarItemHover`.
private struct SidebarButton: View {
    let panel: SettingsPanel
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.controlActiveState) private var activeState
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            TemplateImage(image: panel.icon, color: iconColor)
                .frame(width: 24, height: 24)
                .frame(width: 44, height: 44)
                .background(background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(panel.tooltip)
        .accessibilityLabel(panel.tooltip)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var background: Color {
        if isSelected { return activeState == .inactive ? Color(nsColor: Self.inactiveSelection) : RasterColor.accent }
        return isHovered ? RasterColor.sidebarItemHover.color : .clear
    }

    private var iconColor: NSColor {
        if isSelected { return RasterColor.sidebarItemIcon.nsColor }
        return activeState == .inactive ? Self.inactiveIcon : Self.icon
    }

    /// Selectie in een inactief venster: gemeten sRGB 164; donker geschat.
    private static let inactiveSelection = NSColor(name: nil) { appearance in
        NSColor(white: appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? 0.4 : 164 / 255, alpha: 1)
    }

    /// Niet-geselecteerd icoon: gemeten 68 op het zijbalkmateriaal (227), dus zwart 70 %; in een inactief venster
    /// gemeten 133 op 231, dus zwart 42 %.
    private static let icon = iconColor(alpha: 0.7)
    private static let inactiveIcon = iconColor(alpha: 0.42)

    private static func iconColor(alpha: CGFloat) -> NSColor {
        NSColor(name: nil) { appearance in
            NSColor(white: appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? 1 : 0, alpha: alpha)
        }
    }
}

/// Materiaal van het systeem achter de vensterinhoud (zijbalk), volgt actief/inactief zoals AppKit.
private struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

@MainActor
package final class SettingsWindowController {
    /// Doorzichtige titelbalk over de inhoud, niet te vergroten; de groene knop is verborgen.
    package static let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]

    package let navigation = SettingsNavigation()
    private let model: CommandsModel
    private let snapping: SnappingSettings
    private let settings: AppSettings
    private let loginItem: LoginItemState
    private let onShow: () -> Void
    private let onReset: (ResetScope) -> Void
    private(set) var window: NSWindow?

    package init(model: CommandsModel, snapping: SnappingSettings, settings: AppSettings, loginItem: LoginItemState,
                 onShow: @escaping () -> Void, onReset: @escaping (ResetScope) -> Void) {
        self.model = model
        self.snapping = snapping
        self.settings = settings
        self.loginItem = loginItem
        self.onShow = onShow
        self.onReset = onReset
    }

    func show() {
        onShow()
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: navigation.panel.width, height: SettingsMetrics.height),
                                  styleMask: Self.styleMask, backing: .buffered, defer: false)
            install(in: window)
            window.center()
        }
        NSApp.unhide(nil)
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    /// Richt een (nog niet getoond) venster in als instellingenvenster; de render-test geeft er zelf een.
    package func install(in window: NSWindow) {
        window.title = navigation.panel.title
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = false
        // Een lege toolbar maakt de titelbalk 52 pt hoog: macOS zet de verkeerslichten dan zelf op (26, 26) en
        // (46, 26), midden in de kopbalk, en geeft het venster de grotere hoekradius.
        window.toolbar = NSToolbar(identifier: "RasterSettings")
        window.toolbarStyle = .unified
        window.titlebarSeparatorStyle = .none
        window.standardWindowButton(.zoomButton)?.isHidden = true
        let host = NSHostingView(rootView: SettingsRoot(
            navigation: navigation, model: model, snapping: snapping, settings: settings, loginItem: loginItem,
            onReset: onReset, select: { [weak self] panel in self?.select(panel) }))
        // De vensterbreedte hoort bij het paneel; SwiftUI mag het venster niet groter of kleiner maken.
        host.sizingOptions = []
        // De inhoud loopt onder de titelbalk door en tekent de kopbalk zelf: geen veilige zone van het venster.
        host.safeAreaRegions = []
        window.contentView = host
        resize(window, animate: false)

        // De inlogstatus kan buiten Raster veranderen; bij het actief worden van het venster opnieuw lezen.
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.loginItem.refresh() }
        }
        // Sluiten of de focus kwijtraken tijdens opnemen: opname stoppen en sneltoetsen weer aanzetten.
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.cancelRecording() }
        }
        // Sluiten: ook een onvolledig commando zonder vraag weggooien.
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                // Eerst het bewerken afsluiten (het titelveld bewaart dan de getypte naam): het venster blijft bestaan,
                // dus zonder dit verdwijnt er geen view en raakt het veld zijn focus niet kwijt.
                _ = self?.window?.makeFirstResponder(nil)
                self?.leaveCommands()
            }
            DispatchQueue.main.async {
                MainActor.assumeIsolated { NSApp.yieldFocusIfIdle() }
            }
        }
        self.window = window
    }

    /// Ander paneel: opname stoppen, een onvolledig commando zonder vraag weggooien en het venster (geanimeerd) op de
    /// breedte van het paneel brengen.
    package func select(_ panel: SettingsPanel, animate: Bool = true) {
        guard panel != navigation.panel else { return }
        leaveCommands()
        navigation.panel = panel
        window?.title = panel.title
        if let window { resize(window, animate: animate) }
    }

    /// Weg uit Commands (ander paneel of venster dicht): opname stoppen en een nieuw commando zonder gebied weggooien;
    /// was dat het gekozen commando, dan wordt de buur gekozen.
    private func leaveCommands() {
        model.cancelRecording()
        if let axis = navigation.selectedCommandID.flatMap(model.command)?.axis { navigation.lastCommandAxis = axis }
        let before = model.lists
        guard before.hasIncomplete else { return }
        model.discardIncomplete()
        navigation.repairCommandSelection(after: before, in: model)
    }

    /// Breedte van het paneel en vaste hoogte; de linkerbovenhoek blijft staan, behalve als het venster dan rechts
    /// buiten het scherm zou vallen: dan schuift het zo ver naar links als nodig.
    private func resize(_ window: NSWindow, animate: Bool) {
        var frame = window.frame
        let top = frame.maxY
        frame.size = CGSize(width: navigation.panel.width, height: SettingsMetrics.height)
        frame.origin.y = top - frame.height
        if let visible = window.screen?.visibleFrame, frame.maxX > visible.maxX {
            frame.origin.x = max(visible.minX, visible.maxX - frame.width)
        }
        guard frame != window.frame else { return }
        window.setFrame(frame, display: true, animate: animate && window.isVisible)
    }
}
