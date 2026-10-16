import AppKit
import RasterCore

/// Alle iconen van Raster, getekend als sjabloon (zwart met alfa), zodat menu's en lijsten ze inkleuren.
/// Achtergronden hebben alfa 0,25 en gebieden of symbolen alfa 1: met template-rendering ontstaan zo vanzelf een
/// lichte en een volle tint. Een commando-icoon is een scherm met een rand van 1,5 pt waarbinnen het gebied als
/// afgerond vlak ligt. Menu- en zijbalkiconen zijn SF Symbols; maten in pt van het icoon op schaal 1.
@MainActor
package enum RasterIcons {
    /// Menu-iconen zonder achtergrond.
    package enum Symbol: Hashable, Sendable { case settings, ignore, help, about, quit }

    /// Icoon van een commando: 25 × 15 (Vertical 15 × 25) bij `scale` 1; in menu's `scale` 0,8 (20 × 12).
    /// Een commando met een leeg gebied (nog niet af) geeft alleen de achtergrond.
    package static func command(_ command: Command, scale: CGFloat = 1) -> NSImage {
        let content: IconShape.Content
        switch command.action {
        case .area(let area): content = .area(AreaBounds(area))
        case .special(let special): content = .special(special)
        }
        return image(.command(command.axis, content), scale: scale)
    }

    /// Menu-iconen zonder achtergrond (SF Symbols), 25 × 15 × scale; voor de lijst Vertical 15 × 25.
    package static func symbol(_ symbol: Symbol, axis: CommandAxis = .horizontal, scale: CGFloat = 1) -> NSImage {
        image(.symbol(symbol, axis), scale: scale)
    }

    /// Alleen de vorm van een speciaal commando, zonder achtergrond. Alleen voor `raster-render`, om de vormen los te
    /// bekijken; de app gebruikt `command(_:scale:)`.
    package static func glyph(_ special: SpecialAction, axis: CommandAxis, scale: CGFloat = 1) -> NSImage {
        image(.glyph(special, axis), scale: scale)
    }

    /// Menubalkicoon 22 × 22.
    package static var statusBar: NSImage { image(.statusBar) }
    /// Zijbalk 24 × 24.
    package static var preferences: NSImage { image(.preferences) }
    package static var commands: NSImage { image(.commands) }
    /// Ronde knoppen 20 × 20 (cirkel 16 pt, symbool uitgespaard).
    package static var add: NSImage { image(.add) }
    package static var chevron: NSImage { image(.chevron) }
    package static var remove: NSImage { image(.remove) }
    /// 16 × 16, kruisje.
    package static var removeArea: NSImage { image(.removeArea) }
    /// 20 × 20, rijknoppen "visible in green button menu" / "visible in menu bar" en hun doorgestreepte varianten.
    package static var greenMenu: NSImage { image(.greenMenu) }
    package static var greenMenuCrossed: NSImage { image(.greenMenuCrossed) }
    package static var menuBar: NSImage { image(.menuBar) }
    package static var menuBarCrossed: NSImage { image(.menuBarCrossed) }

    private struct Key: Hashable {
        var shape: IconShape
        var scale: CGFloat
    }

    private static var cache: [Key: NSImage] = [:]

    /// Eén sjabloonafbeelding per vorm en schaal, bewaard voor hergebruik (menu's worden vaak opnieuw gebouwd).
    private static func image(_ shape: IconShape, scale: CGFloat = 1) -> NSImage {
        let key = Key(shape: shape, scale: scale)
        if let cached = cache[key] { return cached }
        let base = shape.size
        let image = NSImage(size: CGSize(width: base.width * scale, height: base.height * scale), flipped: true) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.saveGState()
            // De vormen zijn in pt van schaal 1 beschreven; zo tekent het icoon ook scherp op elke andere maat.
            context.translateBy(x: rect.minX, y: rect.minY)
            context.scaleBy(x: rect.width / base.width, y: rect.height / base.height)
            shape.draw(in: context)
            context.restoreGState()
            return true
        }
        image.isTemplate = true
        cache[key] = image
        return image
    }
}

