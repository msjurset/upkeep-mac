import SwiftUI

/// Renders the contents of a multi-event schedule section: one Form row per
/// sub-event plus an "Add event" button. Caller is responsible for wrapping
/// these in a `Section`. Returns nothing for items whose `scheduleKind` is
/// `.recurring` or `.idea` — sub-events only make sense for `.seasonal`
/// (annual windows) and `.oneTime` (project stages on absolute dates).
struct SubEventsEditor: View {
    @Binding var subEvents: [SubEvent]
    let parentScheduleKind: ScheduleKind

    var body: some View {
        if parentScheduleKind == .seasonal || parentScheduleKind == .oneTime {
            ForEach($subEvents) { $event in
                SubEventRow(
                    event: $event,
                    parentScheduleKind: parentScheduleKind,
                    onDelete: { id in
                        subEvents.removeAll { $0.id == id }
                    }
                )
            }
            Button {
                addEvent()
            } label: {
                Label("Add event", systemImage: "plus.circle")
            }
        }
    }

    private func addEvent() {
        let now = Calendar.current.dateComponents([.month, .day], from: .now)
        let month = now.month ?? 6
        let day = now.day ?? 1
        let event: SubEvent
        switch parentScheduleKind {
        case .seasonal:
            event = SubEvent(
                name: "",
                seasonalWindow: SeasonalWindow(
                    startMonth: month, startDay: day,
                    endMonth: month, endDay: min(day + 7, 28)
                )
            )
        case .oneTime:
            event = SubEvent(name: "", dueDate: .now)
        default:
            return
        }
        subEvents.append(event)
    }
}

private struct SubEventRow: View {
    @Binding var event: SubEvent
    let parentScheduleKind: ScheduleKind
    let onDelete: (UUID) -> Void

    @State private var notesExpanded = false
    @FocusState private var notesFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Event name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", text: $event.name)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.leading)
            }
            HStack(spacing: 4) {
                Spacer()
                switch parentScheduleKind {
                case .seasonal:
                    seasonalEditor
                case .oneTime:
                    oneTimeEditor
                default:
                    EmptyView()
                }
                Button(role: .destructive) {
                    onDelete(event.id)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Remove this event")
                .padding(.leading, 8)
            }
            notesArea
        }
        .panelStyle(cornerRadius: 8, padding: 10)
        .onAppear {
            if parentScheduleKind == .seasonal && event.seasonalWindow == nil {
                event.seasonalWindow = SeasonalWindow(startMonth: 6, startDay: 1, endMonth: 6, endDay: 7)
            }
            if !event.notes.isEmpty { notesExpanded = true }
        }
    }

    @ViewBuilder
    private var notesArea: some View {
        if notesExpanded || !event.notes.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.caption2)
                    Text("Notes")
                        .font(.caption)
                    Spacer()
                    Text("Markdown supported")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(.secondary)
                TextEditor(text: $event.notes)
                    .font(.callout)
                    .focused($notesFocused)
                    .frame(height: notesFocused ? 240 : 56)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.upkeepPanel))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(
                                notesFocused
                                    ? AnyShapeStyle(Color.upkeepAmber.opacity(0.5))
                                    : AnyShapeStyle(Color(NSColor.separatorColor).opacity(0.25)),
                                lineWidth: notesFocused ? 1 : 0.5
                            )
                    )
                    .animation(.easeInOut(duration: 0.18), value: notesFocused)
            }
            .padding(.top, 2)
        } else {
            Button {
                notesExpanded = true
            } label: {
                Label("Add notes", systemImage: "note.text.badge.plus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private var seasonalEditor: some View {
        let window = event.seasonalWindow ?? SeasonalWindow(startMonth: 6, startDay: 1, endMonth: 6, endDay: 7)
        Text("Opens")
            .font(.caption)
            .foregroundStyle(.secondary)
        monthDayPickers(
            month: Binding(
                get: { window.startMonth },
                set: { event.seasonalWindow = updatedWindow(window, startMonth: $0) }
            ),
            day: Binding(
                get: { window.startDay },
                set: { event.seasonalWindow = updatedWindow(window, startDay: $0) }
            )
        )
        Rectangle()
            .fill(.secondary.opacity(0.5))
            .frame(width: 24, height: 1)
            .padding(.horizontal, 6)
        Text("Closes")
            .font(.caption)
            .foregroundStyle(.secondary)
        monthDayPickers(
            month: Binding(
                get: { window.endMonth },
                set: { event.seasonalWindow = updatedWindow(window, endMonth: $0) }
            ),
            day: Binding(
                get: { window.endDay },
                set: { event.seasonalWindow = updatedWindow(window, endDay: $0) }
            )
        )
    }

    @ViewBuilder
    private var oneTimeEditor: some View {
        Text("Due")
            .font(.caption)
            .foregroundStyle(.secondary)
        StepperDateField(selection: Binding(
            get: { event.dueDate ?? .now },
            set: { event.dueDate = $0 }
        ))
        CalendarPopoverButton(selection: Binding(
            get: { event.dueDate ?? .now },
            set: { event.dueDate = $0 }
        ))
    }

    @ViewBuilder
    private func monthDayPickers(month: Binding<Int>, day: Binding<Int>) -> some View {
        Picker("", selection: month) {
            ForEach(1...12, id: \.self) { m in
                Text(monthAbbrev(m)).tag(m)
            }
        }
        .labelsHidden()
        .frame(width: 64)
        TextField("", value: clampedDay(day), format: .number)
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .frame(width: 36)
        Stepper("", value: day, in: 1...31)
            .labelsHidden()
            .controlSize(.small)
            .fixedSize()
    }

    private func clampedDay(_ day: Binding<Int>) -> Binding<Int> {
        Binding(
            get: { day.wrappedValue },
            set: { day.wrappedValue = min(max($0, 1), 31) }
        )
    }

    private func monthAbbrev(_ month: Int) -> String {
        DateFormatter().shortMonthSymbols[month - 1]
    }

    private func updatedWindow(_ w: SeasonalWindow,
                               startMonth: Int? = nil, startDay: Int? = nil,
                               endMonth: Int? = nil, endDay: Int? = nil) -> SeasonalWindow {
        SeasonalWindow(
            startMonth: startMonth ?? w.startMonth,
            startDay: startDay ?? w.startDay,
            endMonth: endMonth ?? w.endMonth,
            endDay: endDay ?? w.endDay
        )
    }
}
