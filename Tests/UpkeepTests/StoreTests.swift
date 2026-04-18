import Testing
import Foundation
@testable import Upkeep

// MARK: - Helpers

@MainActor
private func makeStore() -> UpkeepStore {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let persistence = Persistence(baseURL: tempDir)
    return UpkeepStore(persistence: persistence)
}

private func makeItem(
    name: String = "Test",
    frequencyInterval: Int = 1,
    frequencyUnit: FrequencyUnit = .months,
    startDate: Date = Date.now.addingTimeInterval(-86400 * 60),
    vendorID: UUID? = nil,
    supply: Supply? = nil,
    tags: [String] = [],
    isActive: Bool = true
) -> MaintenanceItem {
    MaintenanceItem(
        name: name,
        frequencyInterval: frequencyInterval,
        frequencyUnit: frequencyUnit,
        startDate: startDate,
        vendorID: vendorID,
        supply: supply,
        tags: tags,
        isActive: isActive
    )
}

private func makeLog(
    itemID: UUID? = nil,
    completedDate: Date = .now,
    cost: Decimal? = nil
) -> LogEntry {
    LogEntry(itemID: itemID, title: "Test", category: .other, completedDate: completedDate, cost: cost)
}

// MARK: - Scheduling

@Suite("UpkeepStore Scheduling")
struct SchedulingTests {
    @Test("nextDueDate with no completions uses startDate + frequency")
    @MainActor func nextDueDateNoCompletions() {
        let store = makeStore()
        let start = Calendar.current.date(byAdding: .month, value: -2, to: .now)!
        let item = makeItem(frequencyInterval: 1, frequencyUnit: .months, startDate: start)
        store.items = [item]

        let due = store.nextDueDate(for: item)
        let expected = Calendar.current.date(byAdding: .month, value: 1, to: start)!
        #expect(Calendar.current.isDate(due, inSameDayAs: expected))
    }

    @Test("nextDueDate uses last completion date")
    @MainActor func nextDueDateWithCompletion() {
        let store = makeStore()
        let item = makeItem(frequencyInterval: 3, frequencyUnit: .months)
        let completionDate = Calendar.current.date(byAdding: .day, value: -10, to: .now)!
        let log = makeLog(itemID: item.id, completedDate: completionDate)
        store.items = [item]
        store.logEntries = [log]

        let due = store.nextDueDate(for: item)
        let expected = Calendar.current.date(byAdding: .month, value: 3, to: completionDate)!
        #expect(Calendar.current.isDate(due, inSameDayAs: expected))
    }

    @Test("nextDueDate with different frequency units",
          arguments: [
            (FrequencyUnit.days, Calendar.Component.day),
            (FrequencyUnit.weeks, Calendar.Component.weekOfYear),
            (FrequencyUnit.months, Calendar.Component.month),
            (FrequencyUnit.years, Calendar.Component.year),
          ])
    @MainActor func nextDueDateFrequencyUnits(unit: FrequencyUnit, component: Calendar.Component) {
        let store = makeStore()
        let start = Calendar.current.date(byAdding: .year, value: -1, to: .now)!
        let item = makeItem(frequencyInterval: 2, frequencyUnit: unit, startDate: start)
        store.items = [item]

        let due = store.nextDueDate(for: item)
        let expected = Calendar.current.date(byAdding: component, value: 2, to: start)!
        #expect(Calendar.current.isDate(due, inSameDayAs: expected))
    }

    @Test("isOverdue returns true when past due")
    @MainActor func isOverdueTrue() {
        let store = makeStore()
        let start = Calendar.current.date(byAdding: .month, value: -3, to: .now)!
        let item = makeItem(frequencyInterval: 1, frequencyUnit: .months, startDate: start)
        store.items = [item]
        // Due 1 month after start = 2 months ago → overdue
        #expect(store.isOverdue(item))
    }

    @Test("isOverdue returns false when not yet due")
    @MainActor func isOverdueFalse() {
        let store = makeStore()
        let item = makeItem(frequencyInterval: 1, frequencyUnit: .months, startDate: .now)
        store.items = [item]
        // Due 1 month from now → not overdue
        #expect(!store.isOverdue(item))
    }

