import Foundation

struct SchedulingService: Sendable {
    let items: [MaintenanceItem]
    let logEntries: [LogEntry]

    func lastCompletion(for itemID: UUID) -> LogEntry? {
        logEntries
            .filter { $0.itemID == itemID && $0.countsAsCompletion }
            .sorted { $0.completedDate > $1.completedDate }
            .first
    }

    func nextDueDate(for item: MaintenanceItem) -> Date {
        // Items with sub-events: earliest upcoming sub-event drives the
        // "next due" — the item-level schedule becomes a fallback only when
        // subEvents is empty.
        if !item.subEvents.isEmpty {
            return item.subEvents
                .map { nextDueDate(for: item, subEvent: $0) }
                .min() ?? .distantFuture
        }
        switch item.scheduleKind {
        case .idea:
            // Ideas have no due date; far-future sentinel keeps them sorted last in "Due" mode.
            return .distantFuture
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
        if !item.subEvents.isEmpty {
            return item.subEvents.contains { isOverdue(item, subEvent: $0) }
        }
        switch item.scheduleKind {
        case .idea:
            return false
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

        // Streaks are meaningless for one-time items and ideas
        if item.isOneTime || item.isIdea { return 0 }

        // For seasonal items, count consecutive years with a completion inside the window
        if let window = item.seasonalWindow {
            return seasonalStreak(for: item, window: window)
        }

        let entries = logEntries
            .filter { $0.itemID == itemID && $0.countsAsCompletion }
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
        // Before the window — due at window start (countdown to opening)
        if now < r.start { return r.start }

        // Inside or past the window — due at window end.
        // While inside: daysUntilDue counts down to window close.
        // When past without completion: daysUntilDue goes negative → overdue.
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
            .filter { $0.itemID == item.id && $0.countsAsCompletion }
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

/// Represents a single dated entry on the calendar/upcoming list.
/// For items without sub-events, one entry per item.
/// For items with sub-events, one entry per sub-event.
struct ScheduleEntry: Identifiable, Hashable, Sendable {
    let item: MaintenanceItem
    let subEvent: SubEvent?
    let dueDate: Date
    let isOverdue: Bool

    var id: String {
        if let sub = subEvent {
            return "\(item.id.uuidString)/\(sub.id.uuidString)"
        }
        return item.id.uuidString
    }

    /// Display name. For sub-events, prefixes with the parent item's name
    /// for context (e.g., "Sunday Lawn / Dandelion Doom"). Falls back to the
    /// item name if the sub-event name is empty.
    var displayName: String {
        guard let sub = subEvent, !sub.name.isEmpty else { return item.name }
        return "\(item.name) / \(sub.name)"
    }
}

extension SchedulingService {
    /// Returns one entry per active item — or one entry per sub-event for
    /// items that have sub-events — whose `dueDate` falls in `[start, end)`.
    /// Sorted by due date.
    func entriesDueInRange(start: Date, end: Date) -> [ScheduleEntry] {
        var out: [ScheduleEntry] = []
        for item in items where item.isActive {
            if item.subEvents.isEmpty {
                let due = nextDueDate(for: item)
                if due >= start && due < end {
                    out.append(ScheduleEntry(
                        item: item, subEvent: nil,
                        dueDate: due, isOverdue: isOverdue(item)
                    ))
                }
            } else {
                for sub in item.subEvents {
                    let due = nextDueDate(for: item, subEvent: sub)
                    if due >= start && due < end {
                        out.append(ScheduleEntry(
                            item: item, subEvent: sub,
                            dueDate: due, isOverdue: isOverdue(item, subEvent: sub)
                        ))
                    }
                }
            }
        }
        return out.sorted { $0.dueDate < $1.dueDate }
    }

    func daysUntilSubEvent(item: MaintenanceItem, sub: SubEvent) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let end = cal.startOfDay(for: nextDueDate(for: item, subEvent: sub))
        return cal.dateComponents([.day], from: start, to: end).day ?? 0
    }

    func nextDueDate(for item: MaintenanceItem, subEvent sub: SubEvent) -> Date {
        if sub.isSnoozed, let until = sub.snoozedUntil { return until }

        if let window = sub.seasonalWindow {
            let cal = Calendar.current
            let now = Date.now
            let year = cal.component(.year, from: now)
            let thisStart = window.startDate(in: year)
            let thisEnd = window.endDate(in: year)
            let nextYearStart = window.startDate(in: year + 1)

            // Skipped this year (item-level or sub-event-level)
            if item.skippedYear == year || sub.skippedYear == year {
                return nextYearStart
            }

            // Has a log entry counting as this cycle's completion?
            if isCompletedForCurrentPeriod(item: item, subEvent: sub) {
                return nextYearStart
            }

            if now < thisStart { return thisStart }
            // Inside the window or past it without completion. Returning
            // thisEnd lets daysUntilDue count down while inside, and goes
            // negative once past — which matches the seasonal-item semantic.
            return thisEnd
        }

        if let due = sub.dueDate { return due }

        return .distantFuture
    }

    /// True when there is a log entry recording completion of this sub-event
    /// for the current period. For seasonal sub-events the period is "the last
    /// 12 months" — pragmatic so logs entered before/after the strict window
    /// still credit the cycle. For one-time sub-events any log counts.
    func isCompletedForCurrentPeriod(item: MaintenanceItem, subEvent sub: SubEvent) -> Bool {
        if sub.seasonalWindow != nil {
            let cutoff = Calendar.current.date(byAdding: .day, value: -365, to: .now) ?? .distantPast
            return logEntries.contains { entry in
                entry.itemID == item.id
                    && entry.subEventID == sub.id
                    && entry.countsAsCompletion
                    && entry.completedDate >= cutoff
            }
        }
        if sub.dueDate != nil {
            return logEntries.contains { entry in
                entry.itemID == item.id && entry.subEventID == sub.id && entry.countsAsCompletion
            }
        }
        return false
    }

    func isOverdue(_ item: MaintenanceItem, subEvent sub: SubEvent) -> Bool {
        guard item.isActive else { return false }
        if item.isSnoozed || sub.isSnoozed { return false }

        if let window = sub.seasonalWindow {
            let cal = Calendar.current
            let year = cal.component(.year, from: .now)
            let thisEnd = window.endDate(in: year)

            if item.skippedYear == year || sub.skippedYear == year { return false }
            if isCompletedForCurrentPeriod(item: item, subEvent: sub) { return false }
            return .now > thisEnd
        }

        if sub.dueDate != nil {
            if isCompletedForCurrentPeriod(item: item, subEvent: sub) { return false }
            return (sub.dueDate ?? .distantFuture) < .now
        }

        return false
    }
}
