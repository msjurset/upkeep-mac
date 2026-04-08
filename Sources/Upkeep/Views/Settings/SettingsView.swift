import SwiftUI

struct SettingsView: View {
    @Environment(UpkeepStore.self) private var store
    @State private var config = AppConfig()
    @State private var loaded = false
    @State private var dataPath = ""
    @State private var backups: [URL] = []
    @State private var showRestoreConfirm = false
    @State private var restoreURL: URL?

    var body: some View {
        Form {
            Section("You") {
                if let member = store.currentMember {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(memberColor(member.color))
                            .frame(width: 24, height: 24)
                            .overlay {
                                Text(member.initials)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        Text(member.name)
                            .font(.callout)
                    }
                }
            }

            Section("Household Members") {
                ForEach(store.members) { member in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(memberColor(member.color))
                            .frame(width: 20, height: 20)
                            .overlay {
                                Text(member.initials)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        Text(member.name)
                            .font(.callout)
                        Spacer()
                        if member.id == store.currentMemberID {
                            Text("You")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
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
    }

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
}
