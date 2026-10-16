import AppKit
import RasterSystem
import SwiftUI

struct PermissionView: View {
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.authorizationWindowTitle)
                .font(.headline)
            // Alleen Markdown (geen opzoeking in een stringtabel), zodat de appnaam in de tekst vet wordt.
            Text((try? AttributedString(markdown: L10n.authorizationWindowSubtitle))
                 ?? AttributedString(L10n.authorizationWindowSubtitle))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(L10n.authorizationWindowAction, action: openSettings)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}

@MainActor
final class PermissionWindowController {
    private var window: NSWindow?

    func show() {
        NSApp.unhide(nil)
        if window == nil {
            let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = L10n.aboutWindowTextTitle
            window.isReleasedWhenClosed = false
            let hosting = NSHostingView(rootView: PermissionView {
                Permissions.requestAccessibility()
                Permissions.openAccessibilitySettings()
            })
            window.contentView = hosting
            window.setContentSize(hosting.fittingSize)
            window.center()
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: window, queue: .main
            ) { _ in
                // Pas een beurt later is het venster echt niet meer zichtbaar.
                DispatchQueue.main.async { MainActor.assumeIsolated { NSApp.yieldFocusIfIdle() } }
            }
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    func close() {
        window?.close()
    }
}
