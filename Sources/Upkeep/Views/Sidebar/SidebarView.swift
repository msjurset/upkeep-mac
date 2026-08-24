import SwiftUI

struct SidebarView: View {
    @Environment(UpkeepStore.self) private var store
    @Binding var selection: NavigationItem?

    @State private var showNewPropertySheet = false
    @State private var editingProperty: Property? = nil

    var body: some View {
        List(selection: $selection) {
            Section("Overview") {
                sidebarRow("Dashboard", icon: "gauge.with.dots.needle.33percent", tag: .dashboard, count: 0, identifier: "sidebar.dashboard")
            }

            Section("Inventory") {
                sidebarRow("Upcoming", icon: "clock", tag: .inventoryUpcoming, count: store.upcomingItems.count, identifier: "sidebar.upcoming")
                sidebarRow("Overdue", icon: "exclamationmark.circle", tag: .inventoryOverdue, count: store.overdueItems.count, tint: store.overdueItems.isEmpty ? nil : .upkeepRed, identifier: "sidebar.overdue")
                sidebarRow("Ideas", icon: "lightbulb", tag: .inventoryIdeas, count: store.ideaItems.count, identifier: "sidebar.ideas")
                sidebarRow("All Items", icon: "checklist", tag: .inventoryAll, count: store.items.count, identifier: "sidebar.allItems")
            }

            Section("Journal") {
                sidebarRow("Log", icon: "book", tag: .log, count: store.logEntries.count, identifier: "sidebar.log")
            }

            Section("Contacts") {
                sidebarRow("Vendors", icon: "person.2", tag: .vendors, count: store.vendors.count, identifier: "sidebar.vendors")
            }

            Section("Workflows") {
                sidebarRow("Procedures", icon: "checklist.checked", tag: .procedures, count: store.scopedProcedures.count, identifier: "sidebar.procedures")
            }

            Section {
                ForEach(store.properties) { p in
                    sidebarPropertyRow(property: p)
                }
            } header: {
                HStack {
                    Text("Properties")
                    Spacer()
                    Button {
                        showNewPropertySheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 8)
                    }
                    .buttonStyle(.plain)
                    .help("Add Property")
                }
            }
        }
        .listStyle(.sidebar)
        .accessibilityIdentifier("sidebar")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 12) {
                SettingsLink {
                    Image(systemName: "gearshape")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")

                Button {
                    exportReport()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Export maintenance report")

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
            .padding(.top, 10)
        }
        .navigationTitle("Upkeep")
        .sheet(isPresented: $showNewPropertySheet) {
            PropertyEditorSheet { newProp in
                store.saveProperty(newProp)
                store.selectedPropertyID = newProp.id
            }
        }
        .sheet(item: $editingProperty) { prop in
            PropertyEditorSheet(existingProperty: prop) { updatedProp in
                store.saveProperty(updatedProp)
            }
        }
    }

    private func sidebarRow(_ title: String, icon: String, tag: NavigationItem, count: Int, tint: Color? = nil, identifier: String) -> some View {
        NavigationLink(value: tag) {
            HStack {
                Label(title, systemImage: icon)
                    .foregroundStyle(tint ?? .primary)
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundStyle(tint ?? .secondary)
                        .monospacedDigit()
                }
            }
        }
        .accessibilityIdentifier(identifier)
    }

    private func sidebarPropertyRow(property: Property) -> some View {
        let isSelected = store.selectedPropertyID == property.id

        return HStack(spacing: 6) {
            // Left checkmark (active property indicator)
            Image(systemName: isSelected ? "checkmark" : "")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.upkeepAmber)
                .frame(width: 14)

            // Property label button (click to switch active scope)
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    store.selectedPropertyID = property.id
                }
            } label: {
                HStack(spacing: 6) {
                    PropertyIconView(property.icon)
                    Text(property.name)
                        .font(.body)
                }
                .foregroundStyle(.primary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            // Right edit pen button (click to edit property details)
            Button {
                editingProperty = property
            } label: {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Edit \(property.name)")
        }
        .contextMenu {
            Button("Edit Property...") {
                editingProperty = property
            }
            if !property.isPrimary {
                Button("Set as Primary") {
                    var updated = property
                    updated.isPrimary = true
                    store.saveProperty(updated)
                }
            }
        }
    }

    private func exportReport() {
        let html = ExportService.generateHTMLReport(
            items: store.items, logEntries: store.logEntries,
            vendors: store.vendors, store: store
        )
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = "Upkeep-Report.html"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? html.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
