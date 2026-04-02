import SwiftUI

struct ItemDetailView: View {
    @Environment(UpkeepStore.self) private var store
    let item: MaintenanceItem
    @State private var showEditSheet = false
    @State private var showLogSheet = false
    @State private var showDeleteConfirm = false
    @State private var showSnoozePopover = false
    @State private var isAddingTag = false
    @State private var newTagText = ""
    @State private var showAddFollowUp = false
    @State private var expandedLogEntryID: UUID?
    @State private var followUpTitle = ""
    @State private var followUpHasDate = false
    @State private var followUpDate = Date.now

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                header
                    .padding(20)

                Divider()

                // Schedule info
                scheduleSection
                    .padding(20)

                Divider()

                // Vendor
                if let vendor = store.vendor(for: item) {
                    vendorSection(vendor)
                        .padding(20)
                    Divider()
                }

                // Supply tracking
                if item.supply != nil {
                    supplySection
                        .padding(20)
                    Divider()
                }

                // Follow-ups
                followUpsSection
                    .padding(20)
                Divider()

                // Notes
                if !item.notes.isEmpty {
                    notesSection
                        .padding(20)
                    Divider()
                }

                // Completion history
                historySection
                    .padding(20)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showLogSheet = true
                } label: {
                    Label("Log Completion", systemImage: "checkmark.circle")
                }
                .help("Log maintenance completion")

                Button {
                    showSnoozePopover = true
                } label: {
                    Label("Snooze", systemImage: "clock.badge.questionmark")
                }
                .help("Snooze — defer this item")
                .popover(isPresented: $showSnoozePopover) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Snooze for...")
                            .font(.headline)
                        ForEach([7, 14, 30], id: \.self) { days in
                            Button("\(days) days") {
                                store.snoozeItem(id: item.id, days: days)
                                showSnoozePopover = false
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(12)
                }

                Button {
                    showEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .help("Edit item")

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .help("Delete item")
            }
        }
        .sheet(isPresented: $showEditSheet) {
            ItemEditorSheet(item: item)
        }
        .sheet(isPresented: $showLogSheet) {
            LogEntrySheet(entry: nil, itemID: item.id)
        }
        .confirmationDialog("Delete \"\(item.name)\"?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                store.deleteItem(id: item.id)
                store.selectedItemID = nil
            }
        } message: {
            Text("This will permanently remove this item and cannot be undone.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: item.category.icon)
                    .font(.title)
                    .foregroundStyle(Color.categoryColor(item.category))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.title2.weight(.semibold))

                    HStack(spacing: 8) {
                        CategoryBadge(category: item.category)
                        PriorityBadge(priority: item.priority)
                        Text(item.priority.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if item.isSnoozed {
                            Text("Snoozed")
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.15))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }

                        if !item.isActive {
                            Text("Paused")
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.secondary.opacity(0.15))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                        }

                        let streak = store.currentStreak(for: item.id)
                        if streak >= 2 {
                            HStack(spacing: 3) {
                                Image(systemName: "flame.fill")
                                    .font(.caption2)
                                Text("\(streak)")
                                    .font(.caption2.weight(.bold))
                            }
                            .foregroundStyle(.upkeepAmber)
                            .help("\(streak) consecutive on-time completions")
                        }
                    }
                }
            }

            // Tags
            if !item.tags.isEmpty || isAddingTag {
                InlineTagEditor(
                    tags: item.tags,
                    isAddingTag: $isAddingTag,
                    newTagText: $newTagText,
                    onAdd: { tag in store.addTag(tag, to: item.id) },
                    onRemove: { tag in store.removeTag(tag, from: item.id) },
                    onTap: { tag in store.navigateToTag(tag) }
                )
                .padding(.top, 6)
            } else {
                Button {
                    isAddingTag = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "tag")
                            .font(.caption2)
                        Text("Add tags")
                            .font(.caption2)
                    }
                    .foregroundStyle(.upkeepAmber)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schedule")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                scheduleCard(title: "Frequency", value: item.frequencyDescription, icon: "arrow.clockwise")

                let days = store.daysUntilDue(item)
                scheduleCard(
                    title: days < 0 ? "Overdue" : "Next Due",
                    value: dueDateText(days),
                    icon: days < 0 ? "exclamationmark.circle" : "calendar",
                    tint: Color.dueDateColor(days)
                )

                if let last = store.lastCompletion(for: item.id) {
                    scheduleCard(
                        title: "Last Done",
                        value: last.completedDate.formatted(date: .abbreviated, time: .omitted),
                        icon: "checkmark.circle"
                    )
                } else {
                    scheduleCard(
                        title: "Tracking Since",
                        value: item.startDate.formatted(date: .abbreviated, time: .omitted),
                        icon: "calendar.badge.clock"
                    )
                }
            }
        }
    }

    private func scheduleCard(title: String, value: String, icon: String, tint: Color = .upkeepAmber) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.body.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func dueDateText(_ days: Int) -> String {
        switch days {
        case ..<0: return "\(abs(days)) days overdue"
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "In \(days) days"
        }
    }

    // MARK: - Vendor

    private func vendorSection(_ vendor: Vendor) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vendor")
                .font(.headline)
                .foregroundStyle(.secondary)

            Button {
                store.navigation = .vendors
                store.selectedVendorID = vendor.id
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.upkeepAmber)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vendor.name)
                            .font(.body.weight(.medium))
                        if !vendor.specialty.isEmpty {
                            Text(vendor.specialty)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(.background))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator.opacity(0.3)))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Supply

    @ViewBuilder
    private var supplySection: some View {
        if let supply = item.supply {
            VStack(alignment: .leading, spacing: 12) {
                Text("Supply")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 20) {
                    // Stock status
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "shippingbox")
                                .font(.caption)
                                .foregroundStyle(supplyTint(supply))
                            Text("In Stock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(supply.stockOnHand)")
                                .font(.title2.weight(.bold).monospacedDigit())
                                .foregroundStyle(supplyTint(supply))
                            Text("(\(supply.quantityPerUse) per use)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()

                    // Uses remaining
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                                .foregroundStyle(supplyTint(supply))
                            Text("Uses Left")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(supply.usesRemaining)")
                            .font(.title2.weight(.bold).monospacedDigit())
                            .foregroundStyle(supplyTint(supply))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()

                    // Unit cost
                    if let costStr = supply.unitCostFormatted {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "dollarsign.circle")
                                    .font(.caption)
                                    .foregroundStyle(.upkeepAmber)
                                Text("Unit Cost")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(costStr)
                                .font(.title2.weight(.bold).monospacedDigit())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                    }
                }

                // Reorder warning
                if supply.needsReorder {
                    HStack(spacing: 8) {
                        Image(systemName: supply.isOutOfStock ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(supply.isOutOfStock ? .upkeepRed : .orange)
                        Text(supply.isOutOfStock ? "Out of stock — reorder now" : "Low stock — time to reorder")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(supply.isOutOfStock ? .upkeepRed : .orange)
                        Spacer()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill((supply.isOutOfStock ? Color.upkeepRed : .orange).opacity(0.1))
                    )
                }

                // Product info
                if !supply.productName.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "cart")
                            .font(.caption)
                            .foregroundStyle(.upkeepAmber)
                        Text(supply.productName)
                            .font(.body)
                            .textSelection(.enabled)
                        Spacer()
                        if !supply.productURL.isEmpty {
                            Link(destination: URL(string: supply.productURL) ?? URL(string: "https://amazon.com")!) {
                                HStack(spacing: 4) {
                                    Text("Order")
                                        .font(.caption.weight(.medium))
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption2)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.background))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator.opacity(0.3)))
                }

                // Quick stock adjustment
                HStack {
                    Text("Adjust stock:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Stepper("\(supply.stockOnHand)", value: Binding(
                        get: { supply.stockOnHand },
                        set: { store.updateSupply(itemID: item.id, stockOnHand: $0) }
                    ), in: 0...999)
                    .frame(width: 120)
                }
            }
        }
    }

    private func supplyTint(_ supply: Supply) -> Color {
        if supply.isOutOfStock { return .upkeepRed }
        if supply.needsReorder { return .orange }
        return .upkeepGreen
    }

    // MARK: - Follow-Ups

    private var followUpsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Follow-Ups")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showAddFollowUp = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .popover(isPresented: $showAddFollowUp) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("New Follow-Up")
                            .font(.headline)
                        TextField("What needs to happen?", text: $followUpTitle)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 250)
                        Toggle("Set due date", isOn: $followUpHasDate)
                        if followUpHasDate {
                            DatePicker("Due", selection: $followUpDate, displayedComponents: .date)
                        }
                        HStack {
                            Spacer()
                            Button("Add") {
                                let trimmed = followUpTitle.trimmingCharacters(in: .whitespaces)
                                guard !trimmed.isEmpty else { return }
                                store.addFollowUp(to: item.id, title: trimmed, dueDate: followUpHasDate ? followUpDate : nil)
                                followUpTitle = ""
                                followUpHasDate = false
                                showAddFollowUp = false
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.upkeepAmber)
                            .disabled(followUpTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .padding(12)
                }
            }

            if item.followUps.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("No follow-ups")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 8)
                    Spacer()
                }
            } else {
                ForEach(item.followUps) { followUp in
                    HStack(spacing: 8) {
                        Button {
                            store.toggleFollowUp(itemID: item.id, followUpID: followUp.id)
                        } label: {
                            Image(systemName: followUp.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.body)
                                .foregroundStyle(followUp.isDone ? .upkeepGreen : followUp.isOverdue ? .upkeepRed : .secondary)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(followUp.title)
                                .font(.body)
                                .strikethrough(followUp.isDone)
                                .foregroundStyle(followUp.isDone ? .secondary : .primary)

                            if let dueDate = followUp.dueDate {
                                Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(followUp.isOverdue ? .upkeepRed : .secondary)
                            }
                        }

                        Spacer()

                        Button {
                            store.removeFollowUp(itemID: item.id, followUpID: followUp.id)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(item.notes)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Maintenance Log")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Log Completion") {
                    showLogSheet = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            let entries = store.logEntries(for: item.id)
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
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                ForEach(entries) { entry in
                    LogEntryRow(entry: entry, showItemName: false, expandedID: $expandedLogEntryID)
                }
            }
        }
    }
}
