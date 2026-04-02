import SwiftUI

struct LogEntrySheet: View {
    @Environment(UpkeepStore.self) private var store
    @Environment(\.dismiss) private var dismiss

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

    private var isEditing: Bool { entry != nil }
    private var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(isEditing ? "Edit Log Entry" : "Log Maintenance")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            Form {
                Section("What was done") {
                    if itemID == nil && entry?.itemID == nil {
                        Picker("Linked item", selection: $selectedItemID) {
                            Text("None (standalone entry)").tag(UUID?.none)
                            ForEach(store.items) { item in
                                Label(item.name, systemImage: item.category.icon).tag(UUID?.some(item.id))
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

                    TextField("Title", text: $title)
                        .textFieldStyle(.roundedBorder)

                    Picker("Category", selection: $category) {
                        ForEach(MaintenanceCategory.allCases) { cat in
                            Label(cat.label, systemImage: cat.icon).tag(cat)
                        }
                    }
                }

                Section("Details") {
                    DatePicker("Date completed", selection: $completedDate, displayedComponents: .date)

                    TextField("Performed by", text: $performedBy, prompt: Text("Self, vendor name, etc."))
                        .textFieldStyle(.roundedBorder)

                    TextField("Cost", text: $costString, prompt: Text("Optional"))
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 4) {
                        Text("Satisfaction")
                        Spacer()
                        RatingPicker(rating: $rating)
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                        .font(.body)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button(isEditing ? "Save" : "Log Entry") {
                    save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.upkeepAmber)
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
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
            } else if let itemID {
                selectedItemID = itemID
                if let item = store.items.first(where: { $0.id == itemID }) {
                    title = item.name
                    category = item.category
                }
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let cost = Decimal(string: costString)
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
                rating: ratingValue
            )
        }
    }
}
