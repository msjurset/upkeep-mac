import SwiftUI

struct LogEntrySheet: View {
    @Environment(UpkeepStore.self) private var store

    let entry: LogEntry?
    let itemID: UUID?

    @State private var title = ""
    @State private var category: MaintenanceCategory = .other
    @State private var completedDate = Date.now
    @State private var notes = ""
    @State private var costString = ""
    @State private var performedBy = ""
    @State private var rating: Int = 0
    @State private var selectedItemID: UUID?
    @State private var markComplete = true

    private var isEditing: Bool { entry != nil }
    private var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    private var linkedToDo: MaintenanceItem? {
        let id = itemID ?? selectedItemID ?? entry?.itemID
        guard let id else { return nil }
        guard let item = store.items.first(where: { $0.id == id }), item.isOneTime else { return nil }
        return item
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

                Section("Details") {
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

                if !isEditing, linkedToDo != nil {
                    Section {
                        Toggle("Mark to-do as complete", isOn: $markComplete)
                        Text(markComplete
                             ? "Uncheck to log progress without finishing the to-do."
                             : "Progress will be logged; the to-do stays active.")
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
                if let cost = entry.cost {
                    costString = "\(cost)"
                }
            } else {
                performedBy = store.localConfig.defaultPerformer
                if let itemID {
                    selectedItemID = itemID
                    if let item = store.items.first(where: { $0.id == itemID }) {
                        title = item.name
                        category = item.category
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
            store.updateLogEntry(existing)
        } else {
            store.logCompletion(
                itemID: resolvedItemID, title: trimmedTitle, category: category,
                date: completedDate, notes: notes, cost: cost, performedBy: performedBy,
                rating: ratingValue, markComplete: markComplete
            )
        }
    }
}
