import SwiftUI

struct SettingsView: View {
    @Environment(UpkeepStore.self) private var store
    @State private var config = AppConfig()
    @State private var loaded = false
    @State private var dataPath = ""
    @State private var backups: [URL] = []
    @State private var showRestoreConfirm = false
    @State private var restoreURL: URL?
    @State private var newMemberName = ""
    @State private var newMemberColor = "amber"
    @State private var memberToDelete: HouseholdMember?
    @State private var isAddingMember = false
    @FocusState private var newMemberFieldFocused: Bool

    var body: some View {
        Form {
            Section("Household Members") {
                ForEach(store.members) { member in
                    MemberRow(
                        member: member,
                        isCurrent: member.id == store.currentMemberID,
                        onUpdate: { store.updateMember($0) },
                        onSetAsCurrent: { store.setCurrentMember(member) },
                        onDelete: { memberToDelete = member }
                    )
                }

                if isAddingMember {
                    HStack(spacing: 8) {
                        ColorSwatchPicker(selection: $newMemberColor)
                        TextField("Name", text: $newMemberName)
                            .textFieldStyle(.roundedBorder)
                            .labelsHidden()
                            .focused($newMemberFieldFocused)
                            .onSubmit(addNewMember)
                        Button("Add", action: addNewMember)
                            .disabled(newMemberName.trimmingCharacters(in: .whitespaces).isEmpty)
                        Button("Cancel", action: cancelAddMember)
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                            .keyboardShortcut(.cancelAction)
                    }
                } else {
                    Button {
                        isAddingMember = true
                        // Defer focus until the field has appeared.
                        DispatchQueue.main.async { newMemberFieldFocused = true }
                    } label: {
                        Label("Add to household", systemImage: "plus.circle")
                            .foregroundStyle(.upkeepAmber.opacity(0.7))
                    }
                    .buttonStyle(.borderless)
                }
            }

            Section("Appearance") {
                Picker("Theme", selection: Binding(
                    get: { store.localConfig.appearance },
                    set: {
                        store.localConfig.appearance = $0
                        store.localConfig.save()
                    }
                )) {
                    ForEach(AppAppearance.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Defaults") {
                HStack {
                    Text("Default performer")
                    Spacer()
                    TextField("e.g. Self", text: Binding(
                        get: { store.localConfig.defaultPerformer },
                        set: {
                            store.localConfig.defaultPerformer = $0
                            store.localConfig.save()
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    .multilineTextAlignment(.trailing)
                }

                Picker("Open on launch", selection: Binding(
                    get: { store.localConfig.launchView },
                    set: {
                        store.localConfig.launchView = $0
                        store.localConfig.save()
                    }
                )) {
                    ForEach(LaunchView.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
            }

            Section("Notifications") {
                Stepper("Remind \(config.defaultReminderDaysBefore) days before due", value: $config.defaultReminderDaysBefore, in: 1...30)
            }

            Section("Dashboard") {
                Toggle("Show recent completions", isOn: $config.showCompletedInDashboard)
                Stepper("Recent history: \(config.recentHistoryDays) days", value: $config.recentHistoryDays, in: 7...365, step: 7)
            }

            Section("To-do Items") {
                Toggle("Deactivate to-dos when completed", isOn: $config.autoDeactivateCompletedTodos)
                Text("When a to-do is logged, remove it from the active list. You can reactivate it later if needed.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Section("Data Location") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Shared data")
                            .font(.caption.weight(.medium))
                        Spacer()
                        Button("Change...") {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            panel.canCreateDirectories = true
                            if panel.runModal() == .OK, let url = panel.url {
                                store.reconfigureDataLocation(url.path)
                            }
                        }
                        .controlSize(.small)
                    }
                    Text(store.localConfig.dataLocation ?? "~/.upkeep/ (default)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Text("Items, logs, vendors, and photos. Can be a synced folder for household sharing.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Divider()

                    Text("Local data")
                        .font(.caption.weight(.medium))
                    Text("~/.upkeep/")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Text("Backups and instance-specific settings. Not synced.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Section("Backup & Restore") {
                HStack {
                    Button("Create Backup") {
                        Task {
                            do {
                                let url = try await store.backup()
                                backups = (try? await store.listBackups()) ?? []
                            } catch {
                                store.error = error.localizedDescription
                            }
                        }
                    }
                    .controlSize(.small)
                    Spacer()
                }

                if !backups.isEmpty {
                    ForEach(backups, id: \.lastPathComponent) { url in
                        HStack {
                            Text(url.lastPathComponent)
                                .font(.caption.monospaced())
                            Spacer()
                            Button("Restore") {
                                restoreURL = url
                                showRestoreConfirm = true
                            }
                            .controlSize(.mini)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 680)
        .onAppear {
            Task {
                if let loaded = try? await store.loadConfig() {
                    config = loaded
                }
                backups = (try? await store.listBackups()) ?? []
                self.loaded = true
            }
        }
        .onChange(of: config) { _, newConfig in
            guard loaded else { return }
            Task {
                try? await store.saveConfig(newConfig)
            }
        }
        .confirmationDialog("Restore from backup?", isPresented: $showRestoreConfirm) {
            Button("Restore", role: .destructive) {
                guard let url = restoreURL else { return }
                Task {
                    try? await store.restore(from: url)
                }
            }
        } message: {
            Text("This will replace all current data with the backup. This cannot be undone.")
        }
        .confirmationDialog(
            "Remove \(memberToDelete?.name ?? "member")?",
            isPresented: Binding(get: { memberToDelete != nil }, set: { if !$0 { memberToDelete = nil } })
        ) {
            Button("Remove", role: .destructive) {
                if let m = memberToDelete { store.removeMember(id: m.id) }
                memberToDelete = nil
            }
        } message: {
            Text("Items and log entries they touched will keep their history, but this member will no longer appear in pickers.")
        }
    }

    private func addNewMember() {
        let trimmed = newMemberName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let isFirst = store.members.isEmpty
        store.addMember(name: trimmed, color: newMemberColor)
        if isFirst, let added = store.members.last {
            store.setCurrentMember(added)
        }
        newMemberName = ""
        newMemberColor = "amber"
        isAddingMember = false
    }

    private func cancelAddMember() {
        newMemberName = ""
        newMemberColor = "amber"
        isAddingMember = false
    }
}

// MARK: - Member Row

/// Editable row: color swatch (click to change), inline-editable name,
/// "You" badge / "Set as me" button, and a delete button.
private struct MemberRow: View {
    let member: HouseholdMember
    let isCurrent: Bool
    let onUpdate: (HouseholdMember) -> Void
    let onSetAsCurrent: () -> Void
    let onDelete: () -> Void

    @State private var name: String = ""

    var body: some View {
        HStack(spacing: 8) {
            ColorSwatchPicker(selection: Binding(
                get: { member.color },
                set: { newColor in
                    var m = member
                    m.color = newColor
                    onUpdate(m)
                }
            ), initials: member.initials)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .onAppear { name = member.name }
                .onChange(of: member.name) { _, newValue in name = newValue }
                .onSubmit(commitName)
                // macOS doesn't call onSubmit on focus-loss; a focus-change handler
                // via FocusState would be the belt-and-suspenders fix, but onSubmit
                // plus the Return key covers the common case.

            Spacer()

            if isCurrent {
                Text("You")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.upkeepAmber.opacity(0.18)))
                    .foregroundStyle(.upkeepAmber)
            } else {
                Button("Set as me", action: onSetAsCurrent)
                    .buttonStyle(.borderless)
                    .controlSize(.small)
            }

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Remove member")
        }
    }

    private func commitName() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != member.name else {
            name = member.name
            return
        }
        var m = member
        m.name = trimmed
        onUpdate(m)
    }
}

// MARK: - Color Swatch Picker

/// Small circular color chip that opens a popover of `HouseholdMember.availableColors`
/// swatches. Optionally renders initials on top for member avatars.
private struct ColorSwatchPicker: View {
    @Binding var selection: String
    var initials: String? = nil
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Circle()
                .fill(memberColor(selection))
                .frame(width: 24, height: 24)
                .overlay {
                    if let initials {
                        Text(initials)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
        }
        .buttonStyle(.plain)
        .help("Change color")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            HStack(spacing: 6) {
                ForEach(HouseholdMember.availableColors, id: \.self) { color in
                    Button {
                        selection = color
                        isPresented = false
                    } label: {
                        Circle()
                            .fill(memberColor(color))
                            .frame(width: 22, height: 22)
                            .overlay {
                                if selection == color {
                                    Image(systemName: "checkmark")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
    }
}

// Shared helper used by settings + onboarding. Kept file-private here; the onboarding
// view has its own copy since it predates this refactor.
private func memberColor(_ name: String) -> Color {
    switch name {
    case "amber": return .upkeepAmber
    case "blue": return .blue
    case "green": return .upkeepGreen
    case "purple": return .purple
    case "red": return .upkeepRed
    case "teal": return .teal
    case "pink": return .pink
    case "orange": return .orange
    default: return .upkeepAmber
    }
}
