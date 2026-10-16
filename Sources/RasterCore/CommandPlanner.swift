import CoreGraphics

public enum CommandPlanner {
    /// Doelrechthoek voor `action` als het venster (`frame`) op scherm `screenIndex` hoort te komen.
    /// Nil als het commando hier niets plaatst: herstellen, altijd bovenop, schermwissel met één scherm, leeg gebied.
    /// Bij schermwissel moet `screenIndex` het scherm van het venster zelf zijn (sleepzones bevatten nooit een schermwissel).
    /// `grid` is het raster van de as van het commando (Horizontal 24 × 12, Vertical 12 × 24).
    /// `margins` gelden alleen voor commando's met een gebied.
    /// Een venster met vaste grootte houdt zijn grootte; alleen de positie volgt het doel.
    public static func target(
        for action: CommandAction, grid: GridSize, frame: CGRect, screens: [ScreenInfo], screenIndex: Int, canResize: Bool,
        margins: WindowMargins = .none
    ) -> CGRect? {
        guard screens.indices.contains(screenIndex) else { return nil }
        let visible = screens[screenIndex].visibleFrame
        var destination = visible
        var target: CGRect
        switch action {
        case .area(let area):
            // Een commando zonder gebied (nog niet af) plaatst niets.
            guard !area.segments.isEmpty else { return nil }
            target = margins.apply(to: GridModel.rect(for: area, grid: grid, in: visible), in: visible)
        case .special(.center):
            target = ScreenGeometry.centered(frame.size, in: visible)
        case .special(.nextDisplay), .special(.previousDisplay):
            guard screens.count > 1 else { return nil }
            let step = action == .special(.nextDisplay) ? 1 : -1
            destination = screens[ScreenGeometry.neighbor(of: screenIndex, in: screens, step: step)].visibleFrame
            target = ScreenGeometry.translate(frame, from: visible, to: destination)
        case .special(.restore), .special(.stayOnTop):
            return nil
        }
        if !canResize {
            target = ScreenGeometry.clamp(CGRect(origin: target.origin, size: frame.size), into: destination)
        }
        return target
    }
}
