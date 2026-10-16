import CoreGraphics

/// Onthoudt per venster de frame van vóór de eerste actie van een reeks.
/// Een volgende actie hoort bij dezelfde reeks als het venster nog (±2 pt) staat waar de
/// vorige actie het neerzette; anders is het met de hand verplaatst en begint een nieuwe reeks.
public struct RestoreMemory<Key: Equatable> {
    private struct Entry {
        var key: Key
        var saved: CGRect
        var applied: CGRect
    }

    private var entries: [Entry] = []
    public let limit: Int

    public init(limit: Int) {
        precondition(limit >= 0, "limit moet 0 of groter zijn")
        self.limit = limit
    }

    public var count: Int { entries.count }

    public mutating func record(before current: CGRect, after applied: CGRect, for key: Key) {
        var entry = Entry(key: key, saved: current, applied: applied)
        if let index = entries.firstIndex(where: { $0.key == key }) {
            let previous = entries.remove(at: index)
            if Self.isClose(previous.applied, current) { entry.saved = previous.saved }
        }
        entries.append(entry)
        if entries.count > limit { entries.removeFirst(entries.count - limit) }
    }

    /// Geeft de bewaarde frame en vergeet het venster.
    public mutating func take(_ key: Key) -> CGRect? {
        guard let index = entries.firstIndex(where: { $0.key == key }) else { return nil }
        return entries.remove(at: index).saved
    }

    /// Of er voor dit venster iets te herstellen is (menu-item Restore aan of grijs).
    public func contains(_ key: Key) -> Bool {
        entries.contains { $0.key == key }
    }

    /// De bewaarde frame zolang het venster nog staat waar Raster het neerzette (±2 pt), anders nil.
    /// Vergeet niets; gebruik daarna `take` als de frame echt wordt gebruikt.
    public func snappedFrame(for key: Key, current: CGRect) -> CGRect? {
        guard let entry = entries.first(where: { $0.key == key }), Self.isClose(entry.applied, current) else { return nil }
        return entry.saved
    }

    static func isClose(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= 2 && abs(a.minY - b.minY) <= 2
            && abs(a.width - b.width) <= 2 && abs(a.height - b.height) <= 2
    }
}
