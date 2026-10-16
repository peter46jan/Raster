import AppKit
import RasterCore
import RasterSystem

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let snapWindowsKey = "snapWindows"

    // Model en voorkeuren pas na de controle op een tweede exemplaar aanmaken (lazy): het inlezen kan commands.json
    // omzetten of herstellen en de voorkeuren opschonen, en dat mag alleen het eerste exemplaar doen.
    private lazy var model = CommandsModel(store: CommandStore(fileURL: CommandStore.defaultURL))
    private let windows = WindowController()
    private let hotkeys = HotkeyManager()
    private let watcher = AccessibilityWatcher()
    private let permissionWindow = PermissionWindowController()
    private let snapPreview = SnapPreview()
    private let activationOverlay = ActivationOverlay()
    private lazy var settings = AppSettings()
    private let welcomeWindow = WelcomeWindowController()
    private lazy var zoomMonitor = ZoomButtonMonitor(windows: windows)
    private lazy var zoomMenu = ZoomButtonMenu(
        windows: windows,
        lists: { [weak self] in self?.model.lists ?? .empty },
        style: { [weak self] in self?.settings.zoomMenuStyle ?? .standard }
    )
    private lazy var dragMonitor = DragMonitor(windows: windows)
    private let tiling = TilingGuard(
        system: DomainPreferences(domain: "com.apple.WindowManager"),
        own: DomainPreferences(domain: Bundle.main.bundleIdentifier ?? "nl.jimlindenburg.raster")
    )
    private var statusMenu: StatusMenu?
    private var settingsWindow: SettingsWindowController?
    private let snappingState = SnappingState()
    private let loginItem = LoginItemState()
    private var isStarted = false
    private var isDuplicate = false
    /// De vraag over tegelen staat open (modaal); `applySnapping` wacht dan op het antwoord.
    private var isAskingAboutTiling = false
    /// Eerste start: de vraag over tegelen wacht tot het welkomstvenster dicht is, de inlogvraag voorbij is
    /// en Raster toestemming heeft (dus ook niet over het toestemmingsvenster heen).
    private var isFirstRunPending = false
    private var isWelcomeClosed = false
    private var terminateSignals: [DispatchSourceSignal] = []

    /// Slepen naar rand staat standaard aan.
    private var isSnappingEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.snapWindowsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.snapWindowsKey) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Een tweede exemplaar (bijv. dezelfde app vanuit een andere map) stopt meteen.
        if let bundleID = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
               .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && !$0.isTerminated }) {
            // Het tweede exemplaar mag bij het stoppen niets terugzetten: het eerste exemplaar beheert de tegelopties.
            isDuplicate = true
            NSApp.activate()
            let alert = NSAlert()
            alert.messageText = "Raster is already running"
            alert.informativeText = "Quit the other copy of Raster first, then open it again."
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        // `killall Raster` (SIGTERM), Ctrl-C (SIGINT) en het sluiten van een terminal (SIGHUP) gaan via een
        // gewone terminate, zodat macOS-tegelen toch wordt teruggezet.
        terminateSignals = [SIGTERM, SIGINT, SIGHUP].map { number in
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
            source.setEventHandler { NSApp.terminate(nil) }
            source.resume()
            return source
        }
        model.onCommandsChange = { [weak self] in self?.registerHotkeys() }
        model.onRecordingChange = { [weak self] recording in
            if recording { self?.hotkeys.unregisterAll() } else { self?.registerHotkeys() }
        }
        snappingState.isEnabled = isSnappingEnabled
        settingsWindow = SettingsWindowController(model: model, snapping: SnappingSettings(
            state: snappingState,
            set: { [weak self] value in
                guard let self else { return }
                isSnappingEnabled = value
                applySnapping()
            }
        ), settings: settings, loginItem: loginItem, onShow: { [weak self] in self?.registerHotkeys() },
           onReset: { [weak self] scope in self?.reset(scope) })
        NSApp.mainMenu = MainMenu.make(openSettings: #selector(openSettings), target: self)
        statusMenu = StatusMenu(
            windows: windows,
            lists: { [weak self] in self?.model.lists ?? .empty },
            settings: settings,
            onRequestPermission: { [weak self] in self?.needPermission() },
            onOpenSettings: { [weak self] in self?.settingsWindow?.show() }
        )
        hotkeys.onHotkey = { [weak self] shortcut in
            guard let self else { return }
            guard Permissions.accessibility else {
                needPermission()
                return
            }
            // Horizontal of Vertical, naar het scherm van het actieve venster; zonder actief venster gebeurt er niets.
            // Het commando werkt op hetzelfde venster als waarmee de lijst gekozen is (één AX-ronde).
            let focused = windows.focusedWindowAndGrid()
            let axis = CommandAxis.for(focused?.grid ?? .landscape)
            guard let command = model.lists.command(for: shortcut, axis: axis), let window = focused?.window else { return }
            windows.perform(command, on: window)
        }
        dragMonitor.lists = { [weak self] in self?.model.lists ?? .empty }
        dragMonitor.onPreviewChange = { [weak self] frame in
            if let frame { self?.snapPreview.show(frame) } else { self?.snapPreview.hide() }
        }
        dragMonitor.onZonesChange = { [weak self] rects in self?.activationOverlay.show(rects) }
        zoomMonitor.onHover = { [weak self] window, point in self?.zoomMenu.show(for: window, at: point) }
        zoomMonitor.isMenuOpen = { [weak self] in self?.zoomMenu.isPanelOpen ?? false }
        settings.onChange = { [weak self] in self?.applySettings() }
        applySettings()
        loginItem.refresh()
        Task { [weak self] in
            await RealMagnetCheck.run()
            guard let self else { return }
            showFirstRunIfNeeded()
            if Permissions.accessibility {
                start()
            } else {
                needPermission()
            }
        }
    }

    /// Opnieuw openen (Finder, Spotlight) toont het toestemmingsvenster als dat nog nodig is,
    /// anders het instellingenvenster.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if Permissions.accessibility {
            settingsWindow?.show()
        } else {
            needPermission()
        }
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        loginItem.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard !isDuplicate else { return }
        hotkeys.unregisterAll()
        dragMonitor.stop()
        zoomMonitor.stop()
        tiling.restoreSystemTiling()
    }

    /// Eén pad voor ontbrekende toestemming: sneltoetsen en slepen vrijgeven, macOS-tegels terug,
    /// waarschuwen en wachten tot het alsnog lukt.
    private func needPermission() {
        hotkeys.unregisterAll()
        dragMonitor.stop()
        zoomMonitor.stop()
        zoomMenu.close()
        isStarted = false
        tiling.restoreSystemTiling()
        snappingState.isRunning = dragMonitor.isRunning
        model.setSystemConflicts([])
        permissionWindow.show()
        watcher.waitForTrust { [weak self] in self?.start() }
    }

    private func start() {
        isStarted = true
        permissionWindow.close()
        registerHotkeys()
        applySnapping()
        applyZoomButton()
        finishFirstRunIfReady()
    }

    /// Alle onderdelen volgen de voorkeuren.
    private func applySettings() {
        windows.excludedBundleIDs = Set(settings.excludedBundleIDs)
        windows.pins.unpin(bundleIDs: Set(settings.excludedBundleIDs))
        windows.margins = WindowMargins(size: CGFloat(settings.margin), fitTightly: settings.fitTightly)
        zoomMonitor.systemMenuModifier = settings.systemMenuModifier == .command ? .command : .control
        zoomMonitor.hoverDelay = settings.zoomHoverDelay
        dragMonitor.restoresOriginalSize = settings.restoreOriginalSize
        dragMonitor.edgeWidth = CGFloat(settings.edgeWidth)
        dragMonitor.innerScale = settings.innerScale
        dragMonitor.showsZones = settings.highlightZones
        snapPreview.style = SnapPreview.Style(
            appearance: settings.previewAppearance, color: settings.previewColor, outline: settings.previewOutline)
        activationOverlay.style = ActivationOverlay.Style(
            appearance: settings.zoneAppearance, color: settings.zoneColor, outline: settings.zoneOutline)
        statusMenu?.setIconHidden(settings.hideMenuBarIcon)
        if isStarted { applyZoomButton() }
    }

    private func applyZoomButton() {
        if settings.zoomButtonMenu && Permissions.accessibility {
            if !zoomMonitor.start() { NSLog("Raster: event tap voor de groene knop kon niet worden gemaakt") }
        } else {
            zoomMonitor.stop()
            zoomMenu.close()
        }
    }

    /// Sneltoetsen (opnieuw) registreren, behalve zonder toestemming of tijdens het opnemen van een sneltoets.
    private func registerHotkeys() {
        guard Permissions.accessibility, !model.isRecording else { return }
        hotkeys.register(model.lists.activeShortcuts)
        model.setSystemConflicts(hotkeys.conflicts)
        if !hotkeys.conflicts.isEmpty {
            NSLog("Raster: sneltoetsconflict voor %@", hotkeys.conflicts.map(\.displayString).sorted().joined(separator: ", "))
        }
    }

    /// Slepen aan: event tap starten en macOS-tegels uit. Uit (of tap geweigerd): tap stoppen en tegels terug.
    private func applySnapping() {
        // Tijdens de vraag over tegelen niets doen; na het antwoord volgt `applySnapping` opnieuw.
        guard !isAskingAboutTiling else { return }
        defer {
            snappingState.isEnabled = isSnappingEnabled
            snappingState.isRunning = dragMonitor.isRunning
        }
        guard isSnappingEnabled, Permissions.accessibility else {
            dragMonitor.stop()
            tiling.restoreSystemTiling()
            return
        }
        // Eenmalig: tegelt macOS nu zelf, dan vragen wie het slepen naar de rand doet. Tijdens de vraag kan er
        // iets veranderen (voorkeur, toestemming), dus daarna opnieuw toepassen.
        if !settings.tilingPromptAnswered && tiling.isSystemTilingActive {
            // Bij de eerste start komt de vraag als laatste; tot dan blijft slepen zoals het is.
            guard !isFirstRunPending else { return }
            if !askKeepRasterSnapping() { isSnappingEnabled = false }
            applySnapping()
            return
        }
        if dragMonitor.start() {
            tiling.disableSystemTiling()
        } else {
            NSLog("Raster: event tap voor slepen kon niet worden gemaakt")
            tiling.restoreSystemTiling()
        }
    }

    /// Geeft true voor "Continue with Raster". De keuze wordt onthouden; de vraag komt niet terug.
    private func askKeepRasterSnapping() -> Bool {
        isAskingAboutTiling = true
        defer { isAskingAboutTiling = false }
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = L10n.tilingWindowTitle
        alert.informativeText = L10n.tilingWindowSubtitle
        alert.addButton(withTitle: L10n.tilingWindowPrimaryActionTitle)
        alert.addButton(withTitle: L10n.tilingWindowSecondaryActionTitle)
        let keep = alert.runModal() == .alertFirstButtonReturn
        settings.markTilingPromptAnswered()
        NSApp.yieldFocusIfIdle()
        return keep
    }

    /// Eerste start: welkomstvenster, daarna eenmalig de vraag over starten bij inloggen en als laatste die over tegelen.
    private func showFirstRunIfNeeded() {
        guard !settings.welcomeShown else { return }
        isFirstRunPending = true
        // Pas bij sluiten markeren: stopt Raster eerder, dan komen welkom en inlogvraag bij de volgende start.
        welcomeWindow.show { [weak self] in
            self?.settings.markWelcomeShown()
            self?.isWelcomeClosed = true
            self?.finishFirstRunIfReady()
        }
    }

    /// Na het welkomstvenster en met toestemming: de inlogvraag, dan (via `applySnapping`) de vraag over tegelen.
    private func finishFirstRunIfReady() {
        guard isFirstRunPending, isWelcomeClosed, isStarted else { return }
        isFirstRunPending = false
        askLoginItemIfNeeded()
        applySnapping()
    }

    private func askLoginItemIfNeeded() {
        loginItem.refresh()
        guard !settings.loginPromptShown, !loginItem.isOn else { return }
        settings.markLoginPromptShown()
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = L10n.launchAtLoginWindowTitle
        alert.informativeText = L10n.launchAtLoginWindowSubtitle
        alert.addButton(withTitle: L10n.launchAtLoginWindowPrimaryActionTitle)
        alert.addButton(withTitle: L10n.launchAtLoginWindowCancelActionTitle)
        if alert.runModal() == .alertFirstButtonReturn {
            loginItem.toggle()
            if loginItem.needsApproval { LoginItem.openSettings() }
        }
        NSApp.yieldFocusIfIdle()
    }

    /// Herstellen naar standaard. Commando's: `onCommandsChange` registreert de sneltoetsen opnieuw;
    /// voorkeuren: `onChange` past ze toe, en slepen naar rand staat weer aan.
    private func reset(_ scope: ResetScope) {
        if scope != .preferences && !model.isReadOnly { model.resetAll() }
        if scope != .commands {
            settings.resetPreferences()
            UserDefaults.standard.removeObject(forKey: Self.snapWindowsKey)
            applySnapping()
        }
    }

    @objc private func openSettings() {
        settingsWindow?.show()
    }
}

extension NSApplication {
    /// Geeft de focus terug aan de vorige app als Raster niets zichtbaars meer heeft.
    func yieldFocusIfIdle() {
        if isActive && !windows.contains(where: { $0.isVisible && $0.styleMask.contains(.titled) }) { hide(nil) }
    }
}
