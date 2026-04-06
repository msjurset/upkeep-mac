import SwiftUI

struct ItemListView: View {
    @Environment(UpkeepStore.self) private var store
    let items: [MaintenanceItem]
    let title: String
    @Binding var showNewItemSheet: Bool

    @FocusState private var searchFocused: Bool

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

            HStack {
                Spacer()
                addButton { showNewItemSheet = true }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            List(selection: $store.selectedItemID) {
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
                            Divider()
                            Button("Delete", role: .destructive) {
                                store.deleteItem(id: item.id)
                            }
                        }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
        .overlay {
            if items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.upkeepAmber.opacity(0.5))
                    Text("No items")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Add maintenance items to track your home's needs")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Button("Add Item") {
                        showNewItemSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.upkeepAmber)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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

            if let supply = item.supply, supply.needsReorder {
                SupplyBadge(supply: supply)
            }

            PriorityBadge(priority: item.priority)

            let days = store.daysUntilDue(item)
            DueDateBadge(daysUntilDue: days)
        }
        .padding(.vertical, 2)
    }
}
