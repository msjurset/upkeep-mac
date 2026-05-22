import SwiftUI

/// Read/edit details + log history for one sub-event of a maintenance item.
/// View-only by default; click the pen icon to flip into edit mode.
struct SubEventDetailSheet: View {
    @Environment(UpkeepStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let itemID: UUID
    let subEventID: UUID

    @State private var entryToEdit: LogEntry?
    @State private var showLogSheet = false

    @State private var isEditing = false
    @FocusState private var notesFocused: Bool
    @State private var editName = ""
    @State private var editNotes = ""
    @State private var editVendorID: UUID?
    @State private var editStartMonth = 6
    @State private var editStartDay = 1
    @State private var editEndMonth = 6
    @State private var editEndDay = 7
    @State private var editDueDate = Date.now

    private var item: MaintenanceItem? {
        store.items.first(where: { $0.id == itemID })
    }

    private var subEvent: SubEvent? {
        item?.subEvents.first(where: { $0.id == subEventID })
    }

    private var entries: [LogEntry] {
        store.logEntries(for: itemID).filter { $0.subEventID == subEventID }
    }

    private var dateLabel: String {
        guard let sub = subEvent else { return "—" }
        if let window = sub.seasonalWindow { return window.description }
        if let due = sub.dueDate { return due.shortDate }
        return "—"
    }

    private var sheetTitle: String {
        let raw = subEvent?.name.trimmingCharacters(in: .whitespaces) ?? ""
        return raw.isEmpty ? "Untitled event" : raw
    }

    var body: some View {
        EditorSheet(
            title: sheetTitle,
            saveLabel: isEditing ? "Save" : "Done",
            onSave: { if isEditing { commitEdits() } },
            toolbar: {
                Button {
                    if isEditing {
                        commitEdits()
                    } else {
                        beginEdit()
                    }
                } label: {
                    Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil")
                        .font(.body)
                        .foregroundStyle(isEditing ? Color.upkeepGreen : Color.upkeepAmber)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help(isEditing ? "Done editing" : "Edit sub-event")
            }
        ) {
            FormSection("Details") {
                if isEditing {
                    FormRow(label: "Name") {
                        TextField("", text: $editName)
                            .textFieldStyle(.roundedBorder)
                    }
                    if subEvent?.seasonalWindow != nil {
                        FormRow(label: "Window opens") {
                            monthDayRow(month: $editStartMonth, day: $editStartDay)
                        }
                        FormRow(label: "Window closes") {
                            monthDayRow(month: $editEndMonth, day: $editEndDay)
                        }
                    } else if subEvent?.dueDate != nil {
                        FormRow(label: "Due") {
                            HStack(spacing: 6) {
                                StepperDateField(selection: $editDueDate)
                                CalendarPopoverButton(selection: $editDueDate)
                            }
                        }
                    }
                    FormRow(label: "Vendor") {
                        Picker("", selection: $editVendorID) {
                            Text("Use parent's").tag(UUID?.none)
                            ForEach(store.vendors) { vendor in
                                Text(vendor.name).tag(UUID?.some(vendor.id))
                            }
                        }
                        .labelsHidden()
                    }
                } else {
                    FormRow(label: "Date") {
                        Text(dateLabel).font(.callout)
                    }
                    if let item, let sub = subEvent {
                        let isComplete = store.scheduling.isCompletedForCurrentPeriod(item: item, subEvent: sub)
                        FormRow(label: "Status") {
                            HStack(spacing: 6) {
                                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isComplete ? .upkeepGreen : .secondary)
                                Text(isComplete ? "Logged for current cycle" : "Not yet logged")
                                    .font(.callout)
                                    .foregroundStyle(isComplete ? .primary : .secondary)
                            }
                        }
                    }
                    if let vendorID = subEvent?.vendorID,
                       let vendor = store.vendors.first(where: { $0.id == vendorID }) {
                        FormRow(label: "Vendor") {
                            Text(vendor.name).font(.callout)
                        }
                    }
                }
            }

            if isEditing || (subEvent?.notes.isEmpty == false) {
                FormSection("Notes") {
                    if isEditing {
                        TextEditor(text: $editNotes)
                            .font(.callout)
                            .focused($notesFocused)
                            .frame(height: notesFocused ? 300 : 72)
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
                        Text("Markdown supported")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else {
                        MarkdownNotesView(text: subEvent?.notes ?? "")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            FormSection("Maintenance log") {
                if entries.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "book")
                                .font(.title3)
                                .foregroundStyle(.upkeepAmber.opacity(0.4))
                            Text("No entries yet")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 12)
                        Spacer()
                    }
                } else {
                    ForEach(entries) { entry in
                        Button {
                            entryToEdit = entry
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.upkeepGreen)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title.isEmpty ? "(no title)" : entry.title)
                                        .font(.callout)
                                    HStack(spacing: 6) {
                                        Text(entry.completedDate.shortDate)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if !entry.performedBy.isEmpty {
                                            Text("·")
                                                .foregroundStyle(.tertiary)
                                            Text(entry.performedBy)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        if let formatted = entry.costFormatted {
                                            Text("·")
                                                .foregroundStyle(.tertiary)
                                            Text(formatted)
                                                .font(.caption.monospacedDigit())
                                                .foregroundStyle(.upkeepAmber)
                                        }
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button {
                    showLogSheet = true
                } label: {
                    Label("Log completion", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
            }
        }
        .frame(width: 520, height: 560)
        .sheet(isPresented: $showLogSheet) {
            LogEntrySheet(entry: nil, itemID: itemID, subEventID: subEventID)
        }
        .sheet(item: $entryToEdit) { entry in
            LogEntrySheet(entry: entry, itemID: itemID, subEventID: subEventID)
        }
    }

    private func beginEdit() {
        guard let sub = subEvent else { return }
        editName = sub.name
        editNotes = sub.notes
        editVendorID = sub.vendorID
        if let window = sub.seasonalWindow {
            editStartMonth = window.startMonth
            editStartDay = window.startDay
            editEndMonth = window.endMonth
            editEndDay = window.endDay
        }
        if let due = sub.dueDate {
            editDueDate = due
        }
        isEditing = true
    }

    private func commitEdits() {
        guard var updated = item,
              let idx = updated.subEvents.firstIndex(where: { $0.id == subEventID })
        else {
            isEditing = false
            return
        }
        updated.subEvents[idx].name = editName.trimmingCharacters(in: .whitespaces)
        updated.subEvents[idx].notes = editNotes
        updated.subEvents[idx].vendorID = editVendorID
        if updated.subEvents[idx].seasonalWindow != nil {
            updated.subEvents[idx].seasonalWindow = SeasonalWindow(
                startMonth: editStartMonth, startDay: editStartDay,
                endMonth: editEndMonth, endDay: editEndDay
            )
        }
        if updated.subEvents[idx].dueDate != nil {
            updated.subEvents[idx].dueDate = editDueDate
        }
        updated.subEvents[idx].touch()
        store.updateItem(updated, actionName: "Edit Sub-event")
        isEditing = false
    }

    @ViewBuilder
    private func monthDayRow(month: Binding<Int>, day: Binding<Int>) -> some View {
        HStack(spacing: 4) {
            Picker("", selection: month) {
                ForEach(1...12, id: \.self) { m in
                    Text(monthName(m)).tag(m)
                }
            }
            .labelsHidden()
            .frame(width: 100)
            TextField("", value: Binding(
                get: { day.wrappedValue },
                set: { day.wrappedValue = min(max($0, 1), 31) }
            ), format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 36)
            Stepper("", value: day, in: 1...31)
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
        }
    }

    private func monthName(_ month: Int) -> String {
        DateFormatter().monthSymbols[month - 1]
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
