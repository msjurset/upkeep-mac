import SwiftUI

struct HomeProfileView: View {
    @Environment(UpkeepStore.self) private var store
    @State private var profile = HomeProfile()
    @State private var loaded = false
    @State private var showAddSystem = false
    @State private var editingSystemID: UUID?

    var body: some View {
        Form {
            Section("Property") {
                LeadingTextField(label: "Address", text: $profile.address)

                HStack {
                    Text("Year Built")
                    Spacer()
                    TextField("e.g. 1998", value: $profile.yearBuilt, format: .number.grouping(.never))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Square Footage")
                    Spacer()
                    TextField("e.g. 2400", value: $profile.squareFootage, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Major Systems") {
                if profile.systems.isEmpty {
                    Text("Track your home's major systems — roof, HVAC, water heater, etc.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                ForEach($profile.systems) { $system in
                    Button {
                        editingSystemID = system.id
                    } label: {
                        systemRow(system: system)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Edit") { editingSystemID = system.id }
                        Button("Delete", role: .destructive) {
                            profile.systems.removeAll { $0.id == system.id }
                        }
                    }
                }
                .onDelete { indices in
                    profile.systems.remove(atOffsets: indices)
                }

                Button {
                    showAddSystem = true
                } label: {
                    Label("Add System", systemImage: "plus")
                }
            }

            Section("Notes") {
                TextEditor(text: $profile.notes)
                    .frame(minHeight: 60)
                    .font(.body)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Home Profile")
        .onAppear {
            Task {
                if let loaded = try? await store.loadHomeProfile() {
                    profile = loaded
                }
                self.loaded = true
            }
        }
        .onChange(of: profile) { _, newProfile in
            guard loaded else { return }
            Task { try? await store.saveHomeProfile(newProfile) }
        }
        .sheet(isPresented: $showAddSystem) {
            SystemEditorSheet { system in
                profile.systems.append(system)
            }
        }
        .sheet(isPresented: Binding(
            get: { editingSystemID != nil },
            set: { if !$0 { editingSystemID = nil } }
        )) {
            if let id = editingSystemID,
               let index = profile.systems.firstIndex(where: { $0.id == id }) {
                SystemEditorSheet(system: profile.systems[index], onSave: { updated in
                    profile.systems[index] = updated
                }, onDelete: {
                    profile.systems.remove(at: index)
                })
            }
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

// MARK: - System Editor

struct SystemEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (HomeProfile.HomeSystem) -> Void
    var onDelete: (() -> Void)?

    private let existing: HomeProfile.HomeSystem?
    private var isEditing: Bool { existing != nil }

    @State private var name = ""
    @State private var brand = ""
    @State private var model = ""
    @State private var installedDate = Date.now
    @State private var hasInstalledDate = false
    @State private var lifespanYears = ""
    @State private var notes = ""
    @State private var showDeleteConfirm = false

    init(system: HomeProfile.HomeSystem? = nil, onSave: @escaping (HomeProfile.HomeSystem) -> Void, onDelete: (() -> Void)? = nil) {
        self.existing = system
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? "Edit System" : "Add System")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            Form {
                LeadingTextField(label: "Name", text: $name, prompt: "e.g. Water Heater, Roof, HVAC")
                LeadingTextField(label: "Brand", text: $brand)
                LeadingTextField(label: "Model", text: $model)

                Toggle("Track install date", isOn: $hasInstalledDate)
                if hasInstalledDate {
                    DatePicker("Installed", selection: $installedDate, displayedComponents: .date)
                }

                LeadingTextField(label: "Expected lifespan (years)", text: $lifespanYears)

                TextEditor(text: $notes)
                    .frame(minHeight: 40)
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                if isEditing && onDelete != nil {
                    Button("Delete", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
                Spacer()
                Button(isEditing ? "Save" : "Add") {
                    var system = existing ?? HomeProfile.HomeSystem(name: "")
                    system.name = name
                    system.brand = brand
                    system.model = model
                    system.installedDate = hasInstalledDate ? installedDate : nil
                    system.expectedLifespanYears = Int(lifespanYears)
                    system.notes = notes
                    onSave(system)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.upkeepAmber)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
            .confirmationDialog("Delete \"\(name)\"?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("This will permanently remove this system.")
            }
        }
        .frame(width: 400, height: 420)
        .onAppear {
            if let system = existing {
                name = system.name
                brand = system.brand
                model = system.model
                if let date = system.installedDate {
                    installedDate = date
                    hasInstalledDate = true
                }
                if let years = system.expectedLifespanYears {
                    lifespanYears = "\(years)"
                }
                notes = system.notes
            }
        }
    }
}