/// Omsluitende rechthoek van de segmenten van een gebied, in rastercellen. Zonder segmenten is hij leeg (`isEmpty`).
fileprivate struct AreaBounds: Hashable, Sendable {
    var minX = 0, minY = 0, maxX = 0, maxY = 0

    init(_ area: GridArea) {
        guard let first = area.segments.first else { return }
        minX = first.x; minY = first.y; maxX = first.x + first.width; maxY = first.y + first.height
        for segment in area.segments.dropFirst() {
            minX = min(minX, segment.x); minY = min(minY, segment.y)
            maxX = max(maxX, segment.x + segment.width); maxY = max(maxY, segment.y + segment.height)
        }
    }

    var isEmpty: Bool { maxX <= minX || maxY <= minY }

    /// Deel van `frame` naar verhouding van de rastercellen.
    func rect(in frame: CGRect, grid: GridSize) -> CGRect {
        let column = frame.width / CGFloat(grid.columns), row = frame.height / CGFloat(grid.rows)
        return CGRect(x: frame.minX + CGFloat(minX) * column, y: frame.minY + CGFloat(minY) * row,
                      width: CGFloat(maxX - minX) * column, height: CGFloat(maxY - minY) * row)
    }
}

/// Elke vorm die `RasterIcons` tekent. Alleen Sendable waarden, zodat de tekenfunctie van NSImage ze mag meenemen.
fileprivate enum IconShape: Hashable, Sendable {
    enum Content: Hashable, Sendable {
        case area(AreaBounds)
        case special(SpecialAction)
    }

    case command(CommandAxis, Content)
    case glyph(SpecialAction, CommandAxis)
    case symbol(RasterIcons.Symbol, CommandAxis)
    case statusBar, preferences, commands, add, chevron, remove, removeArea
    case greenMenu, greenMenuCrossed, menuBar, menuBarCrossed

    /// Maat in pt bij schaal 1.
    var size: CGSize {
        switch self {
        case .command(let axis, _), .glyph(_, let axis), .symbol(_, let axis): Self.canvas(axis)
        case .statusBar: CGSize(width: 22, height: 22)
        case .preferences, .commands: CGSize(width: 24, height: 24)
        case .add, .chevron, .remove, .greenMenu, .greenMenuCrossed, .menuBar, .menuBarCrossed: CGSize(width: 20, height: 20)
        case .removeArea: CGSize(width: 16, height: 16)
        }
    }

    /// Maat van een commando-icoon of menusymbool: 25 × 15, Vertical 15 × 25.
    static func canvas(_ axis: CommandAxis) -> CGSize {
        axis == .vertical ? CGSize(width: 15, height: 25) : CGSize(width: 25, height: 15)
    }

    /// Tekent in een geflipte context (y omlaag) met de maat van `size`.
    func draw(in c: CGContext) {
        switch self {
        case .command(let axis, let content):
            let size = Self.canvas(axis)
            let background = Glyphs.background(size)
            c.setFillColor(Glyphs.backgroundColor)
            c.addPath(background)
            c.fillPath()
            switch content {
            case .area(let bounds):
                guard !bounds.isEmpty else { return }
                // Het gebied ligt binnen een rand van achtergrond, als afgerond vlak.
                let frame = CGRect(origin: .zero, size: size).insetBy(dx: Style.inset, dy: Style.inset)
                let rect = bounds.rect(in: frame, grid: axis.grid)
                let radius = min(Style.areaRadius, rect.width / 2, rect.height / 2)
                c.setFillColor(Glyphs.black)
                Glyphs.fill(c, CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
            case .special(let special):
                Glyphs.layer(c) { Glyphs.special(special, axis: axis, in: c) }
            }
        case .glyph(let special, let axis):
            Glyphs.layer(c) { Glyphs.special(special, axis: axis, in: c) }
        case .symbol(let symbol, let axis):
            Glyphs.layer(c) { Glyphs.symbol(symbol, axis: axis, in: c) }
        case .statusBar: Glyphs.layer(c) { Glyphs.statusBar(c) }
        case .preferences: Glyphs.layer(c) { Glyphs.preferences(c) }
        case .commands: Glyphs.layer(c) { Glyphs.commandsIcon(c) }
        case .add: Glyphs.layer(c) { Glyphs.add(c) }
        case .chevron: Glyphs.layer(c) { Glyphs.chevron(c) }
        case .remove: Glyphs.layer(c) { Glyphs.remove(c) }
        case .removeArea: Glyphs.layer(c) { Glyphs.removeArea(c) }
        case .greenMenu: Glyphs.layer(c) { Glyphs.greenMenu(c, crossed: false) }
        case .greenMenuCrossed: Glyphs.layer(c) { Glyphs.greenMenu(c, crossed: true) }
        case .menuBar: Glyphs.layer(c) { Glyphs.menuBar(c, crossed: false) }
        case .menuBarCrossed: Glyphs.layer(c) { Glyphs.menuBar(c, crossed: true) }
        }
    }
}

/// Vormmaten van de commando-iconen.
private enum Style {
    /// Hoekradius van de achtergrond.
    static let backgroundRadius: CGFloat = 3.5
    /// Rand tussen de buitenkant van het icoon en het gebied.
    static let inset: CGFloat = 1.5
    /// Hoekradius van het gebied.
    static let areaRadius: CGFloat = 1.75
}

/// De tekeningen zelf. Uitsparingen worden met de blend-modus `clear` uit de vorm gehaald, binnen een eigen laag,
/// zodat de achtergrond van een commando-icoon erdoorheen blijft schijnen.
private enum Glyphs {
    static let black = CGColor(gray: 0, alpha: 1)
    static let backgroundColor = CGColor(gray: 0, alpha: 0.25)

    static func layer(_ c: CGContext, _ draw: () -> Void) {
        c.saveGState()
        c.beginTransparencyLayer(auxiliaryInfo: nil)
        c.setFillColor(black)
        c.setStrokeColor(black)
        draw()
        c.endTransparencyLayer()
        c.restoreGState()
    }

    /// Afgeronde rechthoek over het hele icoon.
    static func background(_ size: CGSize) -> CGPath {
        CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: Style.backgroundRadius,
               cornerHeight: Style.backgroundRadius, transform: nil)
    }

    // MARK: Hulpjes

    static func fill(_ c: CGContext, _ path: CGPath) {
        c.addPath(path)
        c.fillPath()
    }

    /// Haalt `path` uit wat er al getekend is.
    static func cut(_ c: CGContext, _ draw: () -> Void) {
        c.saveGState()
        c.setBlendMode(.clear)
        draw()
        c.restoreGState()
    }

    static func stroke(_ c: CGContext, _ points: [CGPoint], width: CGFloat) {
        c.setLineWidth(width)
        c.setLineCap(.round)
        c.setLineJoin(.round)
        c.addLines(between: points)
        c.strokePath()
    }

    static func circle(_ center: CGPoint, _ radius: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2),
               transform: nil)
    }

    static func capsule(_ rect: CGRect) -> CGPath {
        let radius = min(rect.width, rect.height) / 2
        return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    /// Kruis van twee lijnen onder 45°; `arm` is de afstand van het midden tot het midden van een rond uiteinde.
    static func cross(_ c: CGContext, center p: CGPoint, arm a: CGFloat, width: CGFloat) {
        stroke(c, [CGPoint(x: p.x - a, y: p.y - a), CGPoint(x: p.x + a, y: p.y + a)], width: width)
        stroke(c, [CGPoint(x: p.x + a, y: p.y - a), CGPoint(x: p.x - a, y: p.y + a)], width: width)
    }

    static func plus(_ c: CGContext, center p: CGPoint, arm a: CGFloat, width: CGFloat) {
        stroke(c, [CGPoint(x: p.x - a, y: p.y), CGPoint(x: p.x + a, y: p.y)], width: width)
        stroke(c, [CGPoint(x: p.x, y: p.y - a), CGPoint(x: p.x, y: p.y + a)], width: width)
    }

    /// Spiegelt horizontaal binnen een breedte (vorige beeldscherm = volgende gespiegeld).
    static func mirrored(_ c: CGContext, width: CGFloat, _ draw: () -> Void) {
        c.saveGState()
        c.translateBy(x: width, y: 0)
        c.scaleBy(x: -1, y: 1)
        draw()
        c.restoreGState()
    }

    // MARK: Speciale commando's

    static func special(_ special: SpecialAction, axis: CommandAxis, in c: CGContext) {
        let canvas = IconShape.canvas(axis)
        switch special {
        case .nextDisplay:
            nextDisplay(c, axis: axis)
        case .previousDisplay:
            mirrored(c, width: canvas.width) { nextDisplay(c, axis: axis) }
        case .center:
            // Een vlak in het midden, in dezelfde stijl als de gebieden.
            let size = axis == .vertical ? CGSize(width: 7, height: 11) : CGSize(width: 11, height: 7)
            let rect = CGRect(x: (canvas.width - size.width) / 2, y: (canvas.height - size.height) / 2,
                              width: size.width, height: size.height)
            fill(c, CGPath(roundedRect: rect, cornerWidth: Style.areaRadius, cornerHeight: Style.areaRadius,
                           transform: nil))
        case .restore:
            symbolImage(c, "arrow.uturn.backward", center: CGPoint(x: canvas.width / 2, y: canvas.height / 2),
                        pointSize: 10.5, weight: .bold)
        case .stayOnTop:
            symbolImage(c, "pin.fill", center: CGPoint(x: canvas.width / 2, y: canvas.height / 2),
                        pointSize: 9.5, weight: .semibold)
        }
    }

    /// Pijl naar rechts tegen een streep: naar het volgende beeldscherm.
    static func nextDisplay(_ c: CGContext, axis: CommandAxis) {
        let mid = IconShape.canvas(axis).height / 2
        let vertical = axis == .vertical
        let (tail, tip, head, bar): (CGFloat, CGFloat, CGFloat, CGFloat) = vertical ? (2.5, 8.5, 3, 12) : (5, 16, 4, 20)
        stroke(c, [CGPoint(x: tail, y: mid), CGPoint(x: tip, y: mid)], width: 2)
        stroke(c, [CGPoint(x: tip - head, y: mid - head), CGPoint(x: tip, y: mid), CGPoint(x: tip - head, y: mid + head)],
               width: 2)
        stroke(c, [CGPoint(x: bar, y: mid - head - 0.5), CGPoint(x: bar, y: mid + head + 0.5)], width: 2)
    }

    // MARK: Menu-symbolen

    /// SF Symbols van 14 pt in het midden van het icoon.
    static func symbol(_ symbol: RasterIcons.Symbol, axis: CommandAxis, in c: CGContext) {
        let canvas = IconShape.canvas(axis)
        let name = switch symbol {
        case .settings: "gearshape"
        case .ignore: "eye.slash"
        case .help: "questionmark.circle"
        case .about: "info.circle"
        case .quit: "power"
        }
        symbolImage(c, name, center: CGPoint(x: canvas.width / 2, y: canvas.height / 2), pointSize: 14,
                    weight: .medium)
    }

    /// Tekent een SF Symbol (zwart) gecentreerd rond `center`. Bij `pointSize` p is het symbool "circle" p pt hoog.
    static func symbolImage(_ c: CGContext, _ name: String, center: CGPoint, pointSize: CGFloat, weight: NSFont.Weight) {
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil),
              let image = base.withSymbolConfiguration(.init(pointSize: pointSize, weight: weight)) else { return }
        let size = image.size
        let rect = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width,
                          height: size.height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: c, flipped: true)
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        NSGraphicsContext.restoreGraphicsState()
    }

    // MARK: Overige iconen

    /// Menubalk: afgerond scherm met een 2 × 2-raster, het vak linksboven gevuld.
    static func statusBar(_ c: CGContext) {
        let frame = CGRect(x: 2.5, y: 3.5, width: 17, height: 15)
        let outline = CGPath(roundedRect: frame, cornerWidth: 3.5, cornerHeight: 3.5, transform: nil)
        c.saveGState()
        c.addPath(outline)
        c.clip()
        c.fill(CGRect(x: frame.minX, y: frame.minY, width: frame.width / 2, height: frame.height / 2))
        c.restoreGState()
        c.setLineWidth(1.5)
        c.addPath(outline)
        c.move(to: CGPoint(x: frame.midX, y: frame.minY)); c.addLine(to: CGPoint(x: frame.midX, y: frame.maxY))
        c.move(to: CGPoint(x: frame.minX, y: frame.midY)); c.addLine(to: CGPoint(x: frame.maxX, y: frame.midY))
        c.strokePath()
    }

    /// Zijbalk: schuifregelaars.
    static func preferences(_ c: CGContext) {
        symbolImage(c, "slider.horizontal.3", center: CGPoint(x: 12, y: 12), pointSize: 20, weight: .medium)
    }

    /// Zijbalk: raster van vier vakken.
    static func commandsIcon(_ c: CGContext) {
        symbolImage(c, "square.grid.2x2", center: CGPoint(x: 12, y: 12), pointSize: 20, weight: .medium)
    }

    /// Kruisje om een gebied te verwijderen (16 × 16).
    static func removeArea(_ c: CGContext) {
        cross(c, center: CGPoint(x: 8, y: 8), arm: 2.75, width: 2)
    }

    static func add(_ c: CGContext) {
        let mid = CGPoint(x: 10, y: 10)
        fill(c, circle(mid, 8))
        cut(c) { plus(c, center: mid, arm: 3.9, width: 2) }
    }

    static func chevron(_ c: CGContext) {
        fill(c, circle(CGPoint(x: 10, y: 10), 8))
        cut(c) {
            stroke(c, [CGPoint(x: 8.5, y: 6.25), CGPoint(x: 12.25, y: 10), CGPoint(x: 8.5, y: 13.75)], width: 2)
        }
    }

    static func remove(_ c: CGContext) {
        let mid = CGPoint(x: 10, y: 10.5)
        fill(c, circle(mid, 8))
        cut(c) { cross(c, center: mid, arm: 2.75, width: 2) }
    }

    static let rowButton = CGRect(x: 2.5, y: 2.5, width: 16, height: 16)

    static func rowButtonPath() -> CGPath {
        CGPath(roundedRect: rowButton, cornerWidth: 5.25, cornerHeight: 5.25, transform: nil)
    }

    /// Afgerond vierkant met een uitgespaarde stip linksboven (het groene-knopmenu).
    static func greenMenu(_ c: CGContext, crossed: Bool) {
        fill(c, rowButtonPath())
        cut(c) { fill(c, circle(CGPoint(x: 8.5, y: 8.5), 2.45)) }
        if crossed { strikeThrough(c) }
    }

    /// Afgerond vierkant met drie uitgespaarde balken (het menubalkmenu).
    static func menuBar(_ c: CGContext, crossed: Bool) {
        fill(c, rowButtonPath())
        cut(c) {
            for y: CGFloat in [7.5, 10.5, 13.5] {
                fill(c, capsule(CGRect(x: 6.55, y: y - 1, width: 7.9, height: 2)))
            }
        }
        if crossed { strikeThrough(c) }
    }

    /// Diagonale streep van linksonder naar rechtsboven, met rechtsonder een uitgespaarde rand van 2 pt.
    static func strikeThrough(_ c: CGContext) {
        let start = CGPoint(x: 1.95, y: 17.75), end = CGPoint(x: 17.6, y: 2.1)
        // De rand ligt rechtsonder de streep: van de middellijn tot 3 pt ernaast (halve streep + rand). De uitsparing
        // is daarom 3 pt breed en ligt 1,5 pt loodrecht naar rechtsonder verschoven (per as 1,5 / √2).
        let cutWidth: CGFloat = 3
        let offsetPerAxis = cutWidth / 2 / CGFloat(2).squareRoot()
        cut(c) {
            c.setLineCap(.butt)
            c.setLineWidth(cutWidth)
            // De uitsparing loopt 2 pt voorbij beide uiteinden door, zodat hij de rand van het vierkant helemaal opent.
            c.addLines(between: [CGPoint(x: start.x - 2 + offsetPerAxis, y: start.y + 2 + offsetPerAxis),
                                 CGPoint(x: end.x + 2 + offsetPerAxis, y: end.y - 2 + offsetPerAxis)])
            c.strokePath()
        }
        stroke(c, [start, end], width: 2)
    }
}
