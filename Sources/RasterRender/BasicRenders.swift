import AppKit
import SwiftUI
import RasterUI
import RasterCore

/// Rendert onderdelen van de interface naar PNG's (licht en donker, @2x), om ze naast referentie-schermafbeeldingen
/// te leggen.
@MainActor
enum BasicRenders {
    /// Staal van elke kleur: 20 pt hoog, links 60 pt vlak, rechts de naam.
    static func colors() throws {
        let swatches = VStack(spacing: 0) {
            ForEach(RasterColor.allCases, id: \.self) { color in
                HStack {
                    Rectangle().fill(color.color).frame(width: 60)
                    Text(String(describing: color)).font(.system(size: 11))
                    Spacer()
                }
                .frame(height: 20)
            }
        }
        .background(RasterColor.background.color)
        let size = CGSize(width: 260, height: CGFloat(RasterColor.allCases.count) * 20)
        for dark in [false, true] {
            try Render.view(swatches, size: size, name: "colors", dark: dark)
        }
    }

    /// Iconen: elk los op 2x (zwart op transparant, map `icons`, namen van de iconen) om met hun alfarasters te
    /// vergelijken; een blad met alles op 8× (zwart op wit); een blad zoals het menu (ingekleurd met `labelColor` op
    /// grijs 136, icoon 20 × 12 op x 15, rij 24) en zoals de lijst (accent op `listBackground`, wit op accent voor de
    /// geselecteerde eerste rij, icoon 25 × 15 op x 25, rij 30).
    static func icons() throws {
        for (name, image) in Self.namedIcons {
            try Render.image(image, name: "icons/" + name)
        }
        let sheet = IconRowsView(rowHeight: 136, iconX: 16, background: .white)
        sheet.rows = Self.namedIcons.map { .init(image: $0.image, title: $0.name, tint: nil, text: .black, zoom: 4) }
        try Render.view(sheet, name: "icons-sheet")

        for axis in CommandAxis.allCases {
            let commands = DefaultCommands.list(for: axis) + [DefaultCommands.stayOnTop(axis: axis)]
            let menu = IconRowsView(rowHeight: 24, iconX: 15, background: NSColor(white: 136 / 255, alpha: 1))
            menu.rows = commands.map {
                .init(image: RasterIcons.command($0, scale: 0.8), title: $0.name, tint: .labelColor, text: .labelColor)
            } + Self.menuSymbols.map {
                .init(image: RasterIcons.symbol($0.symbol, axis: axis, scale: 0.8), title: $0.name, tint: .labelColor,
                      text: .labelColor)
            }
            try Render.view(menu, name: "icons-menu-\(axis.rawValue)")

            let list = IconRowsView(rowHeight: 30, iconX: 25, background: RasterColor.listBackground.nsColor)
            list.rows = commands.enumerated().map { index, command in
                let selected = index == 0
                return .init(image: RasterIcons.command(command), title: command.name,
                             tint: selected ? .white : RasterColor.accentNSColor, text: selected ? .white : .labelColor,
                             selection: selected ? RasterColor.accentNSColor : nil)
            }
            try Render.view(list, name: "icons-list-\(axis.rawValue)")
        }
    }

    /// Het menubalkmenu zoals het referentiemenu (`referentie-menu.png`: Terminal voorop, niets te herstellen): als tekst in `menu.txt`
    /// (zie `StatusMenu.outline`) en als iconenkolom zoals het menu (icoon 20 × 12 op x 15, ritme 24, scheidingslijn
    /// 13 pt zoals gemeten in `referentie-menu.png`), licht en donker.
    static func menu() throws {
        let directory = Render.directory
        let app = StatusMenu.TargetApp(name: "Terminal", bundleID: "com.apple.Terminal", isExcluded: false)
        for axis in CommandAxis.allCases {
            let entries = StatusMenu.entries(lists: .standard, axis: axis, trusted: true, canRestore: false,
                                             isPinned: false, app: app, ownBundleID: nil)
            let suffix = axis == .horizontal ? "" : "-vertical"
            let text = StatusMenu.outline(entries).joined(separator: "\n") + "\n"
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            try text.write(toFile: directory + "/menu\(suffix).txt", atomically: true, encoding: .utf8)

            let menu = IconRowsView(rowHeight: 24, iconX: 15, background: NSColor(white: 136 / 255, alpha: 1))
            menu.rows = entries.map { entry in
                guard case .item(let item) = entry else { return .separator(height: 13) }
                let image: NSImage? = switch item.icon {
                case .command(let command): RasterIcons.command(command, scale: 0.8)
                case .symbol(let symbol): RasterIcons.symbol(symbol, axis: axis, scale: 0.8)
                case nil: nil
                }
                let color: NSColor = item.isEnabled ? .labelColor : .tertiaryLabelColor
                var title = item.title
                if let shortcut = item.shortcut { title += "    " + shortcut.displayString }
                return .init(image: image, title: title, tint: color, text: color)
            }
            for dark in [false, true] {
                try Render.view(menu, name: "menu" + suffix, dark: dark)
            }
        }
    }