    @Test("isOverdue returns false for inactive items")
    @MainActor func isOverdueInactive() {
        let store = makeStore()
        let start = Calendar.current.date(byAdding: .year, value: -2, to: .now)!
        let item = makeItem(startDate: start, isActive: false)
        store.items = [item]
        #expect(!store.isOverdue(item))
    }

    @Test("isOverdue returns false for snoozed items")
    @MainActor func isOverdueSnoozed() {
        let store = makeStore()
        let start = Calendar.current.date(byAdding: .year, value: -2, to: .now)!
        var item = makeItem(startDate: start)
        item.snoozedUntil = Calendar.current.date(byAdding: .day, value: 7, to: .now)
        store.items = [item]
        #expect(!store.isOverdue(item))
    }

    @Test("daysUntilDue calculates correctly")
    @MainActor func daysUntilDue() {
        let store = makeStore()
        let item = makeItem(frequencyInterval: 1, frequencyUnit: .months, startDate: .now)
        store.items = [item]
        let days = store.daysUntilDue(item)
        // Due in ~30 days from now
        #expect(days >= 28 && days <= 31)
    }

    @Test("daysUntilDue negative when overdue")
    @MainActor func daysUntilDueNegative() {
        let store = makeStore()
        let start = Calendar.current.date(byAdding: .month, value: -3, to: .now)!
        let item = makeItem(frequencyInterval: 1, frequencyUnit: .months, startDate: start)
        store.items = [item]
        #expect(store.daysUntilDue(item) < 0)
    }
}

// MARK: - Filtering

@Suite("UpkeepStore Filtering")
struct FilteringTests {
    @Test("activeItems excludes inactive")
    @MainActor func activeItemsFilter() {
        let store = makeStore()
        store.items = [
            makeItem(name: "Active", isActive: true),
            makeItem(name: "Inactive", isActive: false),
        ]
        #expect(store.activeItems.count == 1)
        #expect(store.activeItems[0].name == "Active")
    }

    @Test("overdueItems sorted by due date")
    @MainActor func overdueItemsSorted() {
        let store = makeStore()
        let older = Calendar.current.date(byAdding: .month, value: -6, to: .now)!
        let newer = Calendar.current.date(byAdding: .month, value: -3, to: .now)!
        store.items = [
            makeItem(name: "Newer", startDate: newer),
            makeItem(name: "Older", startDate: older),
        ]
        let overdue = store.overdueItems
        #expect(overdue.count == 2)
        #expect(overdue[0].name == "Older")
    }

    @Test("upcomingItems excludes overdue")
    @MainActor func upcomingExcludesOverdue() {
        let store = makeStore()
        let pastStart = Calendar.current.date(byAdding: .month, value: -3, to: .now)!
        store.items = [
            makeItem(name: "Overdue", startDate: pastStart),
            makeItem(name: "Upcoming", startDate: .now),
        ]
        let upcoming = store.upcomingItems
        #expect(upcoming.count == 1)
        #expect(upcoming[0].name == "Upcoming")
    }

    @Test("filteredActiveItems with text search")
    @MainActor func filteredByText() {
        let store = makeStore()
        store.items = [
            makeItem(name: "Change HVAC filter"),
            makeItem(name: "Clean gutters"),
        ]
        store.searchQuery = "hvac"
        #expect(store.filteredActiveItems.count == 1)
        #expect(store.filteredActiveItems[0].name == "Change HVAC filter")
    }

    @Test("filteredActiveItems with tag search")
    @MainActor func filteredByTag() {
        let store = makeStore()
        store.items = [
            makeItem(name: "A", tags: ["spring", "exterior"]),
            makeItem(name: "B", tags: ["winter"]),
            makeItem(name: "C", tags: ["spring"]),
        ]
        store.searchQuery = "tag:spring"
        #expect(store.filteredActiveItems.count == 2)
    }

    @Test("filteredActiveItems with tag + text search")
    @MainActor func filteredByTagAndText() {
        let store = makeStore()
        store.items = [
            makeItem(name: "Clean gutters", tags: ["spring"]),
            makeItem(name: "Plant flowers", tags: ["spring"]),
            makeItem(name: "Winterize pipes", tags: ["winter"]),
        ]
        store.searchQuery = "tag:spring gutters"
        #expect(store.filteredActiveItems.count == 1)
        #expect(store.filteredActiveItems[0].name == "Clean gutters")
    }

