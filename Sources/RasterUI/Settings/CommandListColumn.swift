import AppKit
import RasterCore
import SwiftUI

/// Toestand die alleen `raster-render` zet om hover en een ingeklapte sectie te kunnen tekenen (offscreen is er geen
/// muis). De app zet hem nooit; een nieuwe lijstkolom leest hem één keer bij het aanmaken.
@MainActor
package enum CommandListPreview {
    /// Rij die getekend wordt alsof de muis erboven hangt: `CommandListRow.id`, dus de id van het commando of
    /// "divider:<as>:<id>" (bijv. "divider:horizontal:divider-1").
    package static var hoveredRowID: String?
    /// Secties die ingeklapt beginnen.
    package static var collapsed: Set<CommandAxis> = []
}

/// Lijstkolom van Commands: 275 pt, `listBackground`, kop "Commands" (x 24) en daaronder, scrollend, de secties
/// Horizontal en Vertical met hun rijen. Kiezen, toevoegen van een commando en verwijderen gaan via het paneel
/// (dat de meldingen toont); zichtbaarheid, scheidingsrijen en de volgorde past de kolom zelf aan in het model.
struct CommandListColumn: View {
    let model: CommandsModel
    let selectedID: String?
    let select: (String) -> Void
    let addCommand: (CommandAxis) -> Void
    let remove: (CommandListRow) -> Void

    @State private var collapsed = CommandListPreview.collapsed
    @State private var drag: CommandListDrag?
    @State private var dropTarget: (axis: CommandAxis, index: Int)?
    private let hoveredRowID = CommandListPreview.hoveredRowID

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: L10n.settingsContentTitleCommands, leading: 24)
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        if model.isReadOnly {
                            ReadOnlyBanner(model: model)
                                .font(.system(size: 11))
                                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                                .padding(.horizontal, 24)
                                .padding(.top, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        ForEach(CommandAxis.allCases, id: \.self) { axis in
                            section(axis)
                        }
                    }
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.automatic)
                .onAppear {
                    // Commands openen met een gekozen commando buiten beeld (bijv. in Vertical): ernaartoe scrollen.
                    guard let selectedID else { return }
                    proxy.scrollTo(selectedID)
                }
                .onChange(of: selectedID) { _, id in
                    // Een nieuw commando staat onderaan: in beeld brengen.
                    guard let id else { return }
                    withAnimation { proxy.scrollTo(id) }
                }
            }
            .background(RasterColor.listBackground.color)
        }
        .frame(width: SettingsMetrics.listWidth)
    }

    // MARK: - Sectie

    @ViewBuilder private func section(_ axis: CommandAxis) -> some View {
        let list = model.lists[axis]
        let rows = CommandListRow.rows(of: model.lists, axis: axis)
        let isExpanded = !collapsed.contains(axis)
        CommandListSectionHeader(
            title: axis == .vertical ? L10n.commandListSectionAxisTitleVertical
                                     : L10n.commandListSectionAxisTitleHorizontal,
            isExpanded: isExpanded,
            isReadOnly: model.isReadOnly,
            toggle: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded { collapsed.insert(axis) } else { collapsed.remove(axis) }
                }
            },
            addCommand: {
                collapsed.remove(axis)
                addCommand(axis)
            },
            addDivider: {
                collapsed.remove(axis)
                model.insertDivider(axis, at: list.layout.entries.count)
            })
        if isExpanded {
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    rowView(row, axis: axis)
                        .id(row.id)
                        .onDrag {
                            drag = CommandListDrag(axis: axis, rowID: row.id)
                            return CommandListDrag.itemProvider(for: row.id)
                        }
                }
            }
            .overlay(alignment: .topLeading) {
                if let dropTarget, dropTarget.axis == axis, showsInsertion(at: dropTarget.index, rows: rows) {
                    CommandListInsertionLine()
                        .offset(y: CGFloat(dropTarget.index) * CommandListLogic.rowHeight - 3.5)
                }
            }
            .onDrop(of: CommandListDrag.types, delegate: CommandListDropDelegate(
                axis: axis, count: rows.count, isReadOnly: model.isReadOnly, drag: $drag,
                target: Binding(get: { dropTarget?.axis == axis ? dropTarget?.index : nil },
                                set: { dropTarget = $0.map { (axis, $0) } }),
                move: { rowID, to in move(axis, rowID: rowID, to: to) }))
            .transition(.opacity)
        }
    }

    private func rowView(_ row: CommandListRow, axis: CommandAxis) -> some View {
        let buttons: [CommandRowButton]
        switch row {
        case .command(let command):
            buttons = CommandRowButton.buttons(for: command, isRemovable: model.isRemovable(command.id),
                                               isReadOnly: model.isReadOnly)
        case .divider:
            buttons = CommandRowButton.dividerButtons(isReadOnly: model.isReadOnly)
        }
        return CommandListRowView(
            row: row,
            isSelected: row.command != nil && row.command?.id == selectedID,
            buttons: buttons,
            isHovered: row.id == hoveredRowID,
            onTap: {
                // Scheidingsrijen zijn niet te kiezen.
                if let command = row.command { select(command.id) }
            },
            onButton: { kind in press(kind, on: row) })
    }

    // MARK: - Acties

    private func press(_ kind: CommandRowButton.Kind, on row: CommandListRow) {
        guard !model.isReadOnly else { return }
        switch (kind, row) {
        case (.greenMenu, .command(let command)):
            model.setInZoomButtonMenu(!command.inZoomButtonMenu, for: command.id)
        case (.menuBar, .command(let command)):
            model.setInMenuBar(!command.inMenuBar, for: command.id)
        case (.remove, _):
            remove(row)
        default:
            break
        }
    }

    /// De invoeglijn, behalve op de plaats waar de gesleepte rij al staat.
    private func showsInsertion(at index: Int, rows: [CommandListRow]) -> Bool {
        guard let drag, let from = rows.firstIndex(where: { $0.id == drag.rowID }) else { return true }
        return CommandListLogic.isMove(from: from, to: index)
    }

    /// Rij `rowID` naar plaats `to` in de lijst van `axis`; niets als de rij daar niet (meer) in staat.
    private func move(_ axis: CommandAxis, rowID: String, to: Int) {
        let rows = CommandListRow.rows(of: model.lists, axis: axis)
        guard !model.isReadOnly, let from = rows.firstIndex(where: { $0.id == rowID }),
              let change = CommandListLogic.entryMove(from: from, to: to, rows: rows,
                                                      entries: model.lists[axis].layout.entries) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            model.moveLayout(axis, fromOffsets: IndexSet(integer: change.source), toOffset: change.destination)
        }
    }
}
