import SwiftUI

struct OnboardingView: View {
    @Environment(UpkeepStore.self) private var store
    @State private var name = ""
    @State private var selectedColor = "amber"
    @State private var dataPath = ""
    @State private var useCustomPath = false

    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "house")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.upkeepAmber)
                Text("Welcome to Upkeep")
                    .font(.title.weight(.semibold))
                Text("Let's get you set up")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Who are you?
            VStack(alignment: .leading, spacing: 12) {
                Text("Who are you?")
                    .font(.headline)

                TextField("Your name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)

                HStack(spacing: 8) {
                    Text("Pick a color:")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    ForEach(HouseholdMember.availableColors, id: \.self) { color in
                        Button {
                            selectedColor = color
                        } label: {
                            Circle()
                                .fill(memberColor(color))
                                .frame(width: 24, height: 24)
                                .overlay {
                                    if selectedColor == color {
                                        Image(systemName: "checkmark")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Existing members
                if !store.members.isEmpty {
                    Divider()
                    Text("Or join as an existing member:")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    ForEach(store.members) { member in
                        Button {
                            store.setCurrentMember(member)
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(memberColor(member.color))
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        Text(member.initials)
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                Text(member.name)
                                    .font(.callout)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 8).fill(.background))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator.opacity(0.3)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Data location
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Use custom data location", isOn: $useCustomPath)
                    .font(.callout)
                if useCustomPath {
                    HStack {
                        TextField("Path to shared folder", text: $dataPath)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 280)
                        Button("Browse...") {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            panel.canCreateDirectories = true
                            if panel.runModal() == .OK, let url = panel.url {
                                dataPath = url.path
                            }
                        }
                    }
                    Text("Point this to a Google Drive, iCloud, or shared folder for family sync")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Go
            Button {
                setup()
            } label: {
                Text("Get Started")
                    .font(.callout.weight(.medium))
                    .frame(width: 200)
            }
            .buttonStyle(.borderedProminent)
            .tint(.upkeepAmber)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            .controlSize(.large)
        }
        .padding(40)
        .frame(width: 500, height: 600)
        .onAppear {
            store.loadAll()
        }
    }

    private func setup() {
        if useCustomPath && !dataPath.isEmpty {
            store.reconfigureDataLocation(dataPath)
        }
        let member = HouseholdMember(name: name.trimmingCharacters(in: .whitespaces), color: selectedColor)
        store.addMember(name: member.name, color: member.color)
        // Need to get the actual member we just added (with generated ID)
        if let added = store.members.last {
            store.setCurrentMember(added)
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
