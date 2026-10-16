import AppKit
import RasterCore
import SwiftUI

/// Detailkolom van Commands (528 pt, `background`): kop met de hernoembare naam van het commando (titel op x 35) en
/// daaronder, scrollend, de kaarten van 486 pt op x 21, de eerste 22 pt onder de koplijn en 18 pt ertussen:
/// 1. "Intended window size and position" (alleen commando's met een gebied);
/// 2. "Keyboard shortcut";
/// 3. "Activation area for dragging" (alleen commando's met sleepzones);
/// 4. "Visible in menu bar" en "Visible in green button menu", elk een eigen kaart.
///
/// Speciale commando's (Center, Restore, Next/Previous Display) hebben dus alleen kaarten 2 en 4. Kan de lijst niet
/// bewaard worden (alleen-lezen), dan is alles uitgeschakeld.
struct CommandDetail: View {
    let model: CommandsModel
    let commandID: String?

    init(model: CommandsModel, commandID: String?) {
        self.model = model
        self.commandID = commandID
    }

    /// Ruimte tussen de kaarten, en van de koplijn tot de eerste kaart.
    static let cardSpacing: CGFloat = 18
    static let topInset: CGFloat = 22

    var body: some View {
        let command = commandID.flatMap(model.command)
        VStack(spacing: 0) {
            CommandTitleHeader(model: model, command: command)
            if let command {
                ScrollView(.vertical) {
                    VStack(spacing: Self.cardSpacing) {
                        CommandDetailCards(model: model, command: command)
                    }
                    .padding(.vertical, Self.topInset)
                    .frame(maxWidth: .infinity)
                    .disabled(model.isReadOnly)
                }
                .scrollIndicators(.automatic)
                // Een ander commando begint weer bovenaan.
                .id(command.id)
            } else {
                Spacer(minLength: 0)
            }
        }
        .background(RasterColor.background.color)
    }
}

/// Kop van de detailkolom: 51 pt `toolbar` met de naam van het commando als tekstveld zonder rand (SF 15 semibold,
/// basislijn 31, x 35) en een lijn eronder. Tooltip "Rename", placeholder "Command"; Enter of de focus kwijtraken
/// bewaart de naam (`CommandsModel.setName`, die lege namen terugzet). In een inactief venster is de naam grijs.
private struct CommandTitleHeader: View {
    let model: CommandsModel
    let command: Command?

    static let leading: CGFloat = 35

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let command {
                    CommandTitleField(model: model, command: command)
                        // Eigen invoer per commando: wisselen begint met de naam van het nieuwe commando.
                        .id(command.id)
                        .disabled(model.isReadOnly)
                } else {
                    Color.clear
                }
            }
            .padding(.leading, Self.leading)
            .padding(.trailing, 21)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: SettingsMetrics.headerHeight)
            .background(RasterColor.toolbar.color)
            SeparatorLine(axis: .horizontal)
        }
    }
}

/// Het tekstveld met de naam in de kop (zie `CommandTitleHeader`).
private struct CommandTitleField: View {
    let model: CommandsModel
    let command: Command

    @State private var text: String
    @FocusState private var isFocused: Bool
    @Environment(\.controlActiveState) private var activeState

    init(model: CommandsModel, command: Command) {
        self.model = model
        self.command = command
        self._text = State(initialValue: command.name)
    }

    var body: some View {
        let color = Color(nsColor: activeState == .inactive ? .secondaryLabelColor : .labelColor)
        // Het tekstveld vangt de klikken en toont de naam alleen tijdens het bewerken; daarbuiten staat er dezelfde
        // tekst als in de andere koppen overheen. Offscreen getekend is de tekst van het veld te zwaar (gemeten: zwart
        // in plaats van 85 % zwart), en zo is de kop gelijk aan de andere koppen. Beide op basislijn 31.
        ZStack(alignment: .topLeading) {
            BaselineStack(baselines: [31], bottom: SettingsMetrics.headerHeight - 31) {
                TextField(L10n.commandDefaultName, text: $text)
                    .textFieldStyle(.plain)
                    .font(Self.font)
                    // Doorzichtige tekst en niet `opacity(0)`: dan vangt het veld geen klikken meer.
                    .foregroundStyle(isFocused ? color : .clear)
                    .lineLimit(1)
                    .focused($isFocused)
                    .help(L10n.commandContentTitleTextfieldTooltip)
                    .onSubmit {
                        commit()
                        isFocused = false
                    }
            }
            .frame(height: SettingsMetrics.headerHeight, alignment: .top)
            if !isFocused {
                BaselineStack(baselines: [31], bottom: SettingsMetrics.headerHeight - 31) {
                    Text(text.isEmpty ? L10n.commandDefaultName : text)
                        .font(Self.font)
                        .foregroundStyle(text.isEmpty ? Color(nsColor: .placeholderTextColor) : color)
                        .lineLimit(1)
                }
                .frame(height: SettingsMetrics.headerHeight, alignment: .top)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused { commit() }
        }
        .onChange(of: command.name) { _, name in
            // Van buitenaf hernoemd (of teruggezet): tonen, behalve tijdens het typen.
            if !isFocused { text = name }
        }
        // Wegklikken naar een ander commando terwijl het veld nog focus heeft: toch bewaren.
        .onDisappear { commit() }
    }

    /// SF 15 semibold, zoals de andere koppen.
    private static let font = Font.system(size: 15, weight: .semibold)

    /// Bewaart de getypte naam en toont daarna wat het model ervan maakte (een lege naam wordt teruggezet).
    private func commit() {
        guard let stored = model.command(command.id) else { return }
        if text != stored.name { model.setName(text, for: command.id) }
        text = model.command(command.id)?.name ?? text
    }
}