    private static let menuSymbols: [(symbol: RasterIcons.Symbol, name: String)] =
        [(.settings, "Settings…"), (.ignore, "Ignore"), (.help, "Help"), (.about, "About…"), (.quit, "Quit")]

    /// Alle iconen met hun naam.
    private static var namedIcons: [(name: String, image: NSImage)] {
        var icons: [(String, NSImage)] = []
        let specials: [(String, SpecialAction)] = [("next-display", .nextDisplay), ("previous-display", .previousDisplay),
                                                   ("center", .center), ("restore", .restore), ("stay-on-top", .stayOnTop)]
        let symbols: [(String, RasterIcons.Symbol)] = [("settings", .settings), ("ignore", .ignore), ("help", .help),
                                                       ("about", .about), ("quit", .quit)]
        for axis in CommandAxis.allCases {
            for (name, special) in specials { icons.append(("\(name)-\(axis.rawValue)", RasterIcons.glyph(special, axis: axis))) }
            for (name, symbol) in symbols { icons.append(("\(name)-\(axis.rawValue)", RasterIcons.symbol(symbol, axis: axis))) }
        }
        icons += [("status-bar", RasterIcons.statusBar), ("preferences", RasterIcons.preferences),
                  ("commands", RasterIcons.commands), ("add", RasterIcons.add), ("chevron", RasterIcons.chevron),
                  ("remove", RasterIcons.remove), ("remove-area", RasterIcons.removeArea),
                  ("green-menu", RasterIcons.greenMenu), ("green-menu-crossed", RasterIcons.greenMenuCrossed),
                  ("menu-bar", RasterIcons.menuBar), ("menu-bar-crossed", RasterIcons.menuBarCrossed)]
        return icons
    }
}

/// Rijen met een (ingekleurd) sjabloonicoon en een titel, rechtstreeks met AppKit getekend: SwiftUI rastert een NSImage
/// met tekenfunctie offscreen op 1x en schaalt hem dan wazig op.
@MainActor
private final class IconRowsView: NSView {
    struct Row {
        /// nil: alleen de titel (of niets, bij een scheidingslijn).
        var image: NSImage?
        var title: String
        /// nil: het icoon zoals het is (zwart met alfa).
        var tint: NSColor?
        var text: NSColor
        var selection: NSColor? = nil
        var zoom: CGFloat = 1
        /// Scheidingslijn met eigen hoogte in plaats van een rij.
        var separatorHeight: CGFloat?

        static func separator(height: CGFloat) -> Row {
            Row(image: nil, title: "", tint: nil, text: .clear, separatorHeight: height)
        }
    }

    let rowHeight: CGFloat, iconX: CGFloat, background: NSColor
    var rows: [Row] = [] {
        didSet {
            let width = rows.map { ($0.image?.size.width ?? 0) * $0.zoom }.max() ?? 0
            let height = rows.reduce(0) { $0 + ($1.separatorHeight ?? rowHeight) }
            frame = CGRect(x: 0, y: 0, width: iconX + width + 220, height: height)
        }
    }

    init(rowHeight: CGFloat, iconX: CGFloat, background: NSColor) {
        self.rowHeight = rowHeight
        self.iconX = iconX
        self.background = background
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("niet gebruikt") }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        background.setFill()
        bounds.fill()
        var top: CGFloat = 0
        for row in rows {
            defer { top += row.separatorHeight ?? rowHeight }
            if let height = row.separatorHeight {
                NSColor.separatorColor.setFill()
                CGRect(x: 14, y: top + (height / 2).rounded(.down), width: bounds.width - 28, height: 1).fill()
                continue
            }
            if let selection = row.selection {
                selection.setFill()
                NSBezierPath(roundedRect: CGRect(x: 15, y: top + 1, width: bounds.width - 30, height: rowHeight - 2),
                             xRadius: 5, yRadius: 5).fill()
            }
            guard let image = row.image else {
                (row.title as NSString).draw(at: CGPoint(x: iconX + 30, y: top + (rowHeight - 16) / 2),
                                             withAttributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: row.text])
                continue
            }
            let size = CGSize(width: image.size.width * row.zoom, height: image.size.height * row.zoom)
            let rect = CGRect(x: iconX, y: top + ((rowHeight - size.height) / 2).rounded(), width: size.width,
                              height: size.height)
            if row.zoom > 1 {
                NSColor(white: 0.9, alpha: 1).setFill()
                rect.fill()
            }
            let context = NSGraphicsContext.current?.cgContext
            context?.beginTransparencyLayer(auxiliaryInfo: nil)
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            if let tint = row.tint {
                tint.setFill()
                rect.fill(using: .sourceIn)
            }
            context?.endTransparencyLayer()
            (row.title as NSString).draw(at: CGPoint(x: iconX + size.width + 10, y: top + (rowHeight - 16) / 2),
                                         withAttributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: row.text])
        }
    }
}
