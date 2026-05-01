import SwiftUI

struct ItemDetailView: View {
    @Environment(UpkeepStore.self) private var store
    let item: MaintenanceItem
    @State private var showEditSheet = false
    @State private var showLogSheet = false
    @State private var showDeleteConfirm = false
    @State private var deleteAssociatedLogs = false
    @State private var showSnoozePopover = false
    @State private var isAddingTag = false
    @State private var newTagText = ""
    @State private var showAddFollowUp = false
    @State private var followUpTitle = ""
    @State private var followUpHasDate = false
    @State private var followUpDate = Date.now
    @State private var localStock: Int?
    @State private var stockDebounce: Task<Void, Never>?

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

                // Active sourcing (banner)
                let activeSourcings = store.sourcings(forItem: item.id).filter(\.isOpen)
                if !activeSourcings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(activeSourcings) { sourcing in
                            Button {
                                store.recordHistory()
                                store.navigation = .vendors
                                store.vendorsTab = .sourcings
                                store.selectedSourcingID = sourcing.id
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.upkeepAmber)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Active sourcing")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(sourcing.title)
                                            .font(.body.weight(.medium))
                                    }
                                    Spacer()
                                    Text("\(sourcing.candidates.count) candidate\(sourcing.candidates.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 8).fill(.upkeepAmber.opacity(0.08)))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.upkeepAmber.opacity(0.4)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                    Divider()
                }

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

                // Attachments
                AttachmentsSection(
                    attachments: item.attachments,
                    onAdd: { store.addAttachmentToItem(itemID: item.id, $0) },
                    onRemove: { store.removeAttachmentFromItem(itemID: item.id, attachmentID: $0) }
                )
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

