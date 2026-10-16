import AppKit
import RasterCore

@MainActor
public enum Screens {
    /// Alle schermen in AX-coördinaten. Wordt per actie opnieuw gelezen; er is geen cache.
    public static func current() -> [ScreenInfo] {
        let screens = NSScreen.screens
        guard let mainHeight = screens.first?.frame.height else { return [] }
        return screens.map {
            ScreenInfo(
                frame: ScreenGeometry.flip($0.frame, mainScreenHeight: mainHeight),
                visibleFrame: ScreenGeometry.flip($0.visibleFrame, mainScreenHeight: mainHeight)
            )
        }
    }
}
