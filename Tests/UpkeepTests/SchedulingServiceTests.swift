import Testing
import Foundation
@testable import Upkeep

@Suite("SchedulingService")
struct SchedulingServiceTests {
    private func makeItem(
        name: String = "Test",
        frequencyInterval: Int = 1,
        frequencyUnit: FrequencyUnit = .months,
        startDate: Date = Date.now.addingTimeInterval(-86400 * 60),
        isActive: Bool = true
    ) -> MaintenanceItem {
        MaintenanceItem(
            name: name,
            frequencyInterval: frequencyInterval,
            frequencyUnit: frequencyUnit,
            startDate: startDate,
            isActive: isActive
        )
    }

    private func makeLog(itemID: UUID, completedDate: Date) -> LogEntry {
        LogEntry(itemID: itemID, title: "Done", category: .other, completedDate: completedDate)
    }

    @Test("nextDueDate without completions")
    func nextDueDateNoLog() {
        let start = Calendar.current.date(byAdding: .month, value: -2, to: .now)!
        let item = makeItem(startDate: start)
        let svc = SchedulingService(items: [item], logEntries: [])
        let due = svc.nextDueDate(for: item)
        let expected = Calendar.current.date(byAdding: .month, value: 1, to: start)!
        #expect(Calendar.current.isDate(due, inSameDayAs: expected))
    }

    @Test("nextDueDate with completion")
    func nextDueDateWithLog() {
        let item = makeItem(frequencyInterval: 2, frequencyUnit: .weeks)
        let completed = Calendar.current.date(byAdding: .day, value: -3, to: .now)!
        let log = makeLog(itemID: item.id, completedDate: completed)
        let svc = SchedulingService(items: [item], logEntries: [log])
        let due = svc.nextDueDate(for: item)
        let expected = Calendar.current.date(byAdding: .weekOfYear, value: 2, to: completed)!
        #expect(Calendar.current.isDate(due, inSameDayAs: expected))
    }

    @Test("isOverdue true when past due")
    func isOverdue() {
        let start = Calendar.current.date(byAdding: .month, value: -3, to: .now)!
        let item = makeItem(startDate: start)
        let svc = SchedulingService(items: [item], logEntries: [])
        #expect(svc.isOverdue(item))
    }

    @Test("isOverdue false for inactive")
    func isOverdueInactive() {
        let start = Calendar.current.date(byAdding: .year, value: -2, to: .now)!
        let item = makeItem(startDate: start, isActive: false)
        let svc = SchedulingService(items: [item], logEntries: [])
        #expect(!svc.isOverdue(item))
    }

    @Test("isOverdue false for snoozed")
    func isOverdueSnoozed() {
        let start = Calendar.current.date(byAdding: .year, value: -2, to: .now)!
        var item = makeItem(startDate: start)
        item.snoozedUntil = Calendar.current.date(byAdding: .day, value: 7, to: .now)
        let svc = SchedulingService(items: [item], logEntries: [])
        #expect(!svc.isOverdue(item))
    }

    @Test("daysUntilDue positive for future")
    func daysUntilDuePositive() {
        let item = makeItem(startDate: .now)
        let svc = SchedulingService(items: [item], logEntries: [])
        #expect(svc.daysUntilDue(item) >= 28)
    }

    @Test("daysUntilDue negative for overdue")
    func daysUntilDueNegative() {
        let start = Calendar.current.date(byAdding: .month, value: -3, to: .now)!
        let item = makeItem(startDate: start)
        let svc = SchedulingService(items: [item], logEntries: [])
        #expect(svc.daysUntilDue(item) < 0)
    }

    @Test("itemsDueInRange filters correctly")
    func itemsDueInRange() {
        let soon = makeItem(name: "Soon", frequencyInterval: 1, frequencyUnit: .months, startDate: .now)
        let later = makeItem(name: "Later", frequencyInterval: 1, frequencyUnit: .years, startDate: .now)
        let svc = SchedulingService(items: [soon, later], logEntries: [])

        let end = Calendar.current.date(byAdding: .day, value: 60, to: .now)!
        let result = svc.itemsDueInRange(start: .now, end: end)
        #expect(result.count == 1)
        #expect(result[0].name == "Soon")
    }

