import Foundation

@MainActor
enum ExportService {
    static func generateHTMLReport(items: [MaintenanceItem], logEntries: [LogEntry], vendors: [Vendor], store: UpkeepStore) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        let costFormatter = NumberFormatter()
        costFormatter.numberStyle = .currency

        func formatCost(_ value: Decimal) -> String {
            costFormatter.string(from: value as NSDecimalNumber) ?? "$0"
        }

        var html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <title>Home Maintenance Report</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #333; max-width: 800px; margin: 0 auto; padding: 40px 20px; }
            h1 { font-size: 24px; margin-bottom: 4px; color: #8B6914; }
            .subtitle { font-size: 14px; color: #888; margin-bottom: 30px; }
            h2 { font-size: 18px; margin: 30px 0 12px; padding-bottom: 6px; border-bottom: 2px solid #C8943C; color: #8B6914; }
            h3 { font-size: 14px; margin: 16px 0 6px; }
            table { width: 100%; border-collapse: collapse; margin: 8px 0 16px; font-size: 13px; }
            th { text-align: left; padding: 8px; background: #f8f4ec; border-bottom: 1px solid #ddd; font-weight: 600; }
            td { padding: 8px; border-bottom: 1px solid #eee; }
            .cost { text-align: right; font-variant-numeric: tabular-nums; }
            .overdue { color: #c0392b; font-weight: 600; }
            .tag { display: inline-block; padding: 1px 6px; margin: 1px; background: #f0e6d0; border-radius: 10px; font-size: 11px; color: #8B6914; }
            .summary { display: flex; gap: 20px; margin-bottom: 20px; }
            .stat { background: #f8f4ec; padding: 12px 16px; border-radius: 8px; flex: 1; text-align: center; }
            .stat-value { font-size: 20px; font-weight: 700; }
            .stat-label { font-size: 11px; color: #888; margin-top: 2px; }
            @media (prefers-color-scheme: dark) {
                body { background: #1e1e1e; color: #ddd; }
                h1, h2 { color: #D4A843; }
                h2 { border-color: #D4A843; }
                th { background: #2a2520; }
                td { border-color: #333; }
                .stat { background: #2a2520; }
                .tag { background: #3a3020; color: #D4A843; }
            }
        </style>
        </head>
        <body>
        <h1>Home Maintenance Report</h1>
        <p class="subtitle">Generated \(dateFormatter.string(from: .now))</p>
        """

        // Summary stats
        let totalCost = logEntries.compactMap(\.cost).reduce(Decimal.zero, +)
        let overdueCount = items.filter { store.isOverdue($0) }.count
        html += """
        <div class="summary">
            <div class="stat"><div class="stat-value">\(items.filter(\.isActive).count)</div><div class="stat-label">Items Tracked</div></div>
            <div class="stat"><div class="stat-value">\(overdueCount)</div><div class="stat-label">Overdue</div></div>
            <div class="stat"><div class="stat-value">\(logEntries.count)</div><div class="stat-label">Log Entries</div></div>
            <div class="stat"><div class="stat-value">\(formatCost(totalCost))</div><div class="stat-label">Total Spent</div></div>
        </div>
        """

        // Inventory
        html += "<h2>Maintenance Inventory</h2>"
        html += "<table><tr><th>Item</th><th>Category</th><th>Frequency</th><th>Status</th><th>Tags</th></tr>"
        for item in items.sorted(by: { $0.name < $1.name }) {
            let status = store.isOverdue(item) ? "<span class=\"overdue\">Overdue</span>" : "On Track"
            let tagHTML = item.tags.map { "<span class=\"tag\">\($0)</span>" }.joined(separator: " ")
            html += "<tr><td>\(item.name)</td><td>\(item.category.label)</td><td>\(item.frequencyDescription)</td><td>\(status)</td><td>\(tagHTML)</td></tr>"
        }
        html += "</table>"

        // Maintenance Log
        html += "<h2>Maintenance Log</h2>"
        html += "<table><tr><th>Date</th><th>Description</th><th>Category</th><th>Performed By</th><th class=\"cost\">Cost</th></tr>"
        for entry in logEntries.sorted(by: { $0.completedDate > $1.completedDate }) {
            let costStr = entry.cost.map { formatCost($0) } ?? ""
            html += "<tr><td>\(dateFormatter.string(from: entry.completedDate))</td><td>\(entry.title)</td><td>\(entry.category.label)</td><td>\(entry.performedBy)</td><td class=\"cost\">\(costStr)</td></tr>"
        }
        html += "</table>"

        // Vendors
        if !vendors.isEmpty {
            html += "<h2>Service Providers</h2>"
            html += "<table><tr><th>Name</th><th>Specialty</th><th>Phone</th><th>Email</th></tr>"
            for vendor in vendors.sorted(by: { $0.name < $1.name }) {
                html += "<tr><td>\(vendor.name)</td><td>\(vendor.specialty)</td><td>\(vendor.phone)</td><td>\(vendor.email)</td></tr>"
            }
            html += "</table>"
        }

        html += "</body></html>"
        return html
    }
}
