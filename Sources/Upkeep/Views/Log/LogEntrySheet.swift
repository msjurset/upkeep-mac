import SwiftUI

struct LogEntrySheet: View {
    @Environment(UpkeepStore.self) private var store

    let entry: LogEntry?
    let itemID: UUID?
    let subEventID: UUID?

    init(entry: LogEntry? = nil, itemID: UUID? = nil, subEventID: UUID? = nil) {
        self.entry = entry
        self.itemID = itemID
        self.subEventID = subEventID
    }

    @State private var title = ""
    @State private var category: MaintenanceCategory = .other
    @State private var completedDate = Date.now
    @State private var notes = ""
    @State private var costString = ""
    @State private var performedBy = ""
    @State private var rating: Int = 0
    @State private var selectedItemID: UUID?
    @State private var countsAsCompletion = true

    private var isEditing: Bool { entry != nil }
    private var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Item this entry is linked to whose schedule (or to-do active state)
    /// is affected by `countsAsCompletion`. Idea items have no schedule, so
    /// the toggle is hidden for them. Unlinked entries have nothing to affect.
    private var scheduledItem: MaintenanceItem? {
        guard let item = linkedItem, !item.isIdea else { return nil }
        return item
    }

    private var linkedToDo: MaintenanceItem? {
        guard let item = linkedItem, item.isOneTime else { return nil }
        return item
    }

    private var linkedSubEvent: SubEvent? {
        let resolvedSubID = subEventID ?? entry?.subEventID
        guard let subID = resolvedSubID else { return nil }
        guard let item = linkedItem else { return nil }
        return item.subEvents.first(where: { $0.id == subID })
    }

    private var linkedItem: MaintenanceItem? {
        let resolvedItemID = itemID ?? entry?.itemID ?? selectedItemID
        guard let id = resolvedItemID else { return nil }
        return store.items.first(where: { $0.id == id })
    }

    var body: some View {
        EditorSheet(
            title: isEditing ? "Edit Log Entry" : "Log Maintenance",
            isValid: isValid,
            saveLabel: isEditing ? "Save" : "Log Entry",
            onSave: save
        ) {
            Section("What was done") {
                    if itemID == nil && entry?.itemID == nil {
                        Picker("Linked item", selection: $selectedItemID) {
                            Text("None (standalone entry)").tag(UUID?.none)
                            ForEach(store.items) { item in
                                Label(item.name, systemImage: item.effectiveIcon).tag(UUID?.some(item.id))
                            }
                        }
                        .onChange(of: selectedItemID) { _, newID in
                            if let newID, let item = store.items.first(where: { $0.id == newID }) {
                                if title.isEmpty {
                                    title = item.name
                                }
                                category = item.category
                            }
                        }
                    }

                    if let linkedSub = linkedSubEvent, let parentItem = linkedItem {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.caption)
                                .foregroundStyle(.upkeepAmber)
                            Text(parentItem.name)
                                .font(.caption.weight(.medium))
                            Text("›")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(linkedSub.name.isEmpty ? "(unnamed)" : linkedSub.name)
                                .font(.caption.weight(.medium))
                        }
                        .padding(.vertical, 2)
                    }

                    LeadingTextFieldCore(text: $title, prompt: "Work summary (5–7 words or less)")

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $notes)
                            .frame(minHeight: 60)
                            .font(.body)
                    }

                    Picker("Category", selection: $category) {
                        ForEach(MaintenanceCategory.allCases) { cat in
                            Label(cat.label, systemImage: cat.icon).tag(cat)
                        }
                    }
                }

                Section {
                    LabeledContent("Date completed") {
                        HStack(spacing: 6) {
                            StepperDateField(selection: $completedDate)
                            CalendarPopoverButton(selection: $completedDate)
                        }
                    }

                    LeadingTextField(label: "Performed by", text: $performedBy, prompt: "Self, vendor name, etc.")

                    VStack(alignment: .leading, spacing: 2) {
                        LeadingTextField(label: "Cost", text: $costString, prompt: "Optional")
                        if costString.count > 1 && Decimal.fromCurrencyInput(costString) == nil {
                            Text("Enter a valid number")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }

                    HStack(spacing: 4) {
                        Text("Satisfaction")
                        Spacer()
                        RatingPicker(rating: $rating)
                    }
                }

                if let scheduled = scheduledItem {
                    Section {
                        Toggle(completionToggleLabel(for: scheduled), isOn: $countsAsCompletion)
                        Text(completionToggleHelp(for: scheduled, isOn: countsAsCompletion))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
        }
        .frame(width: 460, height: 540)
        .onAppear {
            if let entry {
                title = entry.title
                category = entry.category
                completedDate = entry.completedDate
                notes = entry.notes
                performedBy = entry.performedBy
                rating = entry.rating ?? 0
                selectedItemID = entry.itemID
                countsAsCompletion = entry.countsAsCompletion
                if let cost = entry.cost {
                    costString = "\(cost)"
                }
            } else {
                performedBy = store.localConfig.defaultPerformer
                if let itemID {
                    selectedItemID = itemID
                    if let item = store.items.first(where: { $0.id == itemID }) {
                        category = item.category
                        if let subEventID, let sub = item.subEvents.first(where: { $0.id == subEventID }) {
                            let subName = sub.name.trimmingCharacters(in: .whitespaces)
                            title = subName.isEmpty ? item.name : "\(item.name) — \(subName)"
                        } else {
                            title = item.name
                        }
                    }
                }
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let cost = Decimal.fromCurrencyInput(costString)
        let resolvedItemID = itemID ?? selectedItemID
        let ratingValue = rating > 0 ? rating : nil

        if var existing = entry {
            existing.title = trimmedTitle
            existing.category = category
            existing.completedDate = completedDate
            existing.notes = notes
            existing.cost = cost
            existing.performedBy = performedBy
            existing.rating = ratingValue
            existing.itemID = resolvedItemID
            existing.countsAsCompletion = countsAsCompletion
            store.updateLogEntry(existing)
        } else {
            store.logCompletion(
                itemID: resolvedItemID, subEventID: subEventID, title: trimmedTitle, category: category,
                date: completedDate, notes: notes, cost: cost, performedBy: performedBy,
                rating: ratingValue, countsAsCompletion: countsAsCompletion
            )
        }
    }

    private func completionToggleLabel(for item: MaintenanceItem) -> String {
        item.isOneTime ? "Mark to-do as complete" : "Counts as completion"
    }

    private func completionToggleHelp(for item: MaintenanceItem, isOn: Bool) -> String {
        if item.isOneTime {
            return isOn
                ? "Uncheck to log progress without finishing the to-do."
                : "Progress will be logged; the to-do stays active."
        }
        return isOn
            ? "Uncheck to log progress without resetting the next-due date."
            : "Progress will be logged; the schedule does not advance."
    }
}
