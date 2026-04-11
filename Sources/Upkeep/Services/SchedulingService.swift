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
        if let window = item.seasonalWindow {
            return nextSeasonalDueDate(for: item, window: window)
        }
        return nextFrequencyDueDate(for: item)
    }

    func isOverdue(_ item: MaintenanceItem) -> Bool {
        guard item.isActive else { return false }
        if item.isSnoozed { return false }
        if let window = item.seasonalWindow {
            return isSeasonalOverdue(item, window: window)
        }
        return nextFrequencyDueDate(for: item) < .now
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

        // For seasonal items, count consecutive years with a completion inside the window
        if let window = item.seasonalWindow {
            return seasonalStreak(for: item, window: window)
        }

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

    /// Status description for seasonal items: "In window", "Window opens in X days", "Overdue", "Done for year"
    func seasonalStatus(for item: MaintenanceItem, window: SeasonalWindow) -> SeasonalItemStatus {
        let cal = Calendar.current
        let now = Date.now
        let year = cal.component(.year, from: now)
        let windowStart = window.startDate(in: year)
        let windowEnd = window.endDate(in: year)

        // Check if completed this year's window
        if let last = lastCompletion(for: item.id) {
            let lastYear = cal.component(.year, from: last.completedDate)
            if lastYear == year && last.completedDate >= windowStart {
                return .doneForYear
            }
        }

        if now < windowStart {
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: windowStart)).day ?? 0
            return .upcoming(daysUntil: days)
        } else if now <= windowEnd {
            return .inWindow
        } else {
            return .overdue
        }
    }

    // MARK: - Private: Frequency-Based

    private func nextFrequencyDueDate(for item: MaintenanceItem) -> Date {
        let lastDate = lastCompletion(for: item.id)?.completedDate ?? item.startDate
        let component: Calendar.Component = switch item.frequencyUnit {
        case .days: .day
        case .weeks: .weekOfYear
        case .months: .month
        case .years: .year
        }
        return Calendar.current.date(byAdding: component, value: item.frequencyInterval, to: lastDate) ?? lastDate
    }

    // MARK: - Private: Seasonal

    private func nextSeasonalDueDate(for item: MaintenanceItem, window: SeasonalWindow) -> Date {
        let cal = Calendar.current
        let now = Date.now
        let year = cal.component(.year, from: now)
        let windowStart = window.startDate(in: year)
        let windowEnd = window.endDate(in: year)

        // If completed this year within the window, next due is next year's window start
        if let last = lastCompletion(for: item.id) {
            let lastYear = cal.component(.year, from: last.completedDate)
            if lastYear == year && last.completedDate >= windowStart {
                return window.startDate(in: year + 1)
            }
        }

        // If before or in this year's window, due date is window start
        if now <= windowEnd {
            return windowStart
        }

        // Past this year's window without completion — still due (overdue)
        // Return window end so daysUntilDue goes negative
        return windowEnd
    }

    private func isSeasonalOverdue(_ item: MaintenanceItem, window: SeasonalWindow) -> Bool {
        let cal = Calendar.current
        let now = Date.now
        let year = cal.component(.year, from: now)
        let windowStart = window.startDate(in: year)
        let windowEnd = window.endDate(in: year)

        // If completed this year in/after window start, not overdue
        if let last = lastCompletion(for: item.id) {
            let lastYear = cal.component(.year, from: last.completedDate)
            if lastYear == year && last.completedDate >= windowStart {
                return false
            }
        }

        // Overdue if past the window end
        return now > windowEnd
    }

    private func seasonalStreak(for item: MaintenanceItem, window: SeasonalWindow) -> Int {
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: .now)
        let entries = logEntries
            .filter { $0.itemID == item.id }
            .sorted { $0.completedDate > $1.completedDate }

        var streak = 0
        var checkYear = currentYear

        // Don't count current year if window hasn't ended yet
        let windowEnd = window.endDate(in: currentYear)
        if Date.now <= windowEnd {
            checkYear -= 1
        }

        for year in stride(from: checkYear, through: checkYear - 10, by: -1) {
            let yearStart = window.startDate(in: year)
            let yearEnd = window.endDate(in: year)
            let hasCompletion = entries.contains { entry in
                entry.completedDate >= yearStart && entry.completedDate <= yearEnd
            }
            if hasCompletion {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }
}

enum SeasonalItemStatus {
    case upcoming(daysUntil: Int)
    case inWindow
    case overdue
    case doneForYear
}
