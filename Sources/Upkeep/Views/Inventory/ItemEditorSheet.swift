import SwiftUI

struct ItemEditorSheet: View {
    @Environment(UpkeepStore.self) private var store

    let item: MaintenanceItem?

    @State private var name = ""
    @State private var category: MaintenanceCategory = .other
    @State private var priority: Priority = .medium
    @State private var scheduleKind: ScheduleKind = .recurring
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
    @State private var windowStartMonth = 6
    @State private var windowStartDay = 1
    @State private var windowEndMonth = 7
    @State private var windowEndDay = 15

    private var isEditing: Bool { item != nil }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        EditorSheet(
            title: isEditing ? "Edit Item" : "New Maintenance Item",
            isValid: isValid,
            saveLabel: isEditing ? "Save" : "Add Item",
            onSave: save
        ) {
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
                    Picker("Type", selection: $scheduleKind) {
                        Text("Recurring").tag(ScheduleKind.recurring)
                        Text("Seasonal").tag(ScheduleKind.seasonal)
                        Text("To-do").tag(ScheduleKind.oneTime)
                    }
                    .pickerStyle(.segmented)

                    switch scheduleKind {
                    case .seasonal:
                        HStack {
                            Text("Window opens")
                            Spacer()
                            Picker("", selection: $windowStartMonth) {
                                ForEach(1...12, id: \.self) { m in
                                    Text(monthName(m)).tag(m)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 100)
                            Stepper("\(windowStartDay)", value: $windowStartDay, in: 1...31)
                                .frame(width: 80)
                        }
                        HStack {
                            Text("Window closes")
                            Spacer()
                            Picker("", selection: $windowEndMonth) {
                                ForEach(1...12, id: \.self) { m in
                                    Text(monthName(m)).tag(m)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 100)
                            Stepper("\(windowEndDay)", value: $windowEndDay, in: 1...31)
                                .frame(width: 80)
                        }
                    case .recurring:
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
                    case .oneTime:
                        EmptyView()
                    }

                    DatePicker(
                        scheduleKind == .oneTime ? "Do by" : "Start tracking from",
                        selection: $startDate,
                        displayedComponents: .date
                    )
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
                        VStack(alignment: .leading, spacing: 2) {
                            LeadingTextField(label: "Unit cost", text: $unitCostString, prompt: "Optional")
                            if !unitCostString.isEmpty && Decimal(string: unitCostString) == nil {
                                Text("Enter a valid number")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            }
                        }
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
        .frame(width: 480, height: 640)
        .onAppear {
            if let item {
                name = item.name
                category = item.category
                priority = item.priority
                scheduleKind = item.scheduleKind
                frequencyInterval = item.frequencyInterval
                frequencyUnit = item.frequencyUnit
                startDate = item.startDate
                notes = item.notes
                selectedVendorID = item.vendorID
                tagsString = item.tags.joined(separator: ", ")
                isActive = item.isActive
                if let window = item.seasonalWindow {
                    windowStartMonth = window.startMonth
                    windowStartDay = window.startDay
                    windowEndMonth = window.endMonth
                    windowEndDay = window.endDay
                }
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

    private var currentSeasonalWindow: SeasonalWindow? {
        guard scheduleKind == .seasonal else { return nil }
        return SeasonalWindow(
            startMonth: windowStartMonth, startDay: windowStartDay,
            endMonth: windowEndMonth, endDay: windowEndDay
        )
    }

    private func monthName(_ month: Int) -> String {
        let df = DateFormatter()
        return df.monthSymbols[month - 1]
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if var existing = item {
            existing.name = trimmedName
            existing.category = category
            existing.priority = priority
            existing.scheduleKind = scheduleKind
            existing.frequencyInterval = frequencyInterval
            existing.frequencyUnit = frequencyUnit
            existing.startDate = startDate
            existing.seasonalWindow = currentSeasonalWindow
            existing.notes = notes
            existing.vendorID = selectedVendorID
            existing.supply = currentSupply
            existing.tags = parsedTags
            existing.isActive = isActive
            store.updateItem(existing)
        } else {
            store.createItem(
                name: trimmedName, category: category, priority: priority,
                scheduleKind: scheduleKind,
                frequencyInterval: frequencyInterval, frequencyUnit: frequencyUnit,
                startDate: startDate, notes: notes, vendorID: selectedVendorID,
                supply: currentSupply, tags: parsedTags,
                seasonalWindow: currentSeasonalWindow
            )
        }
    }
}
