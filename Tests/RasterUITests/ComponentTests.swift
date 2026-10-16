import AppKit
import SwiftUI
import Testing
@testable import RasterUI

/// Bouwstenen van het instellingenvenster die zonder scherm te controleren zijn.
@MainActor
struct ComponentTests {
    /// Het icoon in een knop vangt geen klikken: `hitTest` midden op het icoon geeft niet de NSImageView.
    @Test func templateImageLetsClicksThrough() {
        let button = Button(action: {}) {
            TemplateImage(image: RasterIcons.commands, color: .black)
                .frame(width: 24, height: 24)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        let host = NSHostingView(rootView: button.frame(width: 44, height: 44))
        // In een (niet getoond) venster, anders plaatst SwiftUI de NSImageView niet.
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 44, height: 44), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        let images = host.subviewsRecursively.filter { $0 is NSImageView }
        #expect(!images.isEmpty, "het icoon is een NSImageView")
        for point in [CGPoint(x: 22, y: 22), CGPoint(x: 15, y: 15), CGPoint(x: 30, y: 28)] {
            let hit = window.contentView?.superview?.hitTest(point) ?? host.hitTest(point)
            #expect(hit != nil, "\(point)")
            #expect(!(hit is NSImageView), "\(point)")
        }
    }
}

private extension NSView {
    var subviewsRecursively: [NSView] { subviews + subviews.flatMap(\.subviewsRecursively) }
}
