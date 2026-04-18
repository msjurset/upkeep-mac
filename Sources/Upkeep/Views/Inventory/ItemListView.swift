import SwiftUI

struct ItemListView: View {
    @Environment(UpkeepStore.self) private var store
    let items: [MaintenanceItem]
    let title: String
    @Binding var showNewItemSheet: Bool

    @FocusState private var searchFocused: Bool
    @State private var bulkSelection: Set<UUID> = []

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search items... (tag: to filter)", text: $store.searchQuery)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onSubmit { /* already filters live */ }
                if !store.searchQuery.isEmpty {
                    Button {
                        store.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.bar)

            Divider()

            HStack(spacing: 10) {
                Spacer()
                Button {
                    store.cycleSortMode()
                } label: {
                    HStack(spacing: 3) {
                        Text(store.sortMode.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Image(systemName: store.sortMode.icon)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .help("Sort: \(store.sortMode.rawValue) — click to cycle")

                addButton { showNewItemSheet = true }
                    .help("New item")
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 0)

            List(selection: $bulkSelection) {
                ForEach(items) { item in
                    ItemRow(item: item)
                        .tag(item.id)
                        .contextMenu {
                            Button("Log Completion") {
                                store.logCompletion(
                                    itemID: item.id, title: item.name,
                                    category: item.category, performedBy: "Self"
                                )
                            }
                            Button("Snooze 7 Days") {
                                store.snoozeItem(id: item.id, days: 7)
                            }
                            if item.isSeasonal {
                                Button("Skip This Year") {
                                    store.skipYear(id: item.id)
                                }
                            }
                            Button(item.isActive ? "Deactivate" : "Activate") {
                                var updated = item
                                updated.isActive.toggle()
                                store.updateItem(updated, actionName: item.isActive ? "Deactivate" : "Activate")
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                store.deleteItem(id: item.id)
                            }
                        }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .onChange(of: bulkSelection) {
                // Single selection → navigate to detail
                if bulkSelection.count == 1 {
                    store.selectedItemID = bulkSelection.first
                }
            }

            // Bulk action bar — appears when 2+ items selected
            if bulkSelection.count > 1 {
                Divider()
                HStack(spacing: 12) {
                    Text("\(bulkSelection.count) selected")
                        .font(.callout.weight(.medium))

                    Spacer()

                    Button("Snooze 7d") {
                        for id in bulkSelection {
                            store.snoozeItem(id: id, days: 7)
                        }
                        bulkSelection.removeAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Deactivate") {
                        for id in bulkSelection {
                            if var item = store.items.first(where: { $0.id == id }) {
                                item.isActive = false
                                store.updateItem(item, actionName: "Deactivate")
                            }
                        }
                        bulkSelection.removeAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Delete", role: .destructive) {
                        for id in bulkSelection {
                            store.deleteItem(id: id)
                        }
                        bulkSelection.removeAll()
                    }
                    .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.bar)
            }
        }
        .overlay {
            if items.isEmpty {
                EmptyListOverlay(
                    icon: "wrench.and.screwdriver",
                    title: "No items",
                    message: "Add maintenance items to track your home's needs",
                    buttonLabel: "Add Item"
                ) { showNewItemSheet = true }
            }
        }
        .navigationTitle(title)
    }
}

// MARK: - Item Row

struct ItemRow: View {
    @Environment(UpkeepStore.self) private var store
    let item: MaintenanceItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.category.icon)
                .font(.title3)
                .foregroundStyle(Color.categoryColor(item.category))
                .frame(width: 28)
                .help(item.category.label)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(item.frequencyDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let vendor = store.vendor(for: item) {
                        Text("~")
                            .font(.caption)
                            .foregroundStyle(.quaternary)
                        Text(vendor.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            KindBadge(kind: item.scheduleKind)
                .frame(width: 20)

            HStack(spacing: 6) {
                if let supply = item.supply, supply.needsReorder {
                    SupplyBadge(supply: supply)
                }

                PriorityBadge(priority: item.priority)
                    .frame(width: 14)

                let days = store.daysUntilDue(item)
                DueDateBadge(daysUntilDue: days)
                    .frame(width: 100, alignment: .trailing)
                    .help("Due \(store.nextDueDate(for: item).shortDate)")
            }
        }
        .padding(.vertical, 2)
    }
}