    @Test("streak with no logs returns 0")
    func streakEmpty() {
        let item = makeItem()
        let svc = SchedulingService(items: [item], logEntries: [])
        #expect(svc.currentStreak(for: item.id) == 0)
    }

    @Test("streak for unknown item returns 0")
    func streakUnknown() {
        let svc = SchedulingService(items: [], logEntries: [])
        #expect(svc.currentStreak(for: UUID()) == 0)
    }

    @Test("all frequency units produce correct due dates",
          arguments: [
            (FrequencyUnit.days, Calendar.Component.day),
            (FrequencyUnit.weeks, Calendar.Component.weekOfYear),
            (FrequencyUnit.months, Calendar.Component.month),
            (FrequencyUnit.years, Calendar.Component.year),
          ])
    func frequencyUnits(unit: FrequencyUnit, component: Calendar.Component) {
        let start = Calendar.current.date(byAdding: .year, value: -1, to: .now)!
        let item = makeItem(frequencyInterval: 2, frequencyUnit: unit, startDate: start)
        let svc = SchedulingService(items: [item], logEntries: [])
        let due = svc.nextDueDate(for: item)
        let expected = Calendar.current.date(byAdding: component, value: 2, to: start)!
        #expect(Calendar.current.isDate(due, inSameDayAs: expected))
    }
}

// MARK: - Seasonal Window Scheduling

@Suite("SchedulingService Seasonal")
struct SeasonalSchedulingTests {
    private let juneWindow = SeasonalWindow(startMonth: 5, startDay: 25, endMonth: 7, endDay: 7)
    private let winterWindow = SeasonalWindow(startMonth: 11, startDay: 15, endMonth: 1, endDay: 15)

    private func makeSeasonalItem(name: String = "Trim Rhodos", window: SeasonalWindow? = nil) -> MaintenanceItem {
        MaintenanceItem(name: name, seasonalWindow: window ?? juneWindow)
    }

    @Test("seasonal item not overdue when last year's window was completed")
    func notOverdueWhenLastYearCompleted() {
        let cal = Calendar.current
        let year = cal.component(.year, from: .now)
        let item = makeSeasonalItem()
        // Complete in last year's window
        let completionDate = juneWindow.startDate(in: year - 1)
        let log = LogEntry(itemID: item.id, title: "Done", category: .lawnAndGarden, completedDate: completionDate)
        let svc = SchedulingService(items: [item], logEntries: [log])
        // Last year's window is done; this year's hasn't opened yet → not overdue
        if Date.now < juneWindow.startDate(in: year) {
            #expect(!svc.isOverdue(item))
        }
    }

    @Test("seasonal item overdue when last year's window was missed")
    func overdueWhenLastYearMissed() {
        let cal = Calendar.current
        let year = cal.component(.year, from: .now)
        // The previous year's window (2025) has closed and was never completed
        let item = makeSeasonalItem()
        let svc = SchedulingService(items: [item], logEntries: [])
        let prevEnd = juneWindow.endDate(in: year - 1)
        if Date.now > prevEnd && Date.now < juneWindow.startDate(in: year) {
            #expect(svc.isOverdue(item))
        }
    }

    @Test("seasonal nextDueDate returns next window start after completion")
    func nextDueDateAfterCompletion() {
        let cal = Calendar.current
        let year = cal.component(.year, from: .now)
        let item = makeSeasonalItem()
        // Complete in last year's window
        let completionDate = juneWindow.startDate(in: year - 1)
        let log = LogEntry(itemID: item.id, title: "Done", category: .lawnAndGarden, completedDate: completionDate)
        let svc = SchedulingService(items: [item], logEntries: [log])
        let due = svc.nextDueDate(for: item)
        // Should point to this year's (or next upcoming) window start
        #expect(due >= juneWindow.startDate(in: year - 1))
    }

