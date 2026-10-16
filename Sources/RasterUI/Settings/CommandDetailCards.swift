import RasterCore
import SwiftUI

/// De kaarten van de detailkolom voor `command` (zie `CommandDetail`), in vaste volgorde. Elke wijziging gaat
/// meteen naar het model.
struct CommandDetailCards: View {
    let model: CommandsModel
    let command: Command

    /// Een kaart van de detailkolom.
    enum Card: Equatable {
        case target, shortcut, activation, menuBar, greenButton
    }

    /// De kaarten voor `command`: het doelgebied alleen bij een gebied, het activeringsraster alleen bij sleepzones
    /// (speciale commando's hebben dus alleen sneltoets en zichtbaarheid).
    static func cards(for command: Command) -> [Card] {
        (command.area == nil ? [] : [.target]) + [.shortcut] + (command.dragZones == nil ? [] : [.activation])
            + [.menuBar, .greenButton]
    }

    var body: some View {
        ForEach(Self.cards(for: command), id: \.self) { card in
            switch card {
            case .target: targetCard
            case .shortcut: shortcutCard
            case .activation: activationCard
            case .menuBar:
                DetailCard(title: L10n.commandContentVisibleInMenuBarTitle, height: CommandDetailMetrics.switchHeight,
                           isOn: binding(\.inMenuBar, model.setInMenuBar))
            case .greenButton:
                DetailCard(title: L10n.commandContentVisibleInGreenButtonMenuTitle,
                           height: CommandDetailMetrics.switchHeight,
                           isOn: binding(\.inZoomButtonMenu, model.setInZoomButtonMenu))
            }
        }
    }

    /// 1. "Intended window size and position": het raster horizontaal gecentreerd, 73 pt onder de bovenkant.
    @ViewBuilder private var targetCard: some View {
        let grid = command.axis.grid
        let size = TargetAreaGrid.size(of: grid)
        DetailCard(title: L10n.commandContentTargetAreaTitle, height: CommandDetailMetrics.targetHeight(grid),
                   contentOrigin: CGPoint(x: CommandDetailMetrics.centered(size.width),
                                          y: CommandDetailMetrics.targetTop)) {
            TargetAreaGrid(grid: grid, area: command.area ?? GridArea(segments: [])) {
                model.setArea($0, for: command.id)
            }
        }
    }

    /// 2. "Keyboard shortcut": schakelaar en het sneltoetsveld op (14, 42).
    private var shortcutCard: some View {
        DetailCard(title: L10n.commandContentKeyboardShortcutTitle, height: CommandDetailMetrics.shortcutHeight,
                   contentOrigin: CGPoint(x: CommandDetailMetrics.inset, y: CommandDetailMetrics.shortcutTop),
                   isOn: binding(\.shortcutEnabled, model.setShortcutEnabled)) {
            ShortcutField(model: model, command: command)
                .frame(width: CommandDetailMetrics.shortcutWidth)
        }
    }

    /// 3. "Activation area for dragging": schakelaar en het stippenraster horizontaal gecentreerd, 62 pt onder de
    /// bovenkant, met de zones van de andere commando's in dezelfde lijst.
    @ViewBuilder private var activationCard: some View {
        let grid = command.axis.grid
        let size = ActivationAreaGrid.size(of: grid)
        DetailCard(title: L10n.commandContentActivationAreaTitle, height: CommandDetailMetrics.activationHeight(grid),
                   contentOrigin: CGPoint(x: CommandDetailMetrics.centered(size.width),
                                          y: CommandDetailMetrics.activationTop),
                   isOn: binding(\.dragZonesEnabled, model.setDragZonesEnabled)) {
            ActivationAreaGrid(
                grid: grid, zones: command.dragZones ?? GridArea(segments: []),
                others: ActivationAreaGrid.others(for: command, in: model.commands(for: command.axis)),
                isEnabled: command.dragZonesEnabled,
                onChange: { model.setDragZones($0, for: command.id) },
                onRemoveOther: { other, cell in model.removeDragZone(at: cell, from: other.id) })
        }
    }

