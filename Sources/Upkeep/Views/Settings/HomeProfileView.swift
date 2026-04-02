import SwiftUI

struct HomeProfileView: View {
    @Environment(UpkeepStore.self) private var store
    @State private var profile = HomeProfile()
    @State private var loaded = false
    @State private var showAddSystem = false

    var body: some View {
        Form {
            Section("Property") {
                TextField("Address", text: $profile.address)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Year Built")
                    Spacer()
                    TextField("e.g. 1998", value: $profile.yearBuilt, format: .number)
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
                    systemRow(system: system)
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

    @State private var name = ""
    @State private var brand = ""
    @State private var model = ""
    @State private var installedDate = Date.now
    @State private var hasInstalledDate = false
    @State private var lifespanYears = ""
    @State private var notes = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add System")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            Form {
                TextField("Name", text: $name, prompt: Text("e.g. Water Heater, Roof, HVAC"))
                    .textFieldStyle(.roundedBorder)
                TextField("Brand", text: $brand)
                    .textFieldStyle(.roundedBorder)
                TextField("Model", text: $model)
                    .textFieldStyle(.roundedBorder)

                Toggle("Track install date", isOn: $hasInstalledDate)
                if hasInstalledDate {
                    DatePicker("Installed", selection: $installedDate, displayedComponents: .date)
                }

                TextField("Expected lifespan (years)", text: $lifespanYears)
                    .textFieldStyle(.roundedBorder)

                TextEditor(text: $notes)
                    .frame(minHeight: 40)
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Add") {
                    let system = HomeProfile.HomeSystem(
                        name: name, brand: brand, model: model,
                        installedDate: hasInstalledDate ? installedDate : nil,
                        expectedLifespanYears: Int(lifespanYears),
                        notes: notes
                    )
                    onSave(system)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.upkeepAmber)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 400, height: 420)
    }
}