    @Test("allTags collects unique sorted tags")
    @MainActor func allTagsUniqueSorted() {
        let store = makeStore()
        store.items = [
            makeItem(name: "A", tags: ["winter", "exterior"]),
            makeItem(name: "B", tags: ["exterior", "spring"]),
        ]
        #expect(store.allTags == ["exterior", "spring", "winter"])
    }

    @Test("lowStockItems filters by supply.needsReorder")
    @MainActor func lowStockFilter() {
        let store = makeStore()
        store.items = [
            makeItem(name: "A", supply: Supply(stockOnHand: 0, quantityPerUse: 1)),
            makeItem(name: "B", supply: Supply(stockOnHand: 10, quantityPerUse: 1)),
            makeItem(name: "C"),
        ]
        #expect(store.lowStockItems.count == 1)
        #expect(store.lowStockItems[0].name == "A")
    }

    @Test("recentLogEntries within 30 days")
    @MainActor func recentLogEntries() {
        let store = makeStore()
        let recent = Date.now.addingTimeInterval(-86400 * 5)
        let old = Date.now.addingTimeInterval(-86400 * 60)
        store.logEntries = [
            makeLog(completedDate: recent),
            makeLog(completedDate: old),
        ]
        #expect(store.recentLogEntries.count == 1)
    }

    @Test("itemsDueInRange returns items in window")
    @MainActor func itemsDueInRange() {
        let store = makeStore()
        let cal = Calendar.current
        // Item due in ~30 days
        let item1 = makeItem(name: "Soon", frequencyInterval: 1, frequencyUnit: .months, startDate: .now)
        // Item due in ~365 days
        let item2 = makeItem(name: "Later", frequencyInterval: 1, frequencyUnit: .years, startDate: .now)
        store.items = [item1, item2]

        let start = Date.now
        let end = cal.date(byAdding: .day, value: 60, to: start)!
        let result = store.itemsDueInRange(start: start, end: end)
        #expect(result.count == 1)
        #expect(result[0].name == "Soon")
    }

    @Test("pendingFollowUps filters items with incomplete follow-ups")
    @MainActor func pendingFollowUps() {
        let store = makeStore()
        var itemWithPending = makeItem(name: "Has pending")
        itemWithPending.followUps = [FollowUp(title: "Do something")]
        var itemAllDone = makeItem(name: "All done")
        var doneFollowUp = FollowUp(title: "Done")
        doneFollowUp.isDone = true
        itemAllDone.followUps = [doneFollowUp]
        let itemNone = makeItem(name: "No follow-ups")

        store.items = [itemWithPending, itemAllDone, itemNone]
        #expect(store.pendingFollowUps.count == 1)
        #expect(store.pendingFollowUps[0].name == "Has pending")
    }
}

// MARK: - Streaks

@Suite("UpkeepStore Streaks")
struct StreakTests {
    @Test("streak counts consecutive on-time completions")
    @MainActor func streakCount() {
        let store = makeStore()
        let item = makeItem(name: "Monthly", frequencyInterval: 1, frequencyUnit: .months)
        let cal = Calendar.current

        // 3 completions, each roughly a month apart (all on-time)
        let log1 = makeLog(itemID: item.id, completedDate: cal.date(byAdding: .day, value: -10, to: .now)!)
        let log2 = makeLog(itemID: item.id, completedDate: cal.date(byAdding: .day, value: -40, to: .now)!)
        let log3 = makeLog(itemID: item.id, completedDate: cal.date(byAdding: .day, value: -70, to: .now)!)

        store.items = [item]
        store.logEntries = [log1, log2, log3]

        #expect(store.currentStreak(for: item.id) >= 2)
    }

    @Test("streak is 0 with no completions")
    @MainActor func streakNoCompletions() {
        let store = makeStore()
        let item = makeItem()
        store.items = [item]
        #expect(store.currentStreak(for: item.id) == 0)
    }

    @Test("streak is 0 for unknown item")
    @MainActor func streakUnknownItem() {
        let store = makeStore()
        #expect(store.currentStreak(for: UUID()) == 0)
    }
}

// MARK: - Queries

