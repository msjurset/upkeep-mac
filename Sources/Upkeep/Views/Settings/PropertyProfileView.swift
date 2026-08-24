import SwiftUI
import CoreLocation

struct PropertyProfileView: View {
    @Environment(UpkeepStore.self) private var store
    @Environment(WeatherStore.self) private var weather

    @State private var selectedPropertyID: UUID?
    @State private var property = Property()
    @State private var showAddPropertySheet = false
    @State private var showAddSystem = false
    @State private var editingSystemID: UUID?
    @State private var showDeleteConfirm = false
    @State private var geocodingState: GeocodingState = .idle
    @State private var geocodeTask: Task<Void, Never>?

    enum GeocodingState: Equatable {
        case idle
        case geocoding
        case success
        case failed(String)
    }

    private let availableIcons = [
        "house.fill", "cabin.log", "water.waves", "tree.fill", "building.2.fill", "sun.max.fill"
    ]

    var body: some View {
        Form {
            Section {
                Picker("Editing Property Profile", selection: Binding(
                    get: { selectedPropertyID ?? store.selectedPropertyID ?? store.primaryProperty?.id ?? store.properties.first?.id },
                    set: { newID in
                        if let newID, let p = store.properties.first(where: { $0.id == newID }) {
                            selectedPropertyID = p.id
                            property = p
                        }
                    }
                )) {
                    ForEach(store.properties) { p in
                        PropertyLabel(p.name + (p.isPrimary ? " (Primary)" : ""), icon: p.icon)
                            .tag(Optional(p.id))
                    }
                }
            }

            Section("Property Info") {
                LeadingTextField(label: "Property Name", text: $property.name, prompt: "e.g. Primary Home, Lake House")

                Picker("Icon", selection: $property.icon) {
                    PropertyLabel("Primary Home", icon: "house.fill").tag("house.fill")
                    PropertyLabel("Log Cabin / Lodge", icon: "cabin.log").tag("cabin.log")
                    PropertyLabel("Lake / Water House", icon: "water.waves").tag("water.waves")
                    PropertyLabel("Forest / Mountain Cabin", icon: "tree.fill").tag("tree.fill")
                    PropertyLabel("Townhome / Condo", icon: "building.2.fill").tag("building.2.fill")
                    PropertyLabel("Vacation / Beach", icon: "sun.max.fill").tag("sun.max.fill")
                }

                Toggle("Set as Primary Property", isOn: $property.isPrimary)

                LeadingTextField(label: "Address", text: $property.address)

                // Geocoding status row — shows the cached coordinates and a manual refresh button.
                HStack(spacing: 8) {
                    Image(systemName: locationIcon)
                        .foregroundStyle(locationTint)
                        .font(.caption)
                    Text(locationStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if geocodingState == .geocoding {
                        ProgressView().controlSize(.small)
                    } else if !property.address.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button("Refresh") {
                            geocodeNow()
                        }
                        .controlSize(.small)
                        .help("Re-geocode this address")
                    }
                }

                HStack {
                    Text("Year Built")
                    Spacer()
                    TextField("e.g. 1998", value: $property.yearBuilt, format: .number.grouping(.never))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Square Footage")
                    Spacer()
                    TextField("e.g. 2400", value: $property.squareFootage, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Major Systems") {
                if property.systems.isEmpty {
                    Text("Track major systems — roof, HVAC, water heater, septic, dock, etc.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                ForEach($property.systems) { $system in
                    Button {
                        editingSystemID = system.id
                    } label: {
                        systemRow(system: system)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Edit") { editingSystemID = system.id }
                        Button("Delete", role: .destructive) {
                            property.systems.removeAll { $0.id == system.id }
                            saveCurrentProperty()
                        }
                    }
                }
                .onDelete { indices in
                    property.systems.remove(atOffsets: indices)
                    saveCurrentProperty()
                }

                Button {
                    showAddSystem = true
                } label: {
                    Label("Add System", systemImage: "plus")
                }
            }

            Section("Notes") {
                TextEditor(text: $property.notes)
                    .frame(minHeight: 60)
                    .font(.body)
            }

            if store.properties.count > 1 {
                Section {
                    Button("Delete Property", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Property Profiles")
        .onAppear {
            loadCurrentProperty()
        }
        .onChange(of: property) { _, newProperty in
            saveCurrentProperty()
        }
        .onChange(of: property.address) { _, _ in
            scheduleGeocode()
        }
        .sheet(isPresented: $showAddPropertySheet) {
            PropertyEditorSheet(onSave: { newProperty in
                store.saveProperty(newProperty)
                selectedPropertyID = newProperty.id
                property = newProperty
            })
        }
        .sheet(isPresented: $showAddSystem) {
            SystemEditorSheet { system in
                property.systems.append(system)
                saveCurrentProperty()
            }
        }
        .sheet(isPresented: Binding(
            get: { editingSystemID != nil },
            set: { if !$0 { editingSystemID = nil } }
        )) {
            if let id = editingSystemID,
               let index = property.systems.firstIndex(where: { $0.id == id }) {
                SystemEditorSheet(system: property.systems[index], onSave: { updated in
                    property.systems[index] = updated
                    saveCurrentProperty()
                }, onDelete: {
                    property.systems.remove(at: index)
                    saveCurrentProperty()
                })
            }
        }
        .confirmationDialog("Delete \"\(property.name)\"?", isPresented: $showDeleteConfirm) {
            Button("Delete Property", role: .destructive) {
                let idToDelete = property.id
                store.deleteProperty(id: idToDelete)
                if let next = store.properties.first(where: { $0.id != idToDelete }) {
                    selectedPropertyID = next.id
                    property = next
                }
            }
        } message: {
            Text("This will delete the property profile. Linked items will remain in inventory.")
        }
    }

    private func loadCurrentProperty() {
        if let selID = selectedPropertyID, let found = store.properties.first(where: { $0.id == selID }) {
            property = found
        } else if let selStore = store.selectedProperty {
            selectedPropertyID = selStore.id
            property = selStore
        } else if let primary = store.primaryProperty {
            selectedPropertyID = primary.id
            property = primary
        } else if let first = store.properties.first {
            selectedPropertyID = first.id
            property = first
        }
    }

    private func saveCurrentProperty() {
        guard !property.name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if property.isPrimary {
            for idx in store.properties.indices where store.properties[idx].id != property.id {
                var other = store.properties[idx]
                if other.isPrimary {
                    other.isPrimary = false
                    store.saveProperty(other)
                }
            }
        }
        store.saveProperty(property)
    }

    // MARK: - Geocoding

    private var locationIcon: String {
        switch geocodingState {
        case .idle:
            return property.hasCoordinates ? "location.fill" : "location.slash"
        case .geocoding: return "location"
        case .success: return "location.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var locationTint: Color {
        switch geocodingState {
        case .idle:
            return property.hasCoordinates ? .upkeepGreen : .secondary
        case .geocoding: return .secondary
        case .success: return .upkeepGreen
        case .failed: return .upkeepAmber
        }
    }

    private var locationStatusText: String {
        switch geocodingState {
        case .geocoding: return "Looking up coordinates..."
        case .failed(let msg): return msg
        case .idle, .success:
            if let lat = property.latitude, let lon = property.longitude {
                return String(format: "%.4f°, %.4f° (used for weather)", lat, lon)
            }
            return "Add an address to enable weather forecasts."
        }
    }

    private func scheduleGeocode() {
        geocodeTask?.cancel()
        let address = property.address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else {
            geocodingState = .idle
            property.latitude = nil
            property.longitude = nil
            property.geocodedAddress = nil
            return
        }
        guard property.needsGeocoding else {
            geocodingState = .idle
            return
        }
        geocodeTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            if Task.isCancelled { return }
            await runGeocode(address: address)
        }
    }

    private func geocodeNow() {
        geocodeTask?.cancel()
        let address = property.address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else { return }
        geocodeTask = Task { await runGeocode(address: address) }
    }

    @MainActor
    private func runGeocode(address: String) async {
        geocodingState = .geocoding
        do {
            let placemarks = try await CLGeocoder().geocodeAddressString(address)
            guard let loc = placemarks.first?.location else {
                geocodingState = .failed("Couldn't find that address.")
                return
            }
            property.latitude = loc.coordinate.latitude
            property.longitude = loc.coordinate.longitude
            property.geocodedAddress = address
            geocodingState = .success
            saveCurrentProperty()
            if store.selectedPropertyID == nil || store.selectedPropertyID == property.id {
                weather.applyLocation(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
            }
        } catch {
            geocodingState = .failed("Lookup failed: \(error.localizedDescription)")
        }
    }

    private func systemRow(system: HomeProfile.HomeSystem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(system.name)
                    .font(.body.weight(.medium))
                if !system.brand.isEmpty {
                    Text("~ \(system.brand)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let remaining = system.remainingLifespan {
                    if remaining <= 2 {
                        Text("Replace soon")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.upkeepRed.opacity(0.12))
                            .foregroundStyle(.upkeepRed)
                            .clipShape(Capsule())
                    } else {
                        Text("~\(remaining) yrs left")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if let age = system.age {
                Text("\(age) years old")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add/Edit Property Sheet

struct PropertyEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    var existingProperty: Property? = nil
    var onSave: (Property) -> Void

    @State private var name = ""
    @State private var icon = "house.fill"
    @State private var isPrimary = false
    @State private var address = ""
    @State private var yearBuilt = ""
    @State private var squareFootage = ""
    @State private var notes = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(existingProperty == nil ? "Add Property" : "Edit Property")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            Form {
                LeadingTextField(label: "Property Name", text: $name, prompt: "e.g. Lake House, Mountain Cabin")

                Picker("Icon", selection: $icon) {
                    PropertyLabel("Primary Home", icon: "house.fill").tag("house.fill")
                    PropertyLabel("Log Cabin / Lodge", icon: "cabin.log").tag("cabin.log")
                    PropertyLabel("Lake / Water House", icon: "water.waves").tag("water.waves")
                    PropertyLabel("Forest / Mountain Cabin", icon: "tree.fill").tag("tree.fill")
                    PropertyLabel("Townhome / Condo", icon: "building.2.fill").tag("building.2.fill")
                    PropertyLabel("Vacation / Beach", icon: "sun.max.fill").tag("sun.max.fill")
                }

                Toggle("Set as Primary Property", isOn: $isPrimary)
                LeadingTextField(label: "Address", text: $address, prompt: "Street, City, State ZIP")
                LeadingTextField(label: "Year Built", text: $yearBuilt, prompt: "e.g. 2010")
                LeadingTextField(label: "Square Footage", text: $squareFootage, prompt: "e.g. 1800")

                TextEditor(text: $notes)
                    .frame(minHeight: 50)
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Save Property") {
                    var prop = existingProperty ?? Property()
                    prop.name = name
                    prop.address = address
                    prop.yearBuilt = Int(yearBuilt)
                    prop.squareFootage = Int(squareFootage)
                    prop.notes = notes
                    prop.icon = icon
                    prop.isPrimary = isPrimary
                    onSave(prop)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.upkeepAmber)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 420, height: 440)
        .onAppear {
            if let p = existingProperty {
                name = p.name
                icon = p.icon
                isPrimary = p.isPrimary
                address = p.address
                yearBuilt = p.yearBuilt.map { String($0) } ?? ""
                squareFootage = p.squareFootage.map { String($0) } ?? ""
                notes = p.notes
            }
        }
    }
}
