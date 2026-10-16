import Foundation

/// `commands.json` versie 2: per as een lijst met commando's en volgorde.
struct StoredCommands: Encodable {
    static let currentVersion = 2

    var version = StoredCommands.currentVersion
    var horizontal: CommandList
    var vertical: CommandList
}

/// Alleen het versienummer, om te kiezen hoe de rest gelezen wordt. Ontbreekt het, dan is het versie 1.
private struct StoredVersion: Decodable {
    var version: Int?
}

/// Versie 2 lezen, elke lijst apart: een onleesbare lijst is nil, de andere blijft.
private struct StoredLists: Decodable {
    var horizontal: CommandList?
    var vertical: CommandList?
    /// Waar als er bij het lezen iets wegviel: een hele lijst, een commando, de volgorde of een regel daarvan.
    var lostSomething: Bool

    private struct Decoded: Decodable {
        let list: CommandList
        let lost: Bool

        init(from decoder: Decoder) throws {
            (list, lost) = try CommandList.decodeReportingLoss(from: decoder)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case horizontal, vertical
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let horizontal = try? container.decode(Decoded.self, forKey: .horizontal)
        let vertical = try? container.decode(Decoded.self, forKey: .vertical)
        self.horizontal = horizontal?.list
        self.vertical = vertical?.list
        lostSomething = (horizontal?.lost ?? true) || (vertical?.lost ?? true)
    }
}

/// Het lezen van `commands.json`: versie kiezen, versie 1 omzetten, beschadigde lijsten herstellen.
/// Let op: laden is niet alleen lezen. Het kan het bestand kopiëren (back-up vóór omzetten of herstel) of
/// verplaatsen (een onleesbaar bestand), en een omgezet of hersteld resultaat moet daarna bewaard worden (`needsSave`).
enum CommandFile {
    struct Loaded {
        var lists: CommandLists
        var readOnlyReason: CommandStore.ReadOnlyReason?
        /// Omgezet of hersteld, en het origineel is apart bewaard: nu als versie 2 bewaren.
        var needsSave = false

        /// Na een back-up van het origineel bewaren; is die mislukt, dan alleen-lezen (ook latere wijzigingen
        /// overschrijven het origineel dan niet).
        static func repaired(_ lists: CommandLists, backedUp: Bool) -> Loaded {
            Loaded(lists: lists, readOnlyReason: backedUp ? nil : .backupFailed, needsSave: backedUp)
        }

        static func readOnly(_ reason: CommandStore.ReadOnlyReason) -> Loaded {
            Loaded(lists: .standard, readOnlyReason: reason)
        }
    }

    static func load(from url: URL) -> Loaded {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return Loaded(lists: .standard)
        } catch {
            // Wel een bestand, maar niet te lezen: niets overschrijven.
            return .readOnly(.unreadable)
        }
        guard let stored = try? JSONDecoder().decode(StoredVersion.self, from: data) else { return movedAside(url) }
        let version = stored.version ?? 1
        if version > StoredCommands.currentVersion { return .readOnly(.newerFormat) }
        if version < StoredCommands.currentVersion {
            // Versie 1 (fase 1–5): omzetten. Lukt dat niet, dan is het bestand onleesbaar.
            guard let lists = try? CommandMigration.migrate(data) else { return movedAside(url) }
            return .repaired(lists.normalized().lists, backedUp: backUpVersionOne(url))
        }
        guard let stored = try? JSONDecoder().decode(StoredLists.self, from: data) else { return movedAside(url) }
        // Een onleesbare lijst valt terug op de standaard, een onleesbaar commando of een onleesbare volgorde valt weg.
        let (lists, dropped) = CommandLists(horizontal: stored.horizontal ?? CommandLists.standard.horizontal,
                                            vertical: stored.vertical ?? CommandLists.standard.vertical).normalized()
        guard stored.lostSomething || dropped else { return Loaded(lists: lists) }
        // Er viel iets weg: het bestand eerst bewaren (het origineel blijft staan), dan pas overschrijven.
        return .repaired(lists, backedUp: backUp(url, keepingOriginal: true))
    }

    /// Een onleesbaar bestand gaat opzij als back-up en de standaard komt ervoor in de plaats; lukt dat niet,
    /// dan alleen-lezen.
    private static func movedAside(_ url: URL) -> Loaded {
        backUp(url, keepingOriginal: false) ? Loaded(lists: .standard) : .readOnly(.backupFailed)
    }

    /// Bewaart een bestand van fase 1–5 als `commands-v1.json.bak`; bestaat die al, dan als
    /// `commands.json.<datum-tijd>.bak` (de eerdere back-up blijft staan).
    private static func backUpVersionOne(_ url: URL) -> Bool {
        let backup = url.deletingLastPathComponent().appending(path: "commands-v1.json.bak")
        if FileManager.default.fileExists(atPath: backup.path) { return backUp(url, keepingOriginal: true) }
        return (try? FileManager.default.copyItem(at: url, to: backup)) != nil
    }

    /// Kopieert of verplaatst het bestand naar `commands.json.<datum-tijd>.bak` (met een volgnummer als die al
    /// bestaat, zodat een eerdere back-up blijft staan). Geeft terug of het gelukt is.
    private static func backUp(_ url: URL, keepingOriginal: Bool) -> Bool {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let base = url.lastPathComponent + "." + formatter.string(from: Date())
        var backup = url.deletingLastPathComponent().appending(path: base + ".bak")
        var number = 2
        while FileManager.default.fileExists(atPath: backup.path) {
            backup = url.deletingLastPathComponent().appending(path: "\(base)-\(number).bak")
            number += 1
        }
        if keepingOriginal {
            return (try? FileManager.default.copyItem(at: url, to: backup)) != nil
        }
        return (try? FileManager.default.moveItem(at: url, to: backup)) != nil
    }
}
