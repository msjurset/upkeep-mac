import SwiftUI

struct SidebarView: View {
    @Environment(UpkeepStore.self) private var store
    @Binding var selection: NavigationItem?

    var body: some View {
        List(selection: $selection) {
            Section("Overview") {
                Label("Dashboard", systemImage: "gauge.with.dots.needle.33percent")
                    .tag(NavigationItem.dashboard)
            }

            Section("Inventory") {
                sidebarRow("Upcoming", icon: "clock", tag: .inventoryUpcoming, count: store.upcomingItems.count)
                sidebarRow("Overdue", icon: "exclamationmark.circle", tag: .inventoryOverdue, count: store.overdueItems.count, tint: store.overdueItems.isEmpty ? nil : .upkeepRed)
                sidebarRow("All Items", icon: "checklist", tag: .inventoryAll, count: store.activeItems.count)
            }

            Section("Journal") {
                sidebarRow("Log", icon: "book", tag: .log, count: store.logEntries.count)
            }

            Section("Contacts") {
                sidebarRow("Vendors", icon: "person.2", tag: .vendors, count: store.vendors.count)
            }

            Section("Home") {
                Label("Home Profile", systemImage: "house")
                    .tag(NavigationItem.homeProfile)
            }
        }
        .listStyle(.sidebar)
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
    }

    private func sidebarRow(_ title: String, icon: String, tag: NavigationItem, count: Int, tint: Color? = nil) -> some View {
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
        .tag(tag)
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
