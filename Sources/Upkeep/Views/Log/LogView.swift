import SwiftUI

struct LogView: View {
    @Environment(UpkeepStore.self) private var store
    @Binding var showNewLogEntrySheet: Bool

    var body: some View {
        @Bindable var store = store
        let grouped = groupedEntries

        VStack(spacing: 0) {
            HStack {
                Spacer()
                addButton { showNewLogEntrySheet = true }
                    .help("New log entry")
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 0)

            List(selection: $store.selectedLogEntryID) {
                ForEach(grouped, id: \.key) { month, entries in
                    Section(month) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            LogEntryRow(entry: entry, showItemName: true)
                                .tag(entry.id)
                                .listRowBackground(index.isMultiple(of: 2) ? Color.clear : Color.alternatingRow)
                                .listRowSeparator(.hidden)
                        }
                    }
                }
            }
            .listStyle(.inset)
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
        }
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

// MARK: - Log Entry Row (display-only)

struct LogEntryRow: View {
    @Environment(UpkeepStore.self) private var store
    let entry: LogEntry
    var showItemName: Bool = true

    var body: some View {
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

                    if !entry.attachments.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "paperclip")
                                .font(.caption2)
                            Text("\(entry.attachments.count)")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            RatingDisplay(rating: entry.rating)
            CostText(cost: entry.cost)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