    /// Schakelaar voor een eigenschap van het commando, via de bijbehorende functie van het model.
    private func binding(_ keyPath: KeyPath<Command, Bool>,
                         _ set: @escaping @MainActor (Bool, String) -> Void) -> Binding<Bool> {
        let id = command.id
        return Binding(get: { model.command(id)?[keyPath: keyPath] ?? false }, set: { set($0, id) })
    }
}

/// Maten van de kaarten in de detailkolom (pt), gemeten in de referentie-schermafbeelding.
@MainActor
enum CommandDetailMetrics {
    /// Binnenmarge links en rechts (titel, sneltoetsveld, schakelaar).
    static let inset: CGFloat = 14

    /// Kaart 1: raster 73 pt onder de bovenkant, 43 pt tot de onderkant (Horizontal 306 hoog).
    static let targetTop: CGFloat = 73
    static func targetHeight(_ grid: GridSize) -> CGFloat { targetTop + TargetAreaGrid.size(of: grid).height + 43 }

    /// Kaart 2: sneltoetsveld op (14, 42), 458 breed (de haarlijn erboven ligt op 41,5); kaart 86 hoog.
    static let shortcutTop: CGFloat = 42
    static let shortcutWidth: CGFloat = SettingsCard<EmptyView>.width - 2 * inset
    static let shortcutHeight: CGFloat = 86

    /// Kaart 3: raster 62 pt onder de bovenkant, 42 pt tot de onderkant (Horizontal 296 hoog).
    static let activationTop: CGFloat = 62
    static func activationHeight(_ grid: GridSize) -> CGFloat {
        activationTop + ActivationAreaGrid.size(of: grid).height + 42
    }

    /// Kaarten "Visible in …": alleen titel en schakelaar (geschat).
    static let switchHeight: CGFloat = 40

    /// Links van inhoud van `width` pt die horizontaal in de kaart gecentreerd staat (Horizontal: 52 en 51).
    static func centered(_ width: CGFloat) -> CGFloat {
        ((SettingsCard<EmptyView>.width - width) / 2).rounded(.down)
    }
}

/// Kaart van de detailkolom: 486 breed en `height` hoog, hoekradius 6, vulling `card`, haarlijnrand `border`. Titel
/// SF 13 op x 14 met de basislijn 25 pt onder de bovenkant; met `isOn` rechts een mini-schakelaar (midden 20 pt onder
/// de bovenkant, 14 pt van de rand). De inhoud staat op `contentOrigin`.
struct DetailCard<Content: View>: View {
    let title: String
    let height: CGFloat
    var contentOrigin: CGPoint = .zero
    var isOn: Binding<Bool>?
    @ViewBuilder let content: Content

    init(title: String, height: CGFloat, contentOrigin: CGPoint = .zero, isOn: Binding<Bool>? = nil,
         @ViewBuilder content: () -> Content = { EmptyView() }) {
        self.title = title
        self.height = height
        self.contentOrigin = contentOrigin
        self.isOn = isOn
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        ZStack(alignment: .topLeading) {
            SettingsRow(title: title) {
                if let isOn {
                    // In de rij krijgt de schakelaar de titel al als label voor VoiceOver; hier ook expliciet, zodat
                    // hij zijn naam houdt als de kaart ooit niet meer op `SettingsRow` steunt.
                    MiniSwitch(isOn: isOn, label: title)
                }
            }
            content
                .padding(.leading, contentOrigin.x)
                .padding(.top, contentOrigin.y)
        }
        .frame(width: SettingsCard<EmptyView>.width, height: height, alignment: .topLeading)
        .background(shape.fill(RasterColor.card.color))
        .overlay(shape.strokeBorder(RasterColor.border.color, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
    }
}
