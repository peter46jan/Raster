import AppKit
import RasterCore
import SwiftUI

/// Sneltoetsveld; uitgeschakeld (vaag, niet klikbaar) als `command.shortcutEnabled` false is.
///
/// 24 pt hoog en zo breed als de container; wit (donker `shortcutField`), hoekradius ≈ 8, haarlijnrand en een zachte
/// schaduw onder. Tekst SF 13 gecentreerd: de sneltoets ("⌃⌥◀"), anders "Click to set shortcut"; tijdens het opnemen
/// "Start typing your shortcut" en bij een combinatie die op dezelfde as al gebruikt wordt "This combination is taken"
/// in rood (de opname loopt dan door). Een klik start of stopt het opnemen (`CommandsModel`).
package struct ShortcutField: View {
    let model: CommandsModel
    let command: Command

    package init(model: CommandsModel, command: Command) {
        self.model = model
        self.command = command
    }

    static let height: CGFloat = 24
    /// Hoekradius (gemeten ≈ 8 continuous).
    static let radius: CGFloat = 8

    /// Het commando zoals het nu in het model staat (na opnemen staat daar de nieuwe sneltoets).
    private var current: Command { model.command(command.id) ?? command }
    private var isRecording: Bool { model.recordingID == command.id }
    private var isEnabled: Bool { current.shortcutEnabled }

    /// Tekst en kleur in het veld.
    static func title(shortcut: Shortcut?, isRecording: Bool,
                      error: CommandsModel.RecordingError?) -> (text: String, style: TitleStyle) {
        if isRecording {
            return error == .taken ? (L10n.shortcutsFieldTitleErrorTaken, .error) : (L10n.shortcutsFieldTitleEdit, .placeholder)
        }
        guard let shortcut else { return (L10n.shortcutsFieldTitleView, .placeholder) }
        return (shortcut.displayString, .shortcut)
    }

    enum TitleStyle: Equatable {
        case shortcut, placeholder, error

        var color: Color {
            switch self {
            case .shortcut: Color(nsColor: .labelColor)
            case .placeholder: Color(nsColor: .secondaryLabelColor)
            case .error: RasterColor.red.color
            }
        }
    }

    package var body: some View {
        let title = Self.title(shortcut: current.shortcut, isRecording: isRecording,
                               error: isRecording ? model.recordingError : nil)
        let shape = RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
        Button {
            if isRecording { model.cancelRecording() } else { model.startRecording(for: command.id) }
        } label: {
            Text(title.text)
                .font(.system(size: 13))
                .foregroundStyle(title.style.color)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: Self.height)
                .background {
                    // Gemeten maten (veld op 42 in de kaart): haarlijn ≈ 5 % zwart boven (0,5 pt boven het veld) en
                    // opzij (0,5 pt binnen de rand), wit tot 0,5 pt onder het veld en daaronder een zachte schaduw
                    // (226 / 200 / 221). Zelf getekend en geen `.shadow`: die tekent `cacheDisplay` (raster-render)
                    // gespiegeld.
                    ZStack {
                        // De schaduw alleen onder: smaller dan het veld, zodat hij opzij niet uitsteekt.
                        Group {
                            shape.fill(Color.black.opacity(0.087)).offset(y: 1.5)
                            shape.fill(Color.black.opacity(0.06)).offset(y: 1)
                        }
                        .padding(.horizontal, 1)
                        shape.fill(Color.black.opacity(0.05))
                        RoundedRectangle(cornerRadius: Self.radius - 0.5, style: .continuous)
                            .fill(Self.fill)
                            .padding(EdgeInsets(top: 0.5, leading: 0.5, bottom: 0, trailing: 0.5))
                    }
                    .padding(EdgeInsets(top: -0.5, leading: 0.5, bottom: -0.5, trailing: 0.5))
                }
                .overlay {
                    // Tijdens het opnemen een focusrand in de accentkleur.
                    if isRecording {
                        shape.inset(by: -1.5).strokeBorder(RasterColor.accent.opacity(0.5), lineWidth: 3)
                    }
                }
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .dimmedWhenDisabled(isEnabled)
        .accessibilityLabel(L10n.commandContentKeyboardShortcutTitle)
        .accessibilityValue(title.text)
        .onChange(of: isEnabled) { _, enabled in
            if !enabled && isRecording { model.cancelRecording() }
        }
    }

    /// Wit (gemeten 255; `shortcutField` zelf is 252), in donker `shortcutField`.
    private static let fill = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? RasterColor.shortcutField.nsColor.resolved(for: appearance)
            : .white
    })
}

private extension NSColor {
    /// Deze (dynamische) kleur zoals hij onder `appearance` getekend wordt.
    func resolved(for appearance: NSAppearance) -> NSColor {
        var result = self
        appearance.performAsCurrentDrawingAppearance { result = self.usingColorSpace(.sRGB) ?? self }
        return result
    }
}
