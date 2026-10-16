import CoreGraphics

public struct DragMatch: Equatable, Sendable {
    public var commandID: String
    public var screenIndex: Int

    public init(commandID: String, screenIndex: Int) {
        self.commandID = commandID
        self.screenIndex = screenIndex
    }
}

/// Bepaalt in welke sleepzone de cursor staat. De randbreedte en de regel voor de tweede ring
/// zijn aannames die bij handmatig testen worden gecontroleerd. `innerScale` schaalt
/// de cellen van de tweede ring rond hun midden (kleiner: alleen het midden telt, groter: ook een
/// stukje van de buurcel).
public enum DragZoneResolver {
    public static let edgeWidth: CGFloat = 6

    public static func match(
        cursor: CGPoint, screens: [ScreenInfo], lists: CommandLists,
        edgeWidth: CGFloat = edgeWidth, innerScale: CGFloat = 1
    ) -> DragMatch? {
        guard let index = screens.firstIndex(where: { $0.frame.contains(cursor) }) else { return nil }
        let frame = screens[index].frame
        let grid = GridSize.for(screens[index].visibleFrame.size)
        // Een staand scherm gebruikt alleen Vertical, een liggend alleen Horizontal.
        let commands = lists[CommandAxis.for(grid)].commands.filter(\.isComplete)
        let candidates = activeCells(
            cursor: cursor, frame: frame, grid: grid, edgeWidth: edgeWidth, innerScale: clampedScale(innerScale))
        // Eigen commando's gaan vóór de standaardzones.
        let ordered = commands.filter { $0.group == .custom } + commands.filter { $0.group != .custom }
        // De eerste kandidaat met een zone wint: de eigen cel gaat voor een buurcel die verder reikt.
        for cell in candidates {
            for command in ordered {
                let area = command.activeDragZones
                if area.segments.contains(where: { $0.contains(column: cell.column, row: cell.row) }) {
                    return DragMatch(commandID: command.id, screenIndex: index)
                }
            }
        }
        return nil
    }

    /// Waar de sleepzones van `screen` liggen (zelfde coördinaten als `frame`), om ze tijdens het slepen te tonen.
    /// Randcellen als strook van `edgeWidth` langs de rand, cellen in de tweede ring geschaald rond hun midden.
    /// Aaneengesloten stroken worden samengevoegd.
    public static func zoneRects(
        on screen: ScreenInfo, lists: CommandLists, edgeWidth: CGFloat = edgeWidth, innerScale: CGFloat = 1
    ) -> [CGRect] {
        let frame = screen.frame
        let grid = GridSize.for(screen.visibleFrame.size)
        let commands = lists[CommandAxis.for(grid)].commands.filter(\.isComplete)
        let innerScale = clampedScale(innerScale)
        var cells = Set<GridCell>()
        for command in commands {
            for segment in command.activeDragZones.segments {
                for column in segment.x..<(segment.x + segment.width) {
                    for row in segment.y..<(segment.y + segment.height) {
                        cells.insert(GridCell(column: column, row: row))
                    }
                }
            }
        }
        var rects: [CGRect] = []
        for cell in cells.sorted(by: { ($0.row, $0.column) < ($1.row, $1.column) }) {
            let bounds = cellRect(cell, frame: frame, grid: grid)
            if isOuter(cell, grid) {
                if cell.column == 0 { rects.append(CGRect(x: frame.minX, y: bounds.minY, width: edgeWidth, height: bounds.height)) }
                if cell.column == grid.columns - 1 { rects.append(CGRect(x: frame.maxX - edgeWidth, y: bounds.minY, width: edgeWidth, height: bounds.height)) }
                if cell.row == 0 { rects.append(CGRect(x: bounds.minX, y: frame.minY, width: bounds.width, height: edgeWidth)) }
                if cell.row == grid.rows - 1 { rects.append(CGRect(x: bounds.minX, y: frame.maxY - edgeWidth, width: bounds.width, height: edgeWidth)) }
            } else if isSecondRing(cell, grid) {
                rects.append(scaled(bounds, by: innerScale))
            }
        }
        return merged(rects)
    }

    /// De schaal binnen `PreferenceRange.innerScale`.
    static func clampedScale(_ scale: CGFloat) -> CGFloat {
        CGFloat(Double(scale).clamped(to: PreferenceRange.innerScale))
    }

