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
        switch item.scheduleKind {
        case .oneTime:
            return item.startDate
        case .seasonal:
            if let window = item.seasonalWindow {
                return nextSeasonalDueDate(for: item, window: window)
            }
            return nextFrequencyDueDate(for: item)
        case .recurring:
            return nextFrequencyDueDate(for: item)
        }
    }

    func isOverdue(_ item: MaintenanceItem) -> Bool {
        guard item.isActive else { return false }
        if item.isSnoozed { return false }
        switch item.scheduleKind {
        case .oneTime:
            if lastCompletion(for: item.id) != nil { return false }
            return item.startDate < .now
        case .seasonal:
            if let window = item.seasonalWindow {
                return isSeasonalOverdue(item, window: window)
            }
            return nextFrequencyDueDate(for: item) < .now
        case .recurring:
            return nextFrequencyDueDate(for: item) < .now
        }
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

        // Streaks are meaningless for one-time items
        if item.isOneTime { return 0 }

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
        let r = resolveWindow(window)

        // Item didn't exist during the resolved window — show upcoming
        if item.startDate > r.end {
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: r.nextStart)).day ?? 0
            return .upcoming(daysUntil: days)
        }

        if item.skippedYear == r.startYear {
            return .skippedForYear
        }

        if let last = lastCompletion(for: item.id),
           last.completedDate >= r.start && last.completedDate <= r.end {
            return .doneForYear
        }

        if now < r.start {
            // We're before the next window — show countdown to it
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: r.nextStart)).day ?? 0
            return .upcoming(daysUntil: days)
        } else if now >= r.start && now <= r.end {
            return .inWindow
        } else {
            // Past window end without completion
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

    /// Finds the relevant window period for now.
    /// "Window year" = the year the window starts. For Nov–Jan, the 2025 window is Nov 15 2025 – Jan 15 2026.
    /// Returns (startYear, windowStart, windowEnd) for the current or most recent window,
    /// and (nextStartYear, nextWindowStart) for the upcoming one.
    private func resolveWindow(_ window: SeasonalWindow) -> (startYear: Int, start: Date, end: Date, nextStart: Date) {
        let cal = Calendar.current
        let now = Date.now
        let year = cal.component(.year, from: now)

        // Check if we're inside the current year's window
        let thisStart = window.startDate(in: year)
        let thisEnd = window.endDate(in: year)
        if now >= thisStart && now <= thisEnd {
            return (year, thisStart, thisEnd, window.startDate(in: year + 1))
        }

        // For year-spanning windows, check if we're in the tail of last year's window
        if window.spansYearBoundary {
            let prevStart = window.startDate(in: year - 1)
            let prevEnd = window.endDate(in: year - 1)  // This is in `year` since it spans
            if now >= prevStart && now <= prevEnd {
                return (year - 1, prevStart, prevEnd, thisStart)
            }
        }

        // We're between windows. Figure out if this year's window is upcoming or past.
        if now < thisStart {
            // This year's window is upcoming; the "last" window was the previous year's
            let prevStart = window.startDate(in: year - 1)
            let prevEnd = window.endDate(in: year - 1)
            return (year - 1, prevStart, prevEnd, thisStart)
        } else {
            // Past this year's window
            return (year, thisStart, thisEnd, window.startDate(in: year + 1))
        }
    }

    private func nextSeasonalDueDate(for item: MaintenanceItem, window: SeasonalWindow) -> Date {
        let r = resolveWindow(window)

        // Item didn't exist during this window — next due is the upcoming window
        if item.startDate > r.end { return r.nextStart }

        // Skipped this window's year
        if item.skippedYear == r.startYear { return r.nextStart }

        // Completed during this window
        if let last = lastCompletion(for: item.id),
           last.completedDate >= r.start && last.completedDate <= r.end {
            return r.nextStart
        }

        let now = Date.now
        // Before or in the window — due at window start
        if now <= r.end { return r.start }

        // Past window without completion — overdue, return end so daysUntilDue goes negative
        return r.end
    }

    private func isSeasonalOverdue(_ item: MaintenanceItem, window: SeasonalWindow) -> Bool {
        let r = resolveWindow(window)
        let now = Date.now

        // Item didn't exist during this window — can't be overdue for it
        if item.startDate > r.end { return false }

        if item.skippedYear == r.startYear { return false }

        if let last = lastCompletion(for: item.id),
           last.completedDate >= r.start && last.completedDate <= r.end {
            return false
        }

        return now > r.end
    }

    private func seasonalStreak(for item: MaintenanceItem, window: SeasonalWindow) -> Int {
        let r = resolveWindow(window)
        let entries = logEntries
            .filter { $0.itemID == item.id }
            .sorted { $0.completedDate > $1.completedDate }

        var streak = 0
        var checkYear = r.startYear

        // Don't count current window if it hasn't ended yet
        if Date.now <= r.end { checkYear -= 1 }

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
    case skippedForYear
}
