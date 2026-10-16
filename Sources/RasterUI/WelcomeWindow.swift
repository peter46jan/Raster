import AppKit
import SwiftUI

/// Welkomstvenster bij de eerste start.
@MainActor
final class WelcomeWindowController {
    private var window: NSWindow?
    private var onClose: (() -> Void)?

    /// `onClose` volgt één keer, na sluiten met de sluitknop (er is geen eigen knop).
    func show(onClose: @escaping () -> Void) {
        self.onClose = onClose
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 360),
                styleMask: [.titled, .closable], backing: .buffered, defer: false
            )
            window.title = L10n.aboutWindowTextTitle
            window.isReleasedWhenClosed = false
            let hosting = NSHostingView(rootView: WelcomeView())
            window.contentView = hosting
            window.setContentSize(hosting.fittingSize)
            window.center()
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
                // Na het sluiten, zodat een vraag daarna niet midden in het sluiten verschijnt.
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        let onClose = self?.onClose
                        self?.onClose = nil
                        onClose?()
                        NSApp.yieldFocusIfIdle()
                    }
                }
            }
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}

/// Teksten van het welkomstvenster.
private struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text(L10n.welcomeTitle)
                .font(.largeTitle.bold())
            Text(L10n.welcomeSubtitle0)
            Text(L10n.welcomeSubtitle1)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(28)
        .frame(width: 440)
    }
}
