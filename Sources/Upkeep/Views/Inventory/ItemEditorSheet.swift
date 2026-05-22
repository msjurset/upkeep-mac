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
    @State private var selectedOwnerID: UUID?
    @State private var isActive = true
    @State private var trackSupply = false
    @State private var stockOnHand = 0
    @State private var quantityPerUse = 1
    @State private var productName = ""
    @State private var productURL = ""
    @State private var unitCostString = ""
    @State private var tagsString = ""
    @State private var customIcon: String?
    @State private var showIconPicker = false
    @State private var windowStartMonth = 6
    @State private var windowStartDay = 1
    @State private var windowEndMonth = 7
    @State private var windowEndDay = 15
    @State private var subEvents: [SubEvent] = []

    private var isEditing: Bool { item != nil }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        EditorSheet(
            title: isEditing ? "Edit Item" : "New Maintenance Item",
            isValid: isValid,
            saveLabel: isEditing ? "Save" : "Add Item",
            onSave: save
        ) {
                FormSection("Details") {
                    FormRow(label: "Name") {
                        HStack(spacing: 8) {
                            Button {
                                showIconPicker = true
                            } label: {
                                Image(systemName: customIcon ?? category.icon)
                                    .font(.title3)
                                    .foregroundStyle(.upkeepAmber)
                                    .frame(width: 28, height: 28)
                                    .background(Color.upkeepAmber.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                            .help("Choose an icon")
                            TextField("", text: $name)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    FormRow(label: "Category") {
                        Picker("", selection: $category) {
                            ForEach(MaintenanceCategory.allCases) { cat in
                                Label(cat.label, systemImage: cat.icon).tag(cat)
                            }
                        }
                        .labelsHidden()
                    }
                    FormRow(label: "Tags") {
                        TagSuggestField(text: $tagsString)
                    }
                    FormRow(label: "Priority") {
                        Picker("", selection: $priority) {
                            ForEach(Priority.allCases, id: \.self) { p in
                                Label(p.label, systemImage: p.icon).tag(p)
                            }
                        }
                        .labelsHidden()
                    }
                }

                FormSection("Schedule") {
                    FormRow(label: "Type") {
                        Picker("", selection: $scheduleKind) {
                            Text("Recurring").tag(ScheduleKind.recurring)
                            Text("Seasonal").tag(ScheduleKind.seasonal)
                            Text("To-do").tag(ScheduleKind.oneTime)
                            Text("Idea").tag(ScheduleKind.idea)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    switch scheduleKind {
                    case .seasonal:
                        FormRow(label: "Window opens") {
                            monthDayRow(month: $windowStartMonth, day: $windowStartDay)
                        }
                        FormRow(label: "Window closes") {
                            monthDayRow(month: $windowEndMonth, day: $windowEndDay)
                        }
                    case .recurring:
                        FormRow(label: "Every") {
                            HStack(spacing: 6) {
                                Stepper(value: $frequencyInterval, in: 1...365) {
                                    Text("\(frequencyInterval)")
                                        .monospacedDigit()
                                        .frame(minWidth: 24, alignment: .trailing)
                                }
                                .controlSize(.small)
                                .fixedSize()
                                Picker("", selection: $frequencyUnit) {
                                    ForEach(FrequencyUnit.allCases) { unit in
                                        Text(frequencyInterval == 1 ? unit.singular : unit.label).tag(unit)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 100)
                            }
                        }
                    case .oneTime, .idea:
                        EmptyView()
                    }

                    if scheduleKind != .idea {
                        FormRow(label: scheduleKind == .oneTime ? "Do by" : "Start tracking from") {
                            HStack(spacing: 6) {
                                StepperDateField(selection: $startDate)
                                CalendarPopoverButton(selection: $startDate)
                            }
                        }
                    }
                }

                if scheduleKind == .seasonal || scheduleKind == .oneTime {
                    FormSection("Multi-event schedule") {
                        SubEventsEditor(subEvents: $subEvents, parentScheduleKind: scheduleKind)
                    }
                }

                FormSection("Vendor") {
                    FormRow(label: "Assigned vendor") {
                        Picker("", selection: $selectedVendorID) {
                            Text("None").tag(UUID?.none)
                            ForEach(store.vendors) { vendor in
                                Text(vendor.name).tag(UUID?.some(vendor.id))
                            }
                        }
                        .labelsHidden()
                    }
                    FormRow(label: "Owner") {
                        Picker("", selection: $selectedOwnerID) {
                            Text("None").tag(UUID?.none)
                            ForEach(store.members) { member in
                                Text(member.name).tag(UUID?.some(member.id))
                            }
                        }
                        .labelsHidden()
                    }
                }

                FormSection("Supply Tracking") {
                    FormRow(label: "Track supplies") {
                        Toggle("", isOn: $trackSupply)
                            .labelsHidden()
                    }
                    if trackSupply {
                        FormRow(label: "In stock") {
                            Stepper("\(stockOnHand)", value: $stockOnHand, in: 0...999)
                                .monospacedDigit()
                        }
                        FormRow(label: "Used per maintenance") {
                            Stepper("\(quantityPerUse)", value: $quantityPerUse, in: 1...99)
                                .monospacedDigit()
                        }
                        FormRow(label: "Product name") {
                            TextField("e.g. MERV 13 Filter 20x25x1", text: $productName)
                                .textFieldStyle(.roundedBorder)
                        }
                        FormRow(label: "Purchase link") {
                            TextField("https://amazon.com/...", text: $productURL)
                                .textFieldStyle(.roundedBorder)
                        }
                        FormRow(label: "Unit cost") {
                            VStack(alignment: .leading, spacing: 2) {
                                TextField("Optional", text: $unitCostString)
                                    .textFieldStyle(.roundedBorder)
                                if unitCostString.count > 1 && Decimal.fromCurrencyInput(unitCostString) == nil {
                                    Text("Enter a valid number")
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                }

                FormSection("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                        .font(.body)
                }

                if isEditing {
                    FormSection {
                        FormRow(label: "Archived") {
                            HStack(spacing: 10) {
                                Toggle("", isOn: Binding(
                                    get: { !isActive },
                                    set: { isActive = !$0 }
                                ))
                                .labelsHidden()
                                Text("Archive this item to disable in lists and exclude from Upcoming/Overdue counts. Log history is preserved for all archives.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
        }
        .frame(width: 560, height: 660)
        .sheet(isPresented: $showIconPicker) {
            IconPicker(selection: $customIcon, fallbackIcon: category.icon, fallbackLabel: category.label)
        }
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
                selectedOwnerID = item.ownerID
                tagsString = item.tags.joined(separator: ", ")
                customIcon = item.customIcon
                isActive = item.isActive
                if let window = item.seasonalWindow {
                    windowStartMonth = window.startMonth
                    windowStartDay = window.startDay
                    windowEndMonth = window.endMonth
                    windowEndDay = window.endDay
                }
                subEvents = item.subEvents
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
        // Preserve any reorder-dismissal flag the user set from the dashboard;
        // re-saving the editor shouldn't undo a dismissal. Clear it when the
        // user restocks (new stockOnHand > previous), since restocking
        // semantically means "I handled the reorder."
        let prevSupply = item?.supply
        let prevDismissed = prevSupply?.reorderDismissedAt
        let restocked = (prevSupply?.stockOnHand ?? 0) < stockOnHand
        return Supply(
            stockOnHand: stockOnHand,
            quantityPerUse: quantityPerUse,
            productName: productName,
            productURL: productURL,
            unitCost: Decimal.fromCurrencyInput(unitCostString),
            reorderDismissedAt: restocked ? nil : prevDismissed
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

    @ViewBuilder
    private func monthDayRow(month: Binding<Int>, day: Binding<Int>) -> some View {
        HStack(spacing: 4) {
            Picker("", selection: month) {
                ForEach(1...12, id: \.self) { m in
                    Text(monthName(m)).tag(m)
                }
            }
            .labelsHidden()
            .frame(width: 100)
            TextField("", value: Binding(
                get: { day.wrappedValue },
                set: { day.wrappedValue = min(max($0, 1), 31) }
            ), format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 36)
            Stepper("", value: day, in: 1...31)
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
        }
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
            existing.ownerID = selectedOwnerID
            existing.supply = currentSupply
            existing.tags = parsedTags
            existing.customIcon = customIcon
            existing.isActive = isActive
            existing.subEvents = effectiveSubEvents
            store.updateItem(existing)
        } else {
            store.createItem(
                name: trimmedName, category: category, priority: priority,
                scheduleKind: scheduleKind,
                frequencyInterval: frequencyInterval, frequencyUnit: frequencyUnit,
                startDate: startDate, notes: notes, vendorID: selectedVendorID,
                ownerID: selectedOwnerID,
                supply: currentSupply, tags: parsedTags,
                customIcon: customIcon,
                seasonalWindow: currentSeasonalWindow,
                subEvents: effectiveSubEvents
            )
        }
    }

    /// Sub-events only apply to seasonal/one-time items. If the user switched
    /// the schedule kind to recurring/idea before saving, drop the sub-events
    /// so we don't carry orphaned data the rest of the app would have to
    /// ignore.
    private var effectiveSubEvents: [SubEvent] {
        guard scheduleKind == .seasonal || scheduleKind == .oneTime else { return [] }
        return subEvents.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}
