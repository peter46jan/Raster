import AppKit
import RasterCore

/// Horizontale weergave van het menu bij de groene knop: een klein paneel met iconen, een rij per deel
/// tussen twee scheidingslijnen. Sluit bij een keuze, ⎋, een klik ernaast of als de muis wegbeweegt.
@MainActor
final class HorizontalCommandPanel: NSObject {
    /// Randloos paneel dat key mag worden (voor ⎋ via de toetsmonitor) zonder Raster actief te maken.
    private final class KeyPanel: NSPanel {
        override var canBecomeKey: Bool { true }
    }

    private var panel: KeyPanel?
    var isOpen: Bool { panel?.isVisible == true }
    private var monitors: [Any] = []
    private var onChoose: ((String) -> Void)?
    /// Cursor bij het openen; telt mee bij wegbewegen, want bij een schermrand staat het paneel er soms verder vanaf.
    private var openingCursor = NSPoint.zero
    /// Zo ver mag de muis buiten het paneel komen voordat het sluit.
    private static let leaveDistance: CGFloat = 40

    /// `rows`: commando's per rij (een rij per deel tussen scheidingslijnen). `axPoint` is de cursor (AX).
    func show(rows: [[Command]], pinnedIDs: Set<String>, at axPoint: CGPoint, onChoose: @escaping (String) -> Void) {
        close()
        let rows = rows.filter { !$0.isEmpty }
        guard !rows.isEmpty, let mainHeight = NSScreen.screens.first?.frame.height else { return }
        self.onChoose = onChoose

        let stack = NSStackView(views: rows.map { row in
            let line = NSStackView(views: row.map { button(for: $0, pinnedIDs: pinnedIDs) })
            line.orientation = .horizontal
            line.spacing = 2
            return line
        })
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)

        let background = NSVisualEffectView()
        background.material = .menu
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 8
        background.layer?.masksToBounds = true
        background.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        let size = stack.fittingSize

        let panel = KeyPanel(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
                             backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        panel.contentView = background

        // Linksboven bij de cursor, 8 pt eronder, binnen het zichtbare deel van het scherm onder de cursor.
        let cursor = NSPoint(x: axPoint.x, y: mainHeight - axPoint.y)
        var origin = NSPoint(x: cursor.x, y: cursor.y - 8 - size.height)
        if let visible = (NSScreen.screens.first { $0.frame.contains(cursor) } ?? NSScreen.main)?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
            origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        }
        panel.setFrameOrigin(origin)
        self.panel = panel
        openingCursor = cursor

        if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard event.keyCode == 53 else { return event } // ⎋
            MainActor.assumeIsolated { self?.close() }
            return nil
        }) {
            monitors.append(local)
        }
        // Globaal: klikken in andere apps (klikken in het paneel zelf zijn lokaal en komen hier niet).
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }) {
            monitors.append(global)
        }
        // Wegbewegen: globaal boven andere apps, lokaal boven het paneel zelf.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.closeIfMouseLeft() }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.closeIfMouseLeft() }
            return event
        }) {
            monitors.append(local)
        }
        panel.makeKeyAndOrderFront(nil)
    }

    private func closeIfMouseLeft() {
        guard let panel else { return }
        let area = panel.frame.union(NSRect(origin: openingCursor, size: NSSize(width: 1, height: 1)))
            .insetBy(dx: -Self.leaveDistance, dy: -Self.leaveDistance)
        if !area.contains(NSEvent.mouseLocation) { close() }
    }

    func close() {
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors = []
        panel?.orderOut(nil)
        panel = nil
        onChoose = nil
    }

    private func button(for command: Command, pinnedIDs: Set<String>) -> NSButton {
        let title = command.menuTitle
        let button = NSButton(image: RasterIcons.command(command), target: self, action: #selector(choose(_:)))
        button.bezelStyle = .accessoryBarAction
        button.toolTip = title
        button.setAccessibilityLabel(title)
        button.identifier = NSUserInterfaceItemIdentifier(command.id)
        if command.action == .special(.stayOnTop) && pinnedIDs.contains(command.id) {
            button.setButtonType(.pushOnPushOff)
            button.state = .on
        }
        return button
    }

    @objc private func choose(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue, let onChoose else { return }
        close()
        onChoose(id)
    }
}
