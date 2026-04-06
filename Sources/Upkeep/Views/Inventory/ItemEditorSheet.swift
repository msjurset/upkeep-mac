import SwiftUI

struct ItemEditorSheet: View {
    @Environment(UpkeepStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let item: MaintenanceItem?

    @State private var name = ""
    @State private var category: MaintenanceCategory = .other
    @State private var priority: Priority = .medium
    @State private var frequencyInterval = 1
    @State private var frequencyUnit: FrequencyUnit = .months
    @State private var startDate = Date.now
    @State private var notes = ""
    @State private var selectedVendorID: UUID?
    @State private var isActive = true
    @State private var trackSupply = false
    @State private var stockOnHand = 0
    @State private var quantityPerUse = 1
    @State private var productName = ""
    @State private var productURL = ""
    @State private var unitCostString = ""
    @State private var tagsString = ""

    private var isEditing: Bool { item != nil }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(isEditing ? "Edit Item" : "New Maintenance Item")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            // Form
            Form {
                Section("Details") {
                    LeadingTextField(label: "Name", text: $name)

                    Picker("Category", selection: $category) {
                        ForEach(MaintenanceCategory.allCases) { cat in
                            Label(cat.label, systemImage: cat.icon).tag(cat)
                        }
                    }

                    TagSuggestField(text: $tagsString)

                    Picker("Priority", selection: $priority) {
                        ForEach(Priority.allCases, id: \.self) { p in
                            Label(p.label, systemImage: p.icon).tag(p)
                        }
                    }
                }

                Section("Schedule") {
                    HStack(spacing: 8) {
                        Text("Every")
                        Stepper(value: $frequencyInterval, in: 1...365) {
                            Text("\(frequencyInterval)")
                                .monospacedDigit()
                                .frame(minWidth: 30)
                        }
                        Picker("", selection: $frequencyUnit) {
                            ForEach(FrequencyUnit.allCases) { unit in
                                Text(frequencyInterval == 1 ? unit.singular : unit.label).tag(unit)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 100)
                    }

                    DatePicker("Start tracking from", selection: $startDate, displayedComponents: .date)
                }

                Section("Vendor") {
                    Picker("Assigned vendor", selection: $selectedVendorID) {
                        Text("None").tag(UUID?.none)
                        ForEach(store.vendors) { vendor in
                            Text(vendor.name).tag(UUID?.some(vendor.id))
                        }
                    }
                }

                Section("Supply Tracking") {
                    Toggle("Track supplies for this item", isOn: $trackSupply)

                    if trackSupply {
                        Stepper("In stock: \(stockOnHand)", value: $stockOnHand, in: 0...999)
                        Stepper("Used per maintenance: \(quantityPerUse)", value: $quantityPerUse, in: 1...99)
                        LeadingTextField(label: "Product name", text: $productName, prompt: "e.g. MERV 13 Filter 20x25x1")
                        LeadingTextField(label: "Purchase link", text: $productURL, prompt: "https://amazon.com/...")
                        LeadingTextField(label: "Unit cost", text: $unitCostString, prompt: "Optional")
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                        .font(.body)
                }

                if isEditing {
                    Section {
                        Toggle("Active", isOn: $isActive)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // Actions
            HStack {
                Spacer()
                Button(isEditing ? "Save" : "Add Item") {
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
        .frame(width: 480, height: 640)
        .onAppear {
            if let item {
                name = item.name
                category = item.category
                priority = item.priority
                frequencyInterval = item.frequencyInterval
                frequencyUnit = item.frequencyUnit
                startDate = item.startDate
                notes = item.notes
                selectedVendorID = item.vendorID
                tagsString = item.tags.joined(separator: ", ")
                isActive = item.isActive
                if let supply = item.supply {
                    trackSupply = true
                    stockOnHand = supply.stockOnHand
                    quantityPerUse = supply.quantityPerUse
                    productName = supply.productName
                    productURL = supply.productURL
                    if let cost = supply.unitCost {
                        unitCostString = "\(cost)"
                    }
                }
            }
        }
    }

    private var currentSupply: Supply? {
        guard trackSupply else { return nil }
        return Supply(
            stockOnHand: stockOnHand,
            quantityPerUse: quantityPerUse,
            productName: productName,
            productURL: productURL,
            unitCost: Decimal(string: unitCostString)
        )
    }

    private var parsedTags: [String] {
        tagsString.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if var existing = item {
            existing.name = trimmedName
            existing.category = category
            existing.priority = priority
            existing.frequencyInterval = frequencyInterval
            existing.frequencyUnit = frequencyUnit
            existing.startDate = startDate
            existing.notes = notes
            existing.vendorID = selectedVendorID
            existing.supply = currentSupply
            existing.tags = parsedTags
            existing.isActive = isActive
            store.updateItem(existing)
        } else {
            store.createItem(
                name: trimmedName, category: category, priority: priority,
                frequencyInterval: frequencyInterval, frequencyUnit: frequencyUnit,
                startDate: startDate, notes: notes, vendorID: selectedVendorID,
                supply: currentSupply, tags: parsedTags
            )
        }
    }
}
