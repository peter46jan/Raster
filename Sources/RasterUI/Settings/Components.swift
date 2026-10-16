import AppKit
import SwiftUI

// Bouwstenen van het instellingenvenster, op vaste maten (gemeten in schermafbeeldingen, alles in pt).

/// Kaart met rijen, zoals de kaarten in Preferences en Commands: 486 breed, hoekradius 6, vulling `card`,
/// haarlijnrand `border`. Tussen de rijen komt vanzelf een scheidingslijn (x 12 … breedte − 12, `divider`).
package struct SettingsCard<Content: View>: View {
    package static var width: CGFloat { 486 }

    let content: Content

    package init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    package var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        VStack(spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    row.overlay(alignment: .top) {
                        // De lijn ligt op de grens tussen twee rijen en neemt zelf geen hoogte in.
                        if index > 0 {
                            Rectangle()
                                .fill(RasterColor.divider.color)
                                .frame(height: 0.5)
                                .padding(.horizontal, 12)
                                .offset(y: -0.25)
                        }
                    }
                }
            }
        }
        // Ruimte voor de rand (0,5 pt boven en onder): de rijen houden hun maat binnen de rand.
        .padding(.vertical, 0.5)
        .frame(width: Self.width)
        .background(shape.fill(RasterColor.card.color))
        .overlay(shape.strokeBorder(RasterColor.border.color, lineWidth: 0.5))
    }
}

/// Kop boven een kaart in Preferences ("General", "Mouse", …): SF 13 semibold op x kaart + 14. De basislijn ligt
/// 35 pt onder de vorige kaart (of de koplijn), de volgende kaart begint 14 pt onder de basislijn.
package struct SectionTitle: View {
    let title: String

    package init(_ title: String) {
        self.title = title
    }

    package var body: some View {
        BaselineStack(baselines: [35], bottom: 14) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(nsColor: .labelColor))
        }
        .padding(.leading, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Plaats van het bedieningselement rechts in een `SettingsRow`.
package enum TrailingPlacement {
    /// Op de titelregel (schakelaars): midden 20 pt onder de bovenkant van de rij.
    case titleLine
    /// Verticaal gecentreerd in de rij (steppers en pop-ups).
    case centered
}

/// Rij in een kaart: titel SF 13 (basislijn 25 pt onder de bovenkant, x 14) en eventueel een subtitel SF 11
/// (`secondaryLabelColor`). Elke regel van de subtitel staat op een eigen vaste basislijn: 41 pt onder de bovenkant en
/// daarna steeds 14 pt verder (gemeten); een `Text` van meerdere regels zou in SwiftUI bij SF 11 een
/// regelafstand van 15 pt krijgen. Subtitels breken zelf af met "\n"; elke regel blijft op één regel.
///
/// Een rij zonder subtitel is 39 pt hoog (14 pt onder de basislijn van de titel). Een rij met subtitel eindigt 14,5 pt
/// onder de laatste regel: met twee regels 69,5 pt, wat de kaartposities precies geeft (twee zulke rijen
/// samen 1 pt meer dan 69 + 69). Het bedieningselement staat rechts, 14 pt van de rand, en krijgt de titel als
/// (verborgen) label voor VoiceOver.
package struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var placement: TrailingPlacement
    @ViewBuilder let trailing: Trailing

    package init(title: String, subtitle: String? = nil, placement: TrailingPlacement = .titleLine,
                 @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.placement = placement
        self.trailing = trailing()
    }

    /// De regels van een subtitel (gesplitst op "\n"), zonder spaties aan het eind.
    static func subtitleLines(_ subtitle: String) -> [String] {
        subtitle.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            var line = Substring(line)
            while line.last == " " { line = line.dropLast() }
            return String(line)
        }
    }

    package var body: some View {
        let lines = subtitle.map(Self.subtitleLines) ?? []
        BaselineStack(baselines: [25] + lines.indices.map { 41 + 14 * CGFloat($0) },
                      bottom: lines.isEmpty ? 14 : 14.5) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Color(nsColor: .labelColor))
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                // VoiceOver leest de subtitel als één tekst: de eerste regel draagt hem helemaal.
                Text(line)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .lineLimit(1)
                    .fixedSize()
                    .accessibilityLabel(lines.joined(separator: " "))
                    .accessibilityHidden(index > 0)
            }
        }
        .padding(.leading, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: placement == .titleLine ? .topTrailing : .trailing) {
            trailing
                .environment(\.settingsRowTitle, title)
                .frame(height: placement == .titleLine ? 40 : nil)
                .padding(.trailing, 14)
        }
    }
}

/// Kleine schakelaar van het systeem (26 × 15) in de accentkleur. Label voor VoiceOver: `label`, anders de titel van
/// de rij.
package struct MiniSwitch: View {
    @Binding var isOn: Bool
    var label: String?

    @Environment(\.settingsRowTitle) private var rowTitle

    package init(isOn: Binding<Bool>, label: String? = nil) {
        self._isOn = isOn
        self.label = label
    }

    package var body: some View {
        let _ = assertLabeled(label ?? rowTitle, "MiniSwitch")
        Toggle(label ?? rowTitle, isOn: $isOn)
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            .tint(RasterColor.accent)
    }
}

