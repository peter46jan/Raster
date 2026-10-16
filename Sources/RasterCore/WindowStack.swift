import CoreGraphics

/// Eén venster uit de vensterlijst van macOS (`CGWindowListCopyWindowInfo`), in AX-coördinaten.
public struct WindowListEntry: Equatable, Sendable {
    public var bounds: CGRect
    public var layer: Int
    public var alpha: Double
    public var pid: Int32

    public init(bounds: CGRect, layer: Int, alpha: Double, pid: Int32) {
        self.bounds = bounds
        self.layer = layer
        self.alpha = alpha
        self.pid = pid
    }
}

public enum WindowStack {
    /// Frame van het bovenste gewone venster op `point`, met `windows` van voor naar achter; nil als dat venster
    /// van `ownPID` is of er geen is. Vensters boven laag 0 (menubalk, Dock, panelen) en volledig doorzichtige
    /// vensters liggen er wel boven, maar zijn geen doel: verder zoeken.
    public static func topWindowFrame(at point: CGPoint, in windows: [WindowListEntry], ownPID: Int32) -> CGRect? {
        guard let top = windows.first(where: { $0.bounds.contains(point) && $0.layer == 0 && $0.alpha > 0 }) else {
            return nil
        }
        return top.pid == ownPID ? nil : top.bounds
    }
}
