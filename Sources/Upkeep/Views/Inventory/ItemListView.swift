import SwiftUI

struct ItemListView: View {
    @Environment(UpkeepStore.self) private var store
    let items: [MaintenanceItem]
    let title: String
    @Binding var showNewItemSheet: Bool

    @State private var bulkSelection: Set<UUID> = []
    @State private var tagMatches: [String] = []
    @State private var tagActiveIndex: Int = -1
    @State private var tagJustAccepted = false
    @State private var isNavigating = false

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TagAwareSearchField(
                    query: $store.searchQuery,
                    placeholder: "Search items... (tag: to filter)",
                    hasSuggestions: { !tagMatches.isEmpty },
                    onNavigate: { navigate($0) },
                    onAccept: { handleEnter() }
                )
                if !store.searchQuery.isEmpty {
                    Button {
                        store.searchQuery = ""
                        tagMatches = []
                        tagActiveIndex = -1
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

            // Tag suggestions dropdown
            if !tagMatches.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(tagMatches.enumerated()), id: \.element) { idx, tag in
                        Button {
                            completeTag(tag)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "tag")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("tag:\(tag)")
                                    .font(.callout)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(idx == tagActiveIndex ? Color.accentColor.opacity(0.2) : .clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                .background(.bar)
            }

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
        .background(TagSuggestionMonitor(
            hasSuggestions: { !tagMatches.isEmpty },
            onNavigate: { navigate($0) }
        ))
        .onChange(of: store.searchQuery) { _, _ in
            if isNavigating { isNavigating = false; return }
            tagJustAccepted = false
            updateTagSuggestions()
        }
        .navigationTitle(title)
    }

    // MARK: - Tag Suggestions

    private func updateTagSuggestions() {
        tagActiveIndex = -1
        let query = store.searchQuery
        guard let match = query.range(of: #"(?:^|\s)tag:(\S*)$"#, options: .regularExpression) else {
            tagMatches = []
            return
        }
        let token = query[match]
        guard let colonIdx = token.firstIndex(of: ":") else {
            tagMatches = []
            return
        }
        let partial = String(token[token.index(after: colonIdx)...]).lowercased()
        let existing = Set(query.matches(of: /tag:(\S+)/).compactMap { String($0.output.1).lowercased() })

        tagMatches = store.allTags
            .filter { tag in
                let lower = tag.lowercased()
                return (partial.isEmpty || lower.contains(partial)) && !existing.contains(lower)
            }
            .prefix(8)
            .map { $0 }
    }

    private func navigate(_ direction: TagNavDirection) {
        guard !tagMatches.isEmpty else { return }
        switch direction {
        case .down:
            tagActiveIndex = tagActiveIndex < 0 ? 0 : min(tagActiveIndex + 1, tagMatches.count - 1)
            previewTag(tagMatches[tagActiveIndex])
        case .up:
            tagActiveIndex = max(tagActiveIndex - 1, 0)
            previewTag(tagMatches[tagActiveIndex])
        case .escape:
            tagMatches = []
            tagActiveIndex = -1
        }
    }

    private func handleEnter() {
        if !tagMatches.isEmpty {
            let idx = tagActiveIndex >= 0 ? tagActiveIndex : 0
            if idx < tagMatches.count { completeTag(tagMatches[idx]) }
            tagJustAccepted = true
            return
        }
        // Second Enter (no suggestions) — nothing to submit; live filter is already applied.
        tagJustAccepted = false
    }

    private func previewTag(_ name: String) {
        let query = store.searchQuery
        guard let range = query.range(of: #"(?:^|\s)tag:\S*$"#, options: .regularExpression) else { return }
        let before = query[query.startIndex..<range.lowerBound]
        let prefix = query[range].hasPrefix(" ") ? " " : ""
        isNavigating = true
        store.searchQuery = "\(before)\(prefix)tag:\(name)"
    }

    private func completeTag(_ name: String) {
        let query = store.searchQuery
        guard let range = query.range(of: #"(?:^|\s)tag:\S*$"#, options: .regularExpression) else { return }
        let before = query[query.startIndex..<range.lowerBound]
        let prefix = query[range].hasPrefix(" ") ? " " : ""
        store.searchQuery = "\(before)\(prefix)tag:\(name) "
        tagMatches = []
        tagActiveIndex = -1
    }
}

// MARK: - Item Row

struct ItemRow: View {
    @Environment(UpkeepStore.self) private var store
    let item: MaintenanceItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.effectiveIcon)
                .font(.title3)
                .foregroundStyle(Color.categoryColor(item.category))
                .frame(width: 28)
                .help(item.category.label)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.body.weight(.medium))
                        .strikethrough(!item.isActive)
                        .lineLimit(1)
                    if !item.isActive {
                        Text("Archived")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

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

                if item.isIdea {
                    // Ideas have no due date — keep column width consistent so kind icons still align.
                    Color.clear.frame(width: 100, height: 1)
                } else {
                    let days = store.daysUntilDue(item)
                    DueDateBadge(daysUntilDue: days)
                        .frame(width: 100, alignment: .trailing)
                        .help("Due \(store.nextDueDate(for: item).shortDate)")
                }
            }
        }
        .padding(.vertical, 2)
        .opacity(item.isActive ? 1.0 : 0.55)
    }
}