    /// De cellen waarvoor de cursor telt, op volgorde van voorrang. Randcellen alleen binnen `edgeWidth` van hun
    /// rand; cellen in de tweede ring geschaald rond hun midden. Bij schaal groter dan 1 volgen daarna de
    /// buurcellen uit de tweede ring waarvan het geschaalde gebied de cursor bevat, de dichtstbijzijnde eerst.
    static func activeCells(cursor: CGPoint, frame: CGRect, grid: GridSize, edgeWidth: CGFloat, innerScale: CGFloat) -> [GridCell] {
        let own = GridCell(
            column: cell(cursor.x - frame.minX, length: frame.width, count: grid.columns),
            row: cell(cursor.y - frame.minY, length: frame.height, count: grid.rows)
        )
        var result: [GridCell] = []
        if isOuter(own, grid) {
            let left = own.column == 0, right = own.column == grid.columns - 1
            let top = own.row == 0, bottom = own.row == grid.rows - 1
            if (left && cursor.x - frame.minX < edgeWidth)
                || (right && frame.maxX - cursor.x <= edgeWidth)
                || (top && cursor.y - frame.minY < edgeWidth)
                || (bottom && frame.maxY - cursor.y <= edgeWidth) {
                result.append(own)
            }
        } else if isSecondRing(own, grid) {
            if innerScale >= 1 || scaled(cellRect(own, frame: frame, grid: grid), by: innerScale).contains(cursor) {
                result.append(own)
            }
        }
        guard innerScale > 1 else { return result }
        var neighbours: [GridCell] = []
        for dc in -1...1 {
            for dr in -1...1 where dc != 0 || dr != 0 {
                let candidate = GridCell(column: own.column + dc, row: own.row + dr)
                if candidate.column >= 0, candidate.column < grid.columns, candidate.row >= 0, candidate.row < grid.rows,
                   isSecondRing(candidate, grid),
                   scaled(cellRect(candidate, frame: frame, grid: grid), by: innerScale).contains(cursor) {
                    neighbours.append(candidate)
                }
            }
        }
        func distance(_ cell: GridCell) -> CGFloat {
            let rect = cellRect(cell, frame: frame, grid: grid)
            return hypot(rect.midX - cursor.x, rect.midY - cursor.y)
        }
        return result + neighbours.sorted { distance($0) < distance($1) }
    }

    static func isOuter(_ cell: GridCell, _ grid: GridSize) -> Bool {
        cell.column == 0 || cell.column == grid.columns - 1 || cell.row == 0 || cell.row == grid.rows - 1
    }

    static func isSecondRing(_ cell: GridCell, _ grid: GridSize) -> Bool {
        !isOuter(cell, grid)
            && (cell.column == 1 || cell.column == grid.columns - 2 || cell.row == 1 || cell.row == grid.rows - 2)
    }

    static func cellRect(_ cell: GridCell, frame: CGRect, grid: GridSize) -> CGRect {
        let width = frame.width / CGFloat(grid.columns), height = frame.height / CGFloat(grid.rows)
        return CGRect(x: frame.minX + CGFloat(cell.column) * width, y: frame.minY + CGFloat(cell.row) * height,
                      width: width, height: height)
    }

    static func scaled(_ rect: CGRect, by scale: CGFloat) -> CGRect {
        rect.insetBy(dx: rect.width * (1 - scale) / 2, dy: rect.height * (1 - scale) / 2)
    }

    /// Voegt rechthoeken samen die op elkaar aansluiten of overlappen met dezelfde hoogte (naast elkaar) of breedte (onder elkaar).
    static func merged(_ rects: [CGRect]) -> [CGRect] {
        var result = rects
        var changed = true
        func close(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 0.01 }
        while changed {
            changed = false
            outer: for i in result.indices {
                for j in result.indices where j > i {
                    let a = result[i], b = result[j]
                    let sideBySide = close(a.minY, b.minY) && close(a.height, b.height) && (a.minX <= b.maxX + 0.01 && b.minX <= a.maxX + 0.01)
                    let stacked = close(a.minX, b.minX) && close(a.width, b.width) && (a.minY <= b.maxY + 0.01 && b.minY <= a.maxY + 0.01)
                    if sideBySide || stacked {
                        result[i] = a.union(b)
                        result.remove(at: j)
                        changed = true
                        break outer
                    }
                }
            }
        }
        return result
    }

    static func cell(_ offset: CGFloat, length: CGFloat, count: Int) -> Int {
        guard length > 0 else { return 0 }
        return min(max(Int((offset / length * CGFloat(count)).rounded(.down)), 0), count - 1)
    }
}
