import CoreGraphics

/// Een rechthoek in rastercellen: kolom `x`, rij `y`, breedte en hoogte in cellen.
public struct GridRect: Codable, Hashable, Sendable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public init(_ x: Int, _ y: Int, _ width: Int, _ height: Int) {
        self.init(x: x, y: y, width: width, height: height)
    }
}

/// Een gebied op het raster, opgebouwd uit één of meer segmenten.
public struct GridArea: Codable, Hashable, Sendable {
    public var segments: [GridRect]

    public init(segments: [GridRect]) {
        self.segments = segments
    }

    public init(_ segments: GridRect...) {
        self.init(segments: segments)
    }
}

/// Liggende schermen gebruiken 24 × 12 cellen, staande 12 × 24.
public struct GridSize: Hashable, Sendable {
    public var columns: Int
    public var rows: Int

    public init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
    }

    public static let landscape = GridSize(columns: 24, rows: 12)
    public static let portrait = GridSize(columns: 12, rows: 24)

    public static func `for`(_ size: CGSize) -> GridSize {
        size.height > size.width ? .portrait : .landscape
    }
}

public enum GridModel {
    /// Rekent een gebied om naar een rechthoek binnen `frame` (AX-coördinaten, y omlaag).
    /// Bij meerdere segmenten geldt de omsluitende rechthoek. Celranden worden afgerond
    /// op hele punten; de laatste rand valt altijd precies op de rand van `frame`.
    public static func rect(for area: GridArea, grid: GridSize, in frame: CGRect) -> CGRect {
        guard let first = area.segments.first else { return frame }
        var minX = first.x, minY = first.y
        var maxX = first.x + first.width, maxY = first.y + first.height
        for segment in area.segments.dropFirst() {
            minX = min(minX, segment.x)
            minY = min(minY, segment.y)
            maxX = max(maxX, segment.x + segment.width)
            maxY = max(maxY, segment.y + segment.height)
        }
        let left = edge(minX, of: grid.columns, from: frame.minX, length: frame.width)
        let right = edge(maxX, of: grid.columns, from: frame.minX, length: frame.width)
        let top = edge(minY, of: grid.rows, from: frame.minY, length: frame.height)
        let bottom = edge(maxY, of: grid.rows, from: frame.minY, length: frame.height)
        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }

    private static func edge(_ index: Int, of count: Int, from start: CGFloat, length: CGFloat) -> CGFloat {
        if index <= 0 { return start }
        if index >= count { return start + length }
        return (start + length * CGFloat(index) / CGFloat(count)).rounded()
    }
}

extension GridRect {
    public func contains(column: Int, row: Int) -> Bool {
        column >= x && column < x + width && row >= y && row < y + height
    }
}

public struct GridCell: Hashable, Sendable {
    public var column: Int
    public var row: Int

    public init(column: Int, row: Int) {
        self.column = column
        self.row = row
    }
}

public enum GridSelection {
    /// De rechthoek tussen twee cellen, beide inbegrepen, in welke richting er ook gesleept is.
    public static func rect(from start: GridCell, to end: GridCell) -> GridRect {
        let left = min(start.column, end.column), top = min(start.row, end.row)
        return GridRect(left, top, abs(start.column - end.column) + 1, abs(start.row - end.row) + 1)
    }
}