                if item.isSeasonal {
                    Button {
                        store.skipYear(id: item.id)
                    } label: {
                        Label("Skip This Year", systemImage: "forward")
                    }
                    .help("Skip this seasonal task for the current year")
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
        .sheet(isPresented: $showDeleteConfirm) {
            DeleteItemConfirmation(item: item, deleteLogs: $deleteAssociatedLogs)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: item.effectiveIcon)
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
                switch item.scheduleKind {
                case .idea:
                    scheduleCard(title: "Type", value: "Idea", icon: "lightbulb", tint: .yellow)
                    scheduleCard(title: "Last Updated", value: item.updatedAt.shortDate, icon: "arrow.clockwise")
                case .seasonal:
                    if let window = item.seasonalWindow {
                        scheduleCard(title: "Window", value: window.description, icon: "leaf")

                        let status = store.scheduling.seasonalStatus(for: item, window: window)
                        switch status {
                        case .upcoming(let days):
                            scheduleCard(title: "Opens In", value: "\(days) days", icon: "calendar", tint: .upkeepAmber)
                        case .inWindow:
                            scheduleCard(title: "Status", value: "In window — do it now", icon: "exclamationmark.circle", tint: .upkeepGreen)
                        case .overdue:
                            scheduleCard(title: "Status", value: "Window passed", icon: "exclamationmark.circle", tint: .upkeepRed)
                        case .doneForYear:
                            scheduleCard(title: "Status", value: "Done for this year", icon: "checkmark.circle", tint: .upkeepGreen)
                        case .skippedForYear:
                            scheduleCard(title: "Status", value: "Skipped this year", icon: "forward.circle", tint: .secondary)
                        }
                    }
                case .oneTime:
                    scheduleCard(title: "Do By", value: item.startDate.shortDate, icon: "calendar")
                    let last = store.lastCompletion(for: item.id)
                    if last != nil {
                        scheduleCard(title: "Status", value: "Completed", icon: "checkmark.circle", tint: .upkeepGreen)
                    } else {
                        let days = store.daysUntilDue(item)
                        scheduleCard(
                            title: days < 0 ? "Overdue" : "Due",
                            value: dueDateText(days),
                            icon: days < 0 ? "exclamationmark.circle" : "calendar",
                            tint: Color.dueDateColor(days)
                        )
                    }
                case .recurring:
                    scheduleCard(title: "Frequency", value: item.frequencyDescription, icon: "arrow.clockwise")

                    let days = store.daysUntilDue(item)
                    scheduleCard(
                        title: days < 0 ? "Overdue" : "Next Due",
                        value: dueDateText(days),
                        icon: days < 0 ? "exclamationmark.circle" : "calendar",
                        tint: Color.dueDateColor(days)
                    )
                }

                if item.scheduleKind != .idea {
                    if let last = store.lastCompletion(for: item.id) {
                        scheduleCard(
                            title: "Last Done",
                            value: last.completedDate.shortDate,
                            icon: "checkmark.circle"
                        )
                    } else if !item.isOneTime {
                        scheduleCard(
                            title: "Tracking Since",
                            value: item.startDate.shortDate,
                            icon: "calendar.badge.clock"
                        )
                    }
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
        DueDateText.relative(days: days)
    }

    // MARK: - Vendor

    private func vendorSection(_ vendor: Vendor) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vendor")
                .font(.headline)
                .foregroundStyle(.secondary)

            Button {
                store.recordHistory()
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
                    Stepper("\(localStock ?? supply.stockOnHand)", value: Binding(
                        get: { localStock ?? supply.stockOnHand },
                        set: { newValue in
                            localStock = newValue
                            stockDebounce?.cancel()
                            stockDebounce = Task {
                                try? await Task.sleep(for: .milliseconds(500))
                                guard !Task.isCancelled else { return }
                                store.updateSupply(itemID: item.id, stockOnHand: newValue)
                                localStock = nil
                            }
                        }
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
                            LabeledContent("Due") {
                                HStack(spacing: 6) {
                                    StepperDateField(selection: $followUpDate)
                                    CalendarPopoverButton(selection: $followUpDate)
                                }
                            }
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
                                Text(dueDate.shortDate)
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
            MarkdownNotesView(text: item.notes)
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
                VStack(spacing: 8) {
                    ForEach(entries) { entry in
                        Button {
                            store.recordHistory()
                            store.navigation = .log
                            store.selectedLogEntryID = entry.id
                        } label: {
                            historyEntryCard(entry)
                        }
                        .buttonStyle(.plain)
                        .pointerCursor()
                    }
                }
            }
        }
    }

    private func historyEntryCard(_ entry: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: entry.category.icon)
                    .font(.body)
                    .foregroundStyle(Color.categoryColor(entry.category))
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(entry.completedDate.shortDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !entry.performedBy.isEmpty {
                            Text("~").font(.caption).foregroundStyle(.quaternary)
                            Text(entry.performedBy)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if !entry.attachments.isEmpty {
                            HStack(spacing: 2) {
                                Image(systemName: "paperclip")
                                Text("\(entry.attachments.count)")
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                RatingDisplay(rating: entry.rating)
                CostText(cost: entry.cost)
            }

            if !entry.notes.trimmingCharacters(in: .whitespaces).isEmpty {
                MarkdownNotesView(text: entry.notes)
                    .padding(.leading, 32)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.background))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator.opacity(0.3)))
    }
}

// MARK: - Delete Confirmation

private struct DeleteItemConfirmation: View {
    @Environment(UpkeepStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let item: MaintenanceItem
    @Binding var deleteLogs: Bool

    private var logCount: Int {
        store.logEntries(for: item.id).count
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash")
                .font(.largeTitle)
                .foregroundStyle(.red)

            Text("Delete \"\(item.name)\"?")
                .font(.headline)

            Text("This will permanently remove this item and cannot be undone.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if logCount > 0 {
                Toggle(isOn: $deleteLogs) {
                    Text("Also delete \(logCount) associated log \(logCount == 1 ? "entry" : "entries")")
                        .font(.callout)
                }
                .toggleStyle(.checkbox)
                .padding(.top, 4)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    deleteLogs = false
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Delete", role: .destructive) {
                    store.deleteItem(id: item.id, deleteLogs: deleteLogs)
                    store.selectedItemID = nil
                    deleteLogs = false
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 340)
    }
}
