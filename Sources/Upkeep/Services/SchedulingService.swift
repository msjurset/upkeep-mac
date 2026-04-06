import Foundation

struct SchedulingService: Sendable {
    let items: [MaintenanceItem]
    let logEntries: [LogEntry]

    func lastCompletion(for itemID: UUID) -> LogEntry? {
        logEntries
            .filter { $0.itemID == itemID }
            .sorted { $0.completedDate > $1.completedDate }
            .first
    }

    func nextDueDate(for item: MaintenanceItem) -> Date {
        let lastDate = lastCompletion(for: item.id)?.completedDate ?? item.startDate
        let component: Calendar.Component = switch item.frequencyUnit {
        case .days: .day
        case .weeks: .weekOfYear
        case .months: .month
        case .years: .year
        }
        return Calendar.current.date(byAdding: component, value: item.frequencyInterval, to: lastDate) ?? lastDate
    }

    func isOverdue(_ item: MaintenanceItem) -> Bool {
        guard item.isActive else { return false }
        if item.isSnoozed { return false }
        return nextDueDate(for: item) < .now
    }

    func daysUntilDue(_ item: MaintenanceItem) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let end = cal.startOfDay(for: nextDueDate(for: item))
        return cal.dateComponents([.day], from: start, to: end).day ?? 0
    }

    func itemsDueInRange(start: Date, end: Date) -> [MaintenanceItem] {
        let active = items.filter(\.isActive)
        return active.filter {
            let due = nextDueDate(for: $0)
            return due >= start && due < end
        }.sorted { nextDueDate(for: $0) < nextDueDate(for: $1) }
    }

    func currentStreak(for itemID: UUID) -> Int {
        guard let item = items.first(where: { $0.id == itemID }) else { return 0 }
        let entries = logEntries
            .filter { $0.itemID == itemID }
            .sorted { $0.completedDate > $1.completedDate }
        guard !entries.isEmpty else { return 0 }

        let cal = Calendar.current
        let component: Calendar.Component = switch item.frequencyUnit {
        case .days: .day
        case .weeks: .weekOfYear
        case .months: .month
        case .years: .year
        }

        var streak = 0
        for entry in entries {
            let gracePeriod = cal.date(byAdding: component, value: item.frequencyInterval, to: entry.completedDate) ?? entry.completedDate
            if entry.completedDate <= gracePeriod {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }
}
