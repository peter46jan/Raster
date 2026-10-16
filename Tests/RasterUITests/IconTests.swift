import AppKit
import Testing
@testable import RasterUI
import RasterCore

/// Eigenschappen van de iconen die altijd moeten gelden: maten, sjabloon, alfa van achtergrond en gebied.
/// Draait bij elke `swift test` (geen `RASTER_RENDER` nodig).
@MainActor
struct IconTests {
    private static let left = DefaultCommands.horizontal.first { $0.id == "left" }!
    private static let verticalLeft = DefaultCommands.vertical.first { $0.id == "vertical.left" }!

    @Test func commandIconsAreTemplates() {
        for command in DefaultCommands.horizontal + DefaultCommands.vertical {
            #expect(RasterIcons.command(command).isTemplate, "\(command.id)")
        }
    }

    @Test func commandIconSizes() {
        #expect(RasterIcons.command(Self.left).size == CGSize(width: 25, height: 15))
        #expect(RasterIcons.command(Self.left, scale: 0.8).size == CGSize(width: 20, height: 12))
        #expect(RasterIcons.command(Self.verticalLeft).size == CGSize(width: 15, height: 25))
        #expect(RasterIcons.command(Self.verticalLeft, scale: 0.8).size == CGSize(width: 12, height: 20))
        #expect(RasterIcons.symbol(.quit, scale: 0.8).size == CGSize(width: 20, height: 12))
        #expect(RasterIcons.symbol(.quit, axis: .vertical).size == CGSize(width: 15, height: 25))
    }

    /// Left op 2x: het gebied (dekkend) ligt binnen een rand van 1,5 pt achtergrond (alfa 0,25) en loopt tot de helft
    /// van de binnenruimte (1,5 + 11 = 12,5 pt); de rest is achtergrond.
    @Test func leftHasBackgroundAndOpaqueArea() throws {
        let alpha = try Self.alpha(RasterIcons.command(Self.left))
        #expect(alpha.width == 50 && alpha.height == 30)
        #expect(abs(alpha[12, 15] - 1) < 0.02)
        #expect(abs(alpha[37, 15] - 0.25) < 0.02)
        // Rand links van het gebied.
        #expect(abs(alpha[1, 15] - 0.25) < 0.02)
        // De grens van het gebied ligt op 12,5 pt (pixel 25 op 2x).
        #expect(abs(alpha[24, 15] - 1) < 0.02)
        #expect(abs(alpha[26, 15] - 0.25) < 0.02)
    }

    @Test func emptyAreaGivesOnlyBackground() throws {
        var command = Self.left
        command.setArea(GridArea(segments: []))
        let alpha = try Self.alpha(RasterIcons.command(command))
        #expect(abs(alpha[12, 15] - 0.25) < 0.02)
        #expect(abs(alpha[37, 15] - 0.25) < 0.02)
    }

    /// Elk icoon uit de API heeft de verwachte maat, is een sjabloon en is niet leeg.
    @Test func everyIconHasItsSizeAndIsNotEmpty() throws {
        var icons: [(String, NSImage, CGSize)] = [
            ("statusBar", RasterIcons.statusBar, CGSize(width: 22, height: 22)),
            ("preferences", RasterIcons.preferences, CGSize(width: 24, height: 24)),
            ("commands", RasterIcons.commands, CGSize(width: 24, height: 24)),
            ("add", RasterIcons.add, CGSize(width: 20, height: 20)),
            ("chevron", RasterIcons.chevron, CGSize(width: 20, height: 20)),
            ("remove", RasterIcons.remove, CGSize(width: 20, height: 20)),
            ("removeArea", RasterIcons.removeArea, CGSize(width: 16, height: 16)),
            ("greenMenu", RasterIcons.greenMenu, CGSize(width: 20, height: 20)),
            ("greenMenuCrossed", RasterIcons.greenMenuCrossed, CGSize(width: 20, height: 20)),
            ("menuBar", RasterIcons.menuBar, CGSize(width: 20, height: 20)),
            ("menuBarCrossed", RasterIcons.menuBarCrossed, CGSize(width: 20, height: 20)),
        ]
        let symbols: [RasterIcons.Symbol] = [.settings, .ignore, .help, .about, .quit]
        for axis in CommandAxis.allCases {
            let size = axis == .vertical ? CGSize(width: 15, height: 25) : CGSize(width: 25, height: 15)
            for symbol in symbols {
                icons.append(("\(symbol)-\(axis)", RasterIcons.symbol(symbol, axis: axis), size))
            }
            for command in DefaultCommands.list(for: axis) + [DefaultCommands.stayOnTop(axis: axis)] {
                icons.append((command.id, RasterIcons.command(command), size))
            }
        }
        for (name, image, size) in icons {
            #expect(image.size == size, "\(name)")
            #expect(image.isTemplate, "\(name)")
            let alpha = try Self.alpha(image)
            #expect(alpha.values.contains { $0 > 0.9 }, "\(name) heeft geen dekkende pixels")
        }
    }

    /// Alfakanaal van een afbeelding na rasteren op 2x, als waarden 0…1.
    private struct Alpha {
        var width: Int, height: Int, values: [Double]
        subscript(x: Int, y: Int) -> Double { values[y * width + x] }
    }

    private enum RasterError: Error { case bitmap }

    private static func alpha(_ image: NSImage, scale: CGFloat = 2) throws -> Alpha {
        let width = Int((image.size.width * scale).rounded()), height = Int((image.size.height * scale).rounded())
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { throw RasterError.bitmap }
        rep.size = image.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()
        var values: [Double] = []
        values.reserveCapacity(width * height)
        // Rij 0 van de bitmap is de bovenkant.
        for y in 0..<height {
            for x in 0..<width {
                values.append(Double(rep.colorAt(x: x, y: y)?.alphaComponent ?? 0))
            }
        }
        return Alpha(width: width, height: height, values: values)
    }
}