/// Waarde met een systeem-stepper ("80 %", "8 pt"): de waarde SF 13 rechts uitgelijnd, 7 pt voor de stepper
/// (zichtbaar 17 × 23). In een rij staat het frame 14 pt van de rand, de zichtbare stepper daardoor op 12.
/// VoiceOver leest de stepper met de titel van de rij (of `label`) als label en `text` als waarde.
package struct StepperValue<Value: Strideable>: View {
    let text: String
    @Binding var value: Value
    let range: ClosedRange<Value>
    let step: Value.Stride
    var label: String?

    @Environment(\.settingsRowTitle) private var rowTitle

    package init(text: String, value: Binding<Value>, in range: ClosedRange<Value>, step: Value.Stride = 1,
                 label: String? = nil) {
        self.text = text
        self._value = value
        self.range = range
        self.step = step
        self.label = label
    }

    package var body: some View {
        let _ = assertLabeled(label ?? rowTitle, "StepperValue")
        HStack(spacing: 7) {
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Color(nsColor: .labelColor))
                .accessibilityHidden(true)
            Stepper(label ?? rowTitle, value: $value, in: range, step: step)
                .labelsHidden()
                .accessibilityValue(text)
        }
    }
}

/// Pop-upknop van het systeem ("Automatic"), zo breed als de langste keuze (zichtbaar ≈ 96 × 21). In een rij staat
/// het frame 14 pt van de rand, de zichtbare knop daardoor op 13. Label voor VoiceOver: `label`, anders de titel
/// van de rij.
package struct PopUp<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, title: String)]
    var label: String?

    @Environment(\.settingsRowTitle) private var rowTitle

    package init(selection: Binding<Value>, options: [(value: Value, title: String)], label: String? = nil) {
        self._selection = selection
        self.options = options
        self.label = label
    }

    package var body: some View {
        let _ = assertLabeled(label ?? rowTitle, "PopUp")
        Picker(label ?? rowTitle, selection: $selection) {
            ForEach(options, id: \.value) { option in
                Text(option.title).tag(option.value)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .fixedSize()
    }
}

/// Ronde knop met een sjabloonicoon van 20 × 20 (cirkel 16 pt, symbool uitgespaard) in `control`; bij hover iets
/// donkerder.
struct CircleIconButton: View {
    let image: NSImage
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            TemplateImage(image: image, color: isHovered ? Self.hoverColor : RasterColor.control.nsColor)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(tooltip)
        .accessibilityLabel(tooltip)
    }

    /// `control` (183) iets donkerder, in donker iets lichter.
    private static let hoverColor = NSColor(name: nil) { appearance in
        let dark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return NSColor(white: dark ? 0.8 : 0.6, alpha: 1)
    }
}

/// Sjabloonicoon ingekleurd met `color`, getekend door AppKit: zo blijft een `NSImage` met tekenfunctie op elke
/// schaal scherp (SwiftUI rastert zo'n afbeelding offscreen op 1x). Het icoon vangt geen klikken (die gaan naar de
/// knop eromheen) en is voor VoiceOver geen eigen element; de knop geeft het label.
struct TemplateImage: NSViewRepresentable {
    let image: NSImage
    let color: NSColor

    /// NSImageView die doorlaat: anders geeft `hitTest` de afbeelding en komt een klik op het icoon niet bij de knop.
    final class PassThroughImageView: NSImageView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    func makeNSView(context: Context) -> NSImageView {
        let view = PassThroughImageView()
        view.imageScaling = .scaleNone
        view.isEditable = false
        view.setAccessibilityElement(false)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        return view
    }

    func updateNSView(_ view: NSImageView, context: Context) {
        view.image = image
        view.contentTintColor = color
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSImageView, context: Context) -> CGSize? {
        image.size
    }
}

/// Zet tekstregels op vaste basislijnen, gemeten vanaf de bovenkant: het eerste kind met zijn eerste basislijn op
/// `baselines[0]`, het tweede op `baselines[1]`, enzovoort; kinderen zonder eigen basislijn in `baselines` komen
/// direct onder het vorige kind. De hoogte eindigt `bottom` pt onder de laatste basislijn van het laatste kind. Zo
/// kloppen de maten ongeacht de regelhoogte die SwiftUI een tekst geeft.
struct BaselineStack: Layout {
    var baselines: [CGFloat]
    var bottom: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let lastBaseline = placements(width: width, subviews: subviews).last.map { $0.y + $0.lastBaseline } ?? 0
        return CGSize(width: width, height: lastBaseline + bottom)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, placement) in zip(subviews, placements(width: bounds.width, subviews: subviews)) {
            subview.place(at: CGPoint(x: bounds.minX, y: bounds.minY + placement.y), anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: nil))
        }
    }

    /// Per kind de bovenkant (y) en de afstand van die bovenkant tot zijn laatste basislijn.
    private func placements(width: CGFloat, subviews: Subviews) -> [(y: CGFloat, lastBaseline: CGFloat)] {
        var result: [(y: CGFloat, lastBaseline: CGFloat)] = []
        var previousBottom: CGFloat = 0
        for (index, subview) in subviews.enumerated() {
            let size = subview.dimensions(in: ProposedViewSize(width: width, height: nil))
            let y = index < baselines.count ? baselines[index] - size[VerticalAlignment.firstTextBaseline] : previousBottom
            result.append((y, size[VerticalAlignment.lastTextBaseline]))
            previousBottom = y + size.height
        }
        return result
    }
}

/// Alleen in debug: een bedieningselement zonder label (geen `label:` en niet in een `SettingsRow` met titel) is voor
/// VoiceOver naamloos; dat moet bij het bouwen opvallen.
private func assertLabeled(_ label: String, _ control: StaticString) {
    assert(!label.isEmpty, "\(control) zonder label: geef `label:` mee of zet het in een SettingsRow met titel")
}

extension EnvironmentValues {
    /// Titel van de `SettingsRow` waarin een bedieningselement staat: zijn label voor VoiceOver.
    @Entry var settingsRowTitle = ""
}
