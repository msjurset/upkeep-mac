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
                    ("wrench.and.screwdriver", "Add Items", "Add everything in your home that needs maintenance — HVAC filters, gutters, water heater, etc. Pick Recurring, Seasonal, or To-do as the schedule type."),
                    ("checklist", "To-do Items", "One-off fixes like \"repair hole in ceiling\" use the To-do schedule. Set a \"do by\" date; the item auto-deactivates when you log it complete."),
                    ("book", "Log Maintenance", "When you do maintenance, log it. You can log against an inventory item or create standalone entries for one-off work."),
                    ("person.2", "Add Vendors", "Keep your service providers' contact info handy and link them to maintenance items."),
                    ("shippingbox", "Track Supplies", "For items that consume supplies (filters, salt, batteries), track stock levels and get reorder alerts."),
                ])

                helpSection("Keyboard Shortcuts", items: [
                    ("command", "Cmd+N", "New maintenance item"),
                    ("command", "Cmd+Shift+N", "New log entry"),
                    ("command", "Cmd+K / Cmd+F / /", "Quick search"),
                    ("command", "Cmd+Z", "Undo last action"),
                ])

                helpSection("Dashboard", items: [
                    ("gauge.with.dots.needle.33percent", "Health Score", "Shows how many items are on track vs overdue. Green = 80%+, amber = 50-80%, red = below 50%."),
                    ("shippingbox.fill", "Reorder Alerts", "Items with low supply stock appear here with links to purchase."),
                    ("checkmark.circle.fill", "Quick Log", "Click the green checkmark on overdue items to instantly mark them done."),
                    ("calendar", "30-Day Forecast", "See what's coming up over the next 30 days, organized by week."),
                    ("arrow.left.and.right", "Timeline", "Scrollable horizontal timeline showing completed maintenance on the left, upcoming and overdue items on the right. Drag, scroll, or use the arrow buttons to navigate."),
                    ("leaf", "Seasonal", "Suggestions based on the current season for items that are due soon."),
                ])

                helpSection("Tips", items: [
                    ("tag", "Tags", "Tag items for quick filtering — \"spring-prep\", \"weekend-project\", \"before-vacation\", etc."),
                    ("clock.badge.questionmark", "Snooze", "Can't do something right now? Snooze it to push the due date out without logging a fake completion."),
                    ("camera", "Photos", "Attach photos to log entries — receipts, before/after shots, model numbers."),
                    ("house", "Home Profile", "Record your home's major systems (roof, HVAC, water heater) with install dates and expected lifespans."),
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
