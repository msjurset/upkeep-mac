import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "house")
                        .font(.system(size: 32))
                        .foregroundStyle(.upkeepAmber)
                    VStack(alignment: .leading) {
                        Text("Upkeep Help")
                            .font(.title2.weight(.semibold))
                        Text("Home Maintenance Inventory & Log")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 8)

                helpSection("Getting Started", items: [
                    ("wrench.and.screwdriver", "Add Items", "Add everything in your home that needs attention. Choose Recurring, Seasonal, To-do, or Idea as the schedule type."),
                    ("calendar.badge.clock", "Multi-Event Schedules", "Break complex items (like a 6-step lawn program or multi-trade HVAC inspection) into timed sub-events with independent seasonal windows, due dates, or specialist vendor overrides."),
                    ("checklist", "To-do Items", "One-off fixes like \"repair hole in ceiling\" use the To-do schedule. Set a \"do by\" date; the item auto-deactivates when you log it complete."),
                    ("lightbulb", "Ideas", "Undated wishlist items like \"replace the carpet\" or \"build bookshelves.\" Capture research, vendor quotes, and costs in notes, follow-ups, and log entries over time. Convert to a To-do when ready."),
                    ("book", "Log Maintenance & Progress Notes", "When you do maintenance, log it with date, cost, performer, and rating. Toggle \"Counts as completion\" off to record mid-project progress notes without resetting the next-due date."),
                    ("person.2", "Vendors & Bid Sourcing", "Manage service providers and run structured Vendor Sourcings to compare candidate quotes, track \"Decide by\" deadlines, and promote hired winners automatically."),
                    ("checklist.checked", "Seasonal Procedures", "Run step-by-step operational checklists for Winterization, Spring Opening, Seasonal Prep, and Home Inspections across one or more properties."),
                    ("shippingbox", "Track Supplies", "For items that consume supplies (filters, salt, batteries), track stock levels, quantity per use, and get automatic reorder alerts."),
                    ("paperclip", "Attachments", "Attach photos, PDFs, or URLs to items, log entries, and sourcing quotes. Photos and PDFs are copied into your shared folder; PDFs can also be linked without copying."),
                ])

                helpSection("Keyboard Shortcuts", items: [
                    ("command", "Cmd+N", "New maintenance item (or New Idea when viewing Ideas)"),
                    ("command", "Cmd+Shift+N", "New log entry"),
                    ("command", "Cmd+K / Cmd+F / /", "Quick search across items, logs, vendors, follow-ups, and supplies"),
                    ("command", "Cmd+1 … Cmd+9", "Jump directly to Dashboard, Upcoming, Overdue, Ideas, All Items, Log, Vendors, Procedures, or Property Profile"),
                    ("command", "Cmd+[ / Cmd+]", "Navigate back and forward across item, vendor, sourcing, and log drill-downs"),
                    ("command", "Cmd+Z", "Undo last action"),
                ])

                helpSection("Dashboard & Weather Intelligence", items: [
                    ("gauge.with.dots.needle.33percent", "Health Score", "Shows how many items are on track vs overdue. Green = 80%+, amber = 50-80%, red = below 50%."),
                    ("cloud.sun.fill", "14-Day Weather & Spray Windows", "Local forecast powered by Open-Meteo from your property address, highlighting optimal dry/low-wind windows for outdoor maintenance."),
                    ("shippingbox.fill", "Reorder Alerts", "Items with low supply stock appear here with direct purchase links and 30-day snooze dismissal."),
                    ("checkmark.circle.fill", "Quick Log", "Click the green checkmark on overdue items to instantly mark them done."),
                    ("calendar", "30-Day Forecast", "See what's coming up over the next 30 days, organized by week."),
                    ("arrow.left.and.right", "Interactive Timeline", "Scrollable horizontal timeline showing completed maintenance on the left, upcoming and overdue items on the right."),
                    ("leaf", "Seasonal", "Suggestions based on the current season for items and sub-events that are due soon."),
                ])

                helpSection("Properties, Collaboration & Tips", items: [
                    ("building.2", "Multiple Properties & Major Systems", "Scope items, procedures, and logs across multiple properties (e.g. Primary Home, Mountain Cabin) and track major system lifespans (HVAC, Roof, Water Heater)."),
                    ("tag", "Tag Auto-Suggest", "Tag items for quick filtering — type \"tag:\" in search and use Tab/Arrow/Enter to filter by \"spring-prep\", \"outdoor\", etc."),
                    ("clock.badge.questionmark", "Snooze & Skip Year", "Snooze an item or individual sub-event to defer it temporarily, or skip a seasonal window for the current year without logging a fake completion."),
                    ("folder.badge.person.crop", "Household Shared Storage", "Point Settings > Data Location at a synced folder (iCloud Drive, Google Drive, Syncthing) for multi-member household collaboration with conflict detection."),
                ])
            }
            .padding(24)
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private func helpSection(_ title: String, items: [(String, String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.upkeepAmber)

            ForEach(items, id: \.1) { icon, label, description in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: icon)
                        .font(.callout)
                        .foregroundStyle(.upkeepAmber)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(.callout.weight(.medium))
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
