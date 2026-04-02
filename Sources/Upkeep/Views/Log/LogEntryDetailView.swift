import SwiftUI

struct LogEntryDetailView: View {
    @Environment(UpkeepStore.self) private var store
    let entry: LogEntry
    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: entry.category.icon)
                            .font(.title)
                            .foregroundStyle(Color.categoryColor(entry.category))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .font(.title2.weight(.semibold))

                            HStack(spacing: 8) {
                                CategoryBadge(category: entry.category)
                                if entry.isStandalone {
                                    Text("Standalone entry")
                                        .font(.caption2.weight(.medium))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.secondary.opacity(0.12))
                                        .foregroundStyle(.secondary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                .padding(20)

                Divider()

                // Details
                VStack(alignment: .leading, spacing: 16) {
                    detailRow(icon: "calendar", title: "Date", value: entry.completedDate.formatted(date: .long, time: .omitted))

                    if !entry.performedBy.isEmpty {
                        detailRow(icon: "person", title: "Performed by", value: entry.performedBy)
                    }

                    if let rating = entry.rating, rating > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.upkeepAmber)
                                .frame(width: 16)
                            Text("Satisfaction")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            RatingDisplay(rating: entry.rating)
                        }
                    }

                    if entry.cost != nil, let formatted = entry.costFormatted {
                        detailRow(icon: "dollarsign.circle", title: "Cost", value: formatted)
                    }

                    // Linked item
                    if let itemID = entry.itemID, let item = store.items.first(where: { $0.id == itemID }) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "link")
                                    .font(.caption)
                                    .foregroundStyle(.upkeepAmber)
                                Text("Linked Item")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Button {
                                store.navigation = .inventoryAll
                                store.selectedItemID = item.id
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: item.category.icon)
                                        .foregroundStyle(Color.categoryColor(item.category))
                                    Text(item.name)
                                        .font(.body.weight(.medium))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(.background))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator.opacity(0.3)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)

                // Notes
                if !entry.notes.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text(entry.notes)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                    .padding(20)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            LogEntrySheet(entry: entry, itemID: entry.itemID)
        }
        .confirmationDialog("Delete this log entry?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                store.deleteLogEntry(id: entry.id)
                store.selectedLogEntryID = nil
            }
        }
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.upkeepAmber)
                .frame(width: 16)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body)
        }
    }
}
