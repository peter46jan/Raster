import AppKit
import SwiftUI

/// Het venster waarin een view staat (voor bladen zoals "Incomplete Command"); wordt gezet door `HostWindowReader`.
@MainActor
final class WindowReference {
    weak var window: NSWindow?
}

/// Lege view die het venster waarin hij staat in `reference` zet, zodat een view een vraag als blad aan zijn eigen
/// venster kan hangen (niet aan `NSApp.keyWindow`, dat een ander venster kan zijn). Tekent niets en vangt geen
/// klikken.
struct HostWindowReader: NSViewRepresentable {
    let reference: WindowReference

    final class ReaderView: NSView {
        var reference: WindowReference?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            reference?.window = window
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    func makeNSView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.reference = reference
        view.setAccessibilityElement(false)
        return view
    }

    func updateNSView(_ view: ReaderView, context: Context) {
        view.reference = reference
        reference.window = view.window
    }
}