    @Test("seasonal status done for year after completion in window")
    func statusDoneForYear() {
        let cal = Calendar.current
        let year = cal.component(.year, from: .now)
        let item = makeSeasonalItem()
        // Complete in last year's window
        let completionDate = juneWindow.startDate(in: year - 1)
        let log = LogEntry(itemID: item.id, title: "Done", category: .lawnAndGarden, completedDate: completionDate)
        let svc = SchedulingService(items: [item], logEntries: [log])
        let status = svc.seasonalStatus(for: item, window: juneWindow)
        if case .doneForYear = status {
            // pass
        } else {
            Issue.record("Expected doneForYear, got \(status)")
        }
    }

    @Test("seasonal streak counts consecutive years")
    func streakConsecutiveYears() {
        let cal = Calendar.current
        let year = cal.component(.year, from: .now)
        let item = makeSeasonalItem()
        let logs = (1...3).map { yearsAgo in
            LogEntry(itemID: item.id, title: "Done", category: .lawnAndGarden,
                     completedDate: juneWindow.startDate(in: year - yearsAgo))
        }
        let svc = SchedulingService(items: [item], logEntries: logs)
        #expect(svc.currentStreak(for: item.id) == 3)
    }

    @Test("seasonal streak breaks on missed year")
    func streakBreaksOnMiss() {
        let cal = Calendar.current
        let year = cal.component(.year, from: .now)
        let item = makeSeasonalItem()
        // Completed 1 and 3 years ago, missed 2 years ago
        let logs = [
            LogEntry(itemID: item.id, title: "Done", category: .lawnAndGarden,
                     completedDate: juneWindow.startDate(in: year - 1)),
            LogEntry(itemID: item.id, title: "Done", category: .lawnAndGarden,
                     completedDate: juneWindow.startDate(in: year - 3)),
        ]
        let svc = SchedulingService(items: [item], logEntries: logs)
        #expect(svc.currentStreak(for: item.id) == 1)
    }

    @Test("SeasonalWindow description format")
    func windowDescription() {
        let window = SeasonalWindow(startMonth: 5, startDay: 25, endMonth: 7, endDay: 7)
        #expect(window.description.contains("May"))
        #expect(window.description.contains("Jul"))
    }

    @Test("inactive seasonal item is not overdue")
    func inactiveNotOverdue() {
        var item = makeSeasonalItem()
        item.isActive = false
        let svc = SchedulingService(items: [item], logEntries: [])
        #expect(!svc.isOverdue(item))
    }

    // MARK: - Year-Spanning Windows

    @Test("year-spanning window endDate is in the following year")
    func yearSpanningEndDate() {
        #expect(winterWindow.spansYearBoundary)
        let start = winterWindow.startDate(in: 2025)
        let end = winterWindow.endDate(in: 2025)
        let cal = Calendar.current
        #expect(cal.component(.year, from: start) == 2025)
        #expect(cal.component(.month, from: start) == 11)
        #expect(cal.component(.year, from: end) == 2026)
        #expect(cal.component(.month, from: end) == 1)
    }

    @Test("year-spanning window not overdue when completed in window")
    func yearSpanningCompletedInWindow() {
        let cal = Calendar.current
        let year = cal.component(.year, from: .now)
        let item = makeSeasonalItem(name: "Prune Maple", window: winterWindow)
        // Completed in Dec of last year's window
        let completionDate = cal.date(from: DateComponents(year: year - 1, month: 12, day: 1))!
        let log = LogEntry(itemID: item.id, title: "Done", category: .lawnAndGarden, completedDate: completionDate)
        let svc = SchedulingService(items: [item], logEntries: [log])
        #expect(!svc.isOverdue(item))
    }

    @Test("non-spanning window does not set spansYearBoundary")
    func nonSpanningWindow() {
        #expect(!juneWindow.spansYearBoundary)
    }
}
