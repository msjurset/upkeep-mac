import SwiftUI

struct DashboardView: View {
    @Environment(UpkeepStore.self) private var store
    @State private var showLogSheet = false
    @State private var quickLogItemID: UUID?

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= 700
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if store.items.isEmpty && store.logEntries.isEmpty {
                        emptyState
                    } else if wide {
                        wideLayout
                    } else {
                        narrowLayout
                    }
                }
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("Dashboard")
        .sheet(isPresented: $showLogSheet) {
            if let itemID = quickLogItemID,
               store.items.contains(where: { $0.id == itemID }) {
                LogEntrySheet(entry: nil, itemID: itemID)
            }
        }
    }

    // MARK: - Responsive Layouts

    /// Two-column layout for wider windows
    private var wideLayout: some View {
        VStack(alignment: .leading, spacing: 28) {
            // Health overview spans full width
            healthOverview
                .padding(.horizontal, 24)

            // Two-column body
            HStack(alignment: .top, spacing: 20) {
                // Left column: action items & activity
                VStack(alignment: .leading, spacing: 28) {
                    if !store.lowStockItems.isEmpty {
                        reorderAlerts
                    }
                    if !store.pendingFollowUps.isEmpty {
                        followUpsSection
                    }
                    if !store.overdueItems.isEmpty {
                        overdueSection
                    }
                    next30DaysTimeline
                    if !store.recentLogEntries.isEmpty {
                        recentActivity
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right column: planning & costs
                VStack(alignment: .leading, spacing: 28) {
                    seasonalSection
                    if !store.logEntries.isEmpty {
                        costSection
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 24)
        }
    }

    /// Single-column layout for narrower windows
    private var narrowLayout: some View {
        VStack(alignment: .leading, spacing: 28) {
            healthOverview
            if !store.lowStockItems.isEmpty {
                reorderAlerts
            }
            if !store.pendingFollowUps.isEmpty {
                followUpsSection
            }
            if !store.overdueItems.isEmpty {
                overdueSection
            }
            next30DaysTimeline
            seasonalSection
            if !store.recentLogEntries.isEmpty {
                recentActivity
            }
            if !store.logEntries.isEmpty {
                costSection
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Health Overview

    private var healthOverview: some View {
        HStack(spacing: 20) {
            // Progress ring
            let total = store.activeItems.count
            let onTrack = store.onTrackCount
            let fraction = total > 0 ? Double(onTrack) / Double(total) : 1.0

            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .strokeBorder(.separator.opacity(0.3), lineWidth: 6)
                        .frame(width: 72, height: 72)

                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(
                            fraction >= 0.8 ? Color.upkeepGreen : fraction >= 0.5 ? Color.upkeepAmber : Color.upkeepRed,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 72, height: 72)

                    VStack(spacing: 0) {
                        Text("\(onTrack)")
                            .font(.title3.weight(.bold).monospacedDigit())
                        Text("of \(total)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("On Track")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 100)

            // Key stats
            VStack(alignment: .leading, spacing: 10) {
                if store.overdueItems.isEmpty {
                    statRow(icon: "checkmark.circle.fill", tint: .upkeepGreen, label: "All caught up", detail: "Nothing overdue")
                } else {
                    statRow(icon: "exclamationmark.circle.fill", tint: .upkeepRed,
                            label: "\(store.overdueItems.count) overdue",
                            detail: longestOverdueText)
                }

                statRow(icon: "calendar", tint: .upkeepAmber,
                        label: "\(dueSoon7.count) due this week",
                        detail: dueSoon7.first.map { $0.name } ?? "")

                let lowStock = store.lowStockItems.count
                if lowStock > 0 {
                    statRow(icon: "shippingbox.fill", tint: .orange,
                            label: "\(lowStock) need reorder",
                            detail: store.lowStockItems.first.map { $0.name } ?? "")
                } else {
                    statRow(icon: "dollarsign.circle", tint: .upkeepBrown,
                            label: totalCost30d,
                            detail: "Spent in last 30 days")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cardStyle()
    }

    private func statRow(icon: String, tint: Color, label: String, detail: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(tint)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.callout.weight(.medium))
                if !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var longestOverdueText: String {
        guard let item = store.longestOverdueItem else { return "" }
        let days = abs(store.daysUntilDue(item))
        return "\(item.name) — \(days) days overdue"
    }

    private var dueSoon7: [MaintenanceItem] {
        let end = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        return store.itemsDueInRange(start: .now, end: end)
    }

    // MARK: - Reorder Alerts

    private var reorderAlerts: some View {
        sectionView(title: "Reorder Needed", icon: "shippingbox.fill", tint: .orange) {
            ForEach(store.lowStockItems) { item in
                if let supply = item.supply {
                    Button {
                        store.navigation = .inventoryAll
                        store.selectedItemID = item.id
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.category.icon)
                                .font(.body)
                                .foregroundStyle(Color.categoryColor(item.category))
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.body.weight(.medium))
                                    .lineLimit(1)
                                if !supply.productName.isEmpty {
                                    Text(supply.productName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            SupplyBadge(supply: supply)

                            if !supply.productURL.isEmpty {
                                Link(destination: URL(string: supply.productURL) ?? URL(string: "about:blank")!) {
                                    Image(systemName: "cart")
                                        .font(.caption)
                                        .padding(6)
                                        .background(Circle().fill(.upkeepAmber.opacity(0.12)))
                                        .foregroundStyle(.upkeepAmber)
                                }
                                .help("Order online")
                            }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.background))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.orange.opacity(0.3)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Follow-Ups

    private var followUpsSection: some View {
        sectionView(title: "Follow-Ups", icon: "bell.badge", tint: .upkeepAmber) {
            ForEach(store.pendingFollowUps) { item in
                let pending = item.followUps.filter { !$0.isDone }
                ForEach(pending) { followUp in
                    HStack(spacing: 10) {
                        Button {
                            store.toggleFollowUp(itemID: item.id, followUpID: followUp.id)
                        } label: {
                            Image(systemName: "circle")
                                .font(.body)
                                .foregroundStyle(followUp.isOverdue ? .upkeepRed : .secondary)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(followUp.title)
                                .font(.body)
                                .lineLimit(1)
                            HStack(spacing: 4) {
                                Text(item.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let due = followUp.dueDate {
                                    Text("~ \(due.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundStyle(followUp.isOverdue ? .upkeepRed : .secondary)
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.background))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator.opacity(0.2)))
                }
            }
        }
    }

    // MARK: - Overdue with Quick Log

    private var overdueSection: some View {
        sectionView(title: "Overdue", icon: "exclamationmark.circle.fill", tint: .upkeepRed) {
            ForEach(store.overdueItems.prefix(5)) { item in
                HStack(spacing: 10) {
                    Button {
                        store.navigation = .inventoryAll
                        store.selectedItemID = item.id
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.category.icon)
                                .font(.body)
                                .foregroundStyle(Color.categoryColor(item.category))
                                .frame(width: 24)

                            Text(item.name)
                                .font(.body)
                                .lineLimit(1)

                            Spacer()

                            if let supply = item.supply, supply.needsReorder {
                                SupplyBadge(supply: supply)
                            }

                            let days = store.daysUntilDue(item)
                            DueDateBadge(daysUntilDue: days)
                        }
                    }
                    .buttonStyle(.plain)

                    // Quick log button
                    Button {
                        store.logCompletion(
                            itemID: item.id, title: item.name,
                            category: item.category, performedBy: "Self"
                        )
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.upkeepGreen)
                    }
                    .buttonStyle(.plain)
                    .help("Mark as done")
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(.background))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator.opacity(0.2)))
            }
            if store.overdueItems.count > 5 {
                moreButton(count: store.overdueItems.count - 5, destination: .inventoryOverdue)
            }

            if store.overdueItems.count > 1 {
                Button {
                    for item in store.overdueItems {
                        store.logCompletion(
                            itemID: item.id, title: item.name,
                            category: item.category, performedBy: "Self"
                        )
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.upkeepGreen)
                        Text("Mark all \(store.overdueItems.count) as done")
                            .font(.callout.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.upkeepGreen.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.upkeepGreen.opacity(0.3)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Next 30 Days Timeline

    private var next30DaysTimeline: some View {
        let weeks = upcomingWeeks
        let hasItems = weeks.contains { !$0.items.isEmpty }

        return Group {
            if hasItems {
                sectionView(title: "Next 30 Days", icon: "calendar", tint: .upkeepAmber) {
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(weeks, id: \.label) { week in
                            VStack(spacing: 6) {
                                Text(week.label)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)

                                if week.items.isEmpty {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(.separator.opacity(0.15))
                                        .frame(height: 40)
                                        .overlay {
                                            Text("Clear")
                                                .font(.system(size: 9))
                                                .foregroundStyle(.tertiary)
                                        }
                                } else {
                                    VStack(spacing: 3) {
                                        ForEach(week.items) { item in
                                            Button {
                                                store.navigation = .inventoryAll
                                                store.selectedItemID = item.id
                                            } label: {
                                                HStack(spacing: 4) {
                                                    Circle()
                                                        .fill(Color.categoryColor(item.category))
                                                        .frame(width: 6, height: 6)
                                                    Text(item.name)
                                                        .font(.system(size: 10))
                                                        .lineLimit(1)
                                                }
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(RoundedRectangle(cornerRadius: 4).fill(Color.categoryColor(item.category).opacity(0.08)))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.background))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator.opacity(0.2)))
                }
            }
        }
    }

    private struct WeekBucket: Hashable {
        let label: String
        let items: [MaintenanceItem]

        func hash(into hasher: inout Hasher) { hasher.combine(label) }
        static func == (lhs: WeekBucket, rhs: WeekBucket) -> Bool { lhs.label == rhs.label }
    }

    private var upcomingWeeks: [WeekBucket] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var buckets: [WeekBucket] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        for i in 0..<4 {
            let weekStart = cal.date(byAdding: .day, value: i * 7, to: today)!
            let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart)!
            let label = i == 0 ? "This Week" : formatter.string(from: weekStart)
            let items = store.itemsDueInRange(start: weekStart, end: weekEnd)
            buckets.append(WeekBucket(label: label, items: items))
        }
        return buckets
    }

    // MARK: - Seasonal Awareness

    private var seasonalSection: some View {
        let suggestions = seasonalSuggestions
        return Group {
            if !suggestions.isEmpty {
                sectionView(title: seasonTitle, icon: seasonIcon, tint: .upkeepAmber) {
                    VStack(spacing: 1) {
                        ForEach(suggestions) { item in
                            Button {
                                store.navigation = .inventoryAll
                                store.selectedItemID = item.id
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: item.category.icon)
                                        .font(.body)
                                        .foregroundStyle(Color.categoryColor(item.category))
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.body)
                                            .lineLimit(1)
                                        Text(item.frequencyDescription)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    let days = store.daysUntilDue(item)
                                    if days <= 30 {
                                        DueDateBadge(daysUntilDue: days)
                                    }
                                }
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 8).fill(.background))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator.opacity(0.2)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var seasonTitle: String {
        let month = Calendar.current.component(.month, from: .now)
        switch month {
        case 3...5: return "Spring Checklist"
        case 6...8: return "Summer Checklist"
        case 9...11: return "Fall Checklist"
        default: return "Winter Checklist"
        }
    }

    private var seasonIcon: String {
        let month = Calendar.current.component(.month, from: .now)
        switch month {
        case 3...5: return "leaf"
        case 6...8: return "sun.max"
        case 9...11: return "wind"
        default: return "snowflake"
        }
    }

    private var seasonalCategories: Set<MaintenanceCategory> {
        let month = Calendar.current.component(.month, from: .now)
        switch month {
        case 3...5: return [.exterior, .lawnAndGarden, .hvac, .plumbing]
        case 6...8: return [.lawnAndGarden, .exterior, .appliances]
        case 9...11: return [.exterior, .hvac, .safety]
        default: return [.hvac, .plumbing, .interior, .safety]
        }
    }

    private var seasonalSuggestions: [MaintenanceItem] {
        let relevant = seasonalCategories
        return store.activeItems
            .filter { relevant.contains($0.category) }
            .filter { store.daysUntilDue($0) <= 60 }
            .sorted { store.nextDueDate(for: $0) < store.nextDueDate(for: $1) }
            .prefix(4)
            .map { $0 }
    }

    // MARK: - Recent Activity

    private var recentActivity: some View {
        sectionView(title: "Recent Activity", icon: "book", tint: .upkeepGreen) {
            ForEach(store.recentLogEntries.prefix(4)) { entry in
                dashboardLogRow(entry)
            }
            if store.recentLogEntries.count > 4 {
                moreButton(count: store.recentLogEntries.count - 4, destination: .log)
            }
        }
    }

    // MARK: - Cost Section

    private var costSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar")
                    .font(.subheadline)
                    .foregroundStyle(.upkeepBrown)
                Text("Spending")
                    .font(.headline)
            }

            VStack(spacing: 12) {
                // Month comparison
                HStack(spacing: 16) {
                    monthCostCard(label: currentMonthName, cost: currentMonthCost)
                    monthCostCard(label: previousMonthName, cost: previousMonthCost)
                }

                // Category breakdown
                let breakdown = categoryBreakdown
                if !breakdown.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("By Category")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)

                        let maxCost = breakdown.map(\.cost).max() ?? 1
                        ForEach(breakdown, id: \.category) { item in
                            HStack(spacing: 8) {
                                Image(systemName: item.category.icon)
                                    .font(.caption)
                                    .foregroundStyle(Color.categoryColor(item.category))
                                    .frame(width: 16)

                                Text(item.category.label)
                                    .font(.caption)
                                    .frame(width: 80, alignment: .leading)

                                GeometryReader { geo in
                                    let width = max(4, geo.size.width * CGFloat(truncating: (item.cost / maxCost) as NSDecimalNumber))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.categoryColor(item.category).opacity(0.6))
                                        .frame(width: width)
                                }
                                .frame(height: 12)

                                Text(formatCost(item.cost))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 60, alignment: .trailing)
                            }
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.background))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator.opacity(0.2)))
                }
            }
        }
    }

    private func monthCostCard(label: String, cost: Decimal) -> some View {
        VStack(spacing: 4) {
            Text(formatCost(cost))
                .font(.title3.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: .now)
    }

    private var previousMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        let prev = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
        return formatter.string(from: prev)
    }

    private var currentMonthCost: Decimal {
        monthCost(for: .now)
    }

    private var previousMonthCost: Decimal {
        let prev = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
        return monthCost(for: prev)
    }

    private func monthCost(for date: Date) -> Decimal {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        return store.logEntries
            .filter {
                let c = cal.dateComponents([.year, .month], from: $0.completedDate)
                return c.year == comps.year && c.month == comps.month
            }
            .compactMap(\.cost)
            .reduce(Decimal.zero, +)
    }

    private struct CategoryCost {
        let category: MaintenanceCategory
        let cost: Decimal
    }

    private var categoryBreakdown: [CategoryCost] {
        var byCat: [MaintenanceCategory: Decimal] = [:]
        for entry in store.logEntries {
            if let cost = entry.cost, cost > 0 {
                byCat[entry.category, default: .zero] += cost
            }
        }
        return byCat.map { CategoryCost(category: $0.key, cost: $0.value) }
            .sorted { $0.cost > $1.cost }
            .prefix(6)
            .map { $0 }
    }

    private var totalCost30d: String {
        let total = store.recentLogEntries.compactMap(\.cost).reduce(Decimal.zero, +)
        return formatCost(total)
    }

    private func formatCost(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }

    // MARK: - Shared Helpers

    private func sectionView<Content: View>(title: String, icon: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.headline)
            }

            VStack(spacing: 1) {
                content()
            }
        }
    }

    private func dashboardLogRow(_ entry: LogEntry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: entry.category.icon)
                .font(.body)
                .foregroundStyle(Color.categoryColor(entry.category))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.body)
                    .lineLimit(1)
                Text(entry.completedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            CostText(cost: entry.cost)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.background))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator.opacity(0.2)))
    }

    private func moreButton(count: Int, destination: NavigationItem) -> some View {
        Button {
            store.navigation = destination
        } label: {
            Text("+ \(count) more")
                .font(.caption.weight(.medium))
                .foregroundStyle(.upkeepAmber)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(8)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "house")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.upkeepAmber.opacity(0.4))
            Text("Welcome to Upkeep")
                .font(.title2.weight(.semibold))
            Text("Add your home's maintenance items to start building rhythms")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