@Suite("UpkeepStore Queries")
struct QueryTests {
    @Test("logEntries for item filtered and sorted")
    @MainActor func logEntriesForItem() {
        let store = makeStore()
        let itemID = UUID()
        let older = makeLog(itemID: itemID, completedDate: .now.addingTimeInterval(-86400))
        let newer = makeLog(itemID: itemID, completedDate: .now)
        let other = makeLog(itemID: UUID(), completedDate: .now)
        store.logEntries = [older, newer, other]

        let result = store.logEntries(for: itemID)
        #expect(result.count == 2)
        #expect(result[0].completedDate > result[1].completedDate)
    }

    @Test("items for vendor filtered")
    @MainActor func itemsForVendor() {
        let store = makeStore()
        let vendorID = UUID()
        store.items = [
            makeItem(name: "A", vendorID: vendorID),
            makeItem(name: "B", vendorID: vendorID),
            makeItem(name: "C"),
        ]
        #expect(store.items(for: vendorID).count == 2)
    }

    @Test("vendor for item lookup")
    @MainActor func vendorForItem() {
        let store = makeStore()
        let vendor = Vendor(name: "Bob")
        let item = makeItem(vendorID: vendor.id)
        store.items = [item]
        store.vendors = [vendor]
        #expect(store.vendor(for: item)?.name == "Bob")
    }

    @Test("vendor for item returns nil when no vendor")
    @MainActor func vendorForItemNil() {
        let store = makeStore()
        let item = makeItem()
        store.items = [item]
        #expect(store.vendor(for: item) == nil)
    }

    @Test("onTrackCount excludes overdue")
    @MainActor func onTrackCount() {
        let store = makeStore()
        let pastStart = Calendar.current.date(byAdding: .month, value: -3, to: .now)!
        store.items = [
            makeItem(name: "Overdue", startDate: pastStart),
            makeItem(name: "OnTrack", startDate: .now),
        ]
        #expect(store.onTrackCount == 1)
    }
}

// MARK: - Sorting

@Suite("UpkeepStore Sorting")
struct SortingTests {
    @Test("nameAZ sorts alphabetically")
    @MainActor func sortNameAZ() {
        let store = makeStore()
        store.items = [makeItem(name: "Charlie"), makeItem(name: "Alpha"), makeItem(name: "Bravo")]
        store.sortMode = .nameAZ
        let sorted = store.applyingSort(store.items)
        #expect(sorted.map(\.name) == ["Alpha", "Bravo", "Charlie"])
    }

    @Test("nameZA reverses alphabetical")
    @MainActor func sortNameZA() {
        let store = makeStore()
        store.items = [makeItem(name: "Alpha"), makeItem(name: "Charlie"), makeItem(name: "Bravo")]
        store.sortMode = .nameZA
        let sorted = store.applyingSort(store.items)
        #expect(sorted.map(\.name) == ["Charlie", "Bravo", "Alpha"])
    }

    @Test("priority puts critical first")
    @MainActor func sortPriority() {
        let store = makeStore()
        var high = makeItem(name: "High"); high.priority = .high
        var low = makeItem(name: "Low"); low.priority = .low
        var critical = makeItem(name: "Critical"); critical.priority = .critical
        store.items = [low, high, critical]
        store.sortMode = .priority
        let sorted = store.applyingSort(store.items)
        #expect(sorted.map(\.name) == ["Critical", "High", "Low"])
    }

    @Test("dueSoonest sorts by next due ascending")
    @MainActor func sortDueSoonest() {
        let store = makeStore()
        let soon = makeItem(name: "Soon", frequencyInterval: 1, frequencyUnit: .months, startDate: .now)
        let later = makeItem(name: "Later", frequencyInterval: 1, frequencyUnit: .years, startDate: .now)
        store.items = [later, soon]
        store.sortMode = .dueSoonest
        let sorted = store.applyingSort(store.items)
        #expect(sorted.map(\.name) == ["Soon", "Later"])
    }

    @Test("cycleSortMode advances through all cases")
    @MainActor func cycle() {
        let store = makeStore()
        store.sortMode = .dueSoonest
        store.cycleSortMode()
        #expect(store.sortMode == .priority)
        store.cycleSortMode()
        #expect(store.sortMode == .nameAZ)
        store.cycleSortMode()
        #expect(store.sortMode == .nameZA)
        store.cycleSortMode()
        #expect(store.sortMode == .dueSoonest)
    }
}
