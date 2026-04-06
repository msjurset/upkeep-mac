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
