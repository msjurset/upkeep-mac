import SwiftUI

struct LogView: View {
    @Environment(UpkeepStore.self) private var store
    @Binding var showNewLogEntrySheet: Bool
    @State private var expandedLogEntryID: UUID?

    var body: some View {
        let grouped = groupedEntries

        VStack(spacing: 0) {
            HStack {
                Spacer()
                addButton { showNewLogEntrySheet = true }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

        ScrollViewReader { proxy in
            List {
                ForEach(grouped, id: \.key) { month, entries in
                    Section(month) {
                        ForEach(entries) { entry in
                            LogEntryRow(entry: entry, showItemName: true, expandedID: $expandedLogEntryID)
                                .id(entry.id)
                        }
                    }
                }
            }
            .onChange(of: expandedLogEntryID) { _, newID in
                if let newID {
                    withAnimation {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .overlay {
            if store.logEntries.isEmpty {
                EmptyListOverlay(
                    icon: "book",
                    title: "No log entries",
                    message: "Log maintenance work as you go — routine or one-off",
                    buttonLabel: "New Entry"
                ) { showNewLogEntrySheet = true }
            }
        }
        } // end VStack
    }

    private var groupedEntries: [(key: String, value: [LogEntry])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        let grouped = Dictionary(grouping: store.logEntries) { entry in
            formatter.string(from: entry.completedDate)
        }

        return grouped.sorted { a, b in
            let dateA = store.logEntries.first { formatter.string(from: $0.completedDate) == a.key }?.completedDate ?? .distantPast
            let dateB = store.logEntries.first { formatter.string(from: $0.completedDate) == b.key }?.completedDate ?? .distantPast
            return dateA > dateB
        }
    }
}

// MARK: - Log Entry Row (shared)

struct LogEntryRow: View {
    @Environment(UpkeepStore.self) private var store
    let entry: LogEntry
    var showItemName: Bool = true
    @Binding var expandedID: UUID?

    private var isExpanded: Bool { expandedID == entry.id }

    @State private var editTitle = ""
    @State private var editNotes = ""
    @State private var editCostString = ""
    @State private var editPerformedBy = ""
    @State private var editDate = Date.now
    @State private var editRating: Int = 0
    @State private var isEditing = false
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed row (always visible)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedID = isExpanded ? nil : entry.id
                }
                if !isExpanded {
                    isEditing = false
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: entry.category.icon)
                        .font(.body)
                        .foregroundStyle(Color.categoryColor(entry.category))
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.title)
                            .font(.body.weight(.medium))
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Text(entry.completedDate.shortDate)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if !entry.performedBy.isEmpty {
                                Text("~")
                                    .font(.caption)
                                    .foregroundStyle(.quaternary)
                                Text(entry.performedBy)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            if entry.isStandalone {
                                Text("standalone")
                                    .font(.system(size: 9, weight: .medium))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(.secondary.opacity(0.12))
                                    .foregroundStyle(.secondary)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Spacer()

                    RatingDisplay(rating: entry.rating)
                    CostText(cost: entry.cost)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded detail
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()
                        .padding(.vertical, 4)

                    if isEditing {
                        editView
                    } else {
                        detailView
                    }
                }
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onChange(of: expandedID) { _, newID in
            if newID == entry.id {
                populateEditFields()
            } else {
                isEditing = false
            }
        }
        .confirmationDialog("Delete this log entry?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                store.deleteLogEntry(id: entry.id)
                expandedID = nil
            }
        }
    }

    // MARK: - Detail View (read-only)

    private var detailView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !entry.notes.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(entry.notes)
                        .font(.callout)
                        .textSelection(.enabled)
                }
            }

            HStack(spacing: 16) {
                if let formatted = entry.costFormatted {
                    detailChip(icon: "dollarsign.circle", text: formatted)
                }
                if !entry.performedBy.isEmpty {
                    detailChip(icon: "person", text: entry.performedBy)
                }
                if let rating = entry.rating, rating > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.upkeepAmber)
                        Text("\(rating)/5")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Linked item
            if let itemID = entry.itemID, let item = store.items.first(where: { $0.id == itemID }) {
                Button {
                    store.navigation = .inventoryAll
                    store.selectedItemID = item.id
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.caption2)
                        Text(item.name)
                            .font(.caption)
                    }
                    .foregroundStyle(.upkeepAmber)
                }
                .buttonStyle(.plain)
            }

            // Actions
            HStack(spacing: 12) {
                Button {
                    populateEditFields()
                    isEditing = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.top, 4)
        }
        .padding(.leading, 34)
    }

    private func detailChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.upkeepAmber)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Edit View (inline)

    private var editView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Title")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)
                TextField("Title", text: $editTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
            }

            HStack {
                Text("Date")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)
                DatePicker("", selection: $editDate, displayedComponents: .date)
                    .labelsHidden()
            }

            HStack {
                Text("By")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)
                TextField("Performed by", text: $editPerformedBy)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Cost")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .leading)
                    TextField("Cost", text: $editCostString)
                        .textFieldStyle(.roundedBorder)
                        .font(.callout)
                        .frame(width: 100)
                }
                if !editCostString.isEmpty && Decimal(string: editCostString) == nil {
                    Text("Enter a valid number")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .padding(.leading, 74)
                }
            }

            HStack {
                Text("Rating")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)
                RatingPicker(rating: $editRating)
            }

            HStack {
                Text("Notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)
                TextField("Notes", text: $editNotes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
                    .lineLimit(1...4)
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") {
                    isEditing = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Save") {
                    saveEdit()
                }
                .buttonStyle(.borderedProminent)
                .tint(.upkeepAmber)
                .controlSize(.small)
                .disabled(editTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 4)
        }
        .padding(.leading, 34)
    }

    // MARK: - Helpers

    private func populateEditFields() {
        editTitle = entry.title
        editNotes = entry.notes
        editCostString = entry.cost.map { "\($0)" } ?? ""
        editPerformedBy = entry.performedBy
        editDate = entry.completedDate
        editRating = entry.rating ?? 0
    }

    private func saveEdit() {
        var updated = entry
        updated.title = editTitle.trimmingCharacters(in: .whitespaces)
        updated.notes = editNotes
        updated.cost = Decimal(string: editCostString)
        updated.performedBy = editPerformedBy
        updated.completedDate = editDate
        updated.rating = editRating > 0 ? editRating : nil
        store.updateLogEntry(updated)
        isEditing = false
    }
}
