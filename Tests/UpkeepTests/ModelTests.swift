import Testing
import Foundation
@testable import Upkeep

// MARK: - Priority

@Suite("Priority")
struct PriorityTests {
    @Test("ordering")
    func ordering() {
        #expect(Priority.low < Priority.medium)
        #expect(Priority.medium < Priority.high)
        #expect(Priority.high < Priority.critical)
    }

    @Test("labels are capitalized")
    func labels() {
        #expect(Priority.low.label == "Low")
        #expect(Priority.critical.label == "Critical")
    }
}

// MARK: - MaintenanceCategory

@Suite("MaintenanceCategory")
struct MaintenanceCategoryTests {
    @Test("labels")
    func labels() {
        #expect(MaintenanceCategory.hvac.label == "HVAC")
        #expect(MaintenanceCategory.lawnAndGarden.label == "Lawn & Garden")
        #expect(MaintenanceCategory.other.label == "Other")
    }

    @Test("icons")
    func icons() {
        #expect(MaintenanceCategory.plumbing.icon == "drop")
        #expect(MaintenanceCategory.electrical.icon == "bolt")
        #expect(MaintenanceCategory.safety.icon == "shield.checkered")
    }

    @Test("JSON round-trip")
    func jsonRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for cat in MaintenanceCategory.allCases {
            let data = try encoder.encode(cat)
            let decoded = try decoder.decode(MaintenanceCategory.self, from: data)
            #expect(decoded == cat)
        }
    }
}

// MARK: - FrequencyUnit

@Suite("FrequencyUnit")
struct FrequencyUnitTests {
    @Test("labels")
    func labels() {
        #expect(FrequencyUnit.days.label == "Days")
        #expect(FrequencyUnit.months.label == "Months")
    }

    @Test("singular")
    func singular() {
        #expect(FrequencyUnit.days.singular == "day")
        #expect(FrequencyUnit.weeks.singular == "week")
        #expect(FrequencyUnit.months.singular == "month")
        #expect(FrequencyUnit.years.singular == "year")
    }
}

// MARK: - MaintenanceItem

@Suite("MaintenanceItem")
struct MaintenanceItemTests {
    @Test("JSON round-trip with ISO8601 dates")
    func jsonRoundTrip() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let item = MaintenanceItem(
            name: "Change HVAC filter",
            category: .hvac,
            priority: .high,
            frequencyInterval: 3,
            frequencyUnit: .months,
            notes: "Use MERV 13 filter"
        )

        let data = try encoder.encode(item)
        let decoded = try decoder.decode(MaintenanceItem.self, from: data)

        #expect(decoded.id == item.id)
        #expect(decoded.name == "Change HVAC filter")
        #expect(decoded.category == .hvac)
        #expect(decoded.priority == .high)
        #expect(decoded.frequencyInterval == 3)
        #expect(decoded.frequencyUnit == .months)
        #expect(decoded.notes == "Use MERV 13 filter")
        #expect(decoded.isActive == true)
    }

    @Test("default values")
    func defaults() {
        let item = MaintenanceItem(name: "Test")
        #expect(item.category == .other)
        #expect(item.priority == .medium)
        #expect(item.frequencyInterval == 1)
        #expect(item.frequencyUnit == .months)
        #expect(item.isActive == true)
        #expect(item.vendorID == nil)
    }

    @Test("touch updates timestamp")
    func touch() throws {
        var item = MaintenanceItem(name: "Test")
        let before = item.updatedAt
        Thread.sleep(forTimeInterval: 0.01)
        item.touch()
        #expect(item.updatedAt > before)
    }

    @Test("frequency description")
    func frequencyDescription() {
        let monthly = MaintenanceItem(name: "Test", frequencyInterval: 1, frequencyUnit: .months)
        #expect(monthly.frequencyDescription == "Every month")

        let quarterly = MaintenanceItem(name: "Test", frequencyInterval: 3, frequencyUnit: .months)
        #expect(quarterly.frequencyDescription == "Every 3 months")

        let biweekly = MaintenanceItem(name: "Test", frequencyInterval: 2, frequencyUnit: .weeks)
        #expect(biweekly.frequencyDescription == "Every 2 weeks")
    }
}

// MARK: - Supply

@Suite("Supply")
struct SupplyTests {
    @Test("uses remaining")
    func usesRemaining() {
        let supply = Supply(stockOnHand: 5, quantityPerUse: 2)
        #expect(supply.usesRemaining == 2)

        let single = Supply(stockOnHand: 3, quantityPerUse: 1)
        #expect(single.usesRemaining == 3)
    }

    @Test("needs reorder when less than 2 uses left")
    func needsReorder() {
        let low = Supply(stockOnHand: 1, quantityPerUse: 1)
        #expect(low.needsReorder == true)

        let ok = Supply(stockOnHand: 3, quantityPerUse: 1)
        #expect(ok.needsReorder == false)

        let exactlyTwo = Supply(stockOnHand: 2, quantityPerUse: 1)
        #expect(exactlyTwo.needsReorder == false)
    }

    @Test("out of stock")
    func outOfStock() {
        let empty = Supply(stockOnHand: 0, quantityPerUse: 2)
        #expect(empty.isOutOfStock == true)

        let one = Supply(stockOnHand: 1, quantityPerUse: 2)
        #expect(one.isOutOfStock == true)

        let enough = Supply(stockOnHand: 2, quantityPerUse: 2)
        #expect(enough.isOutOfStock == false)
    }

    @Test("JSON round-trip")
    func jsonRoundTrip() throws {
        let supply = Supply(stockOnHand: 3, quantityPerUse: 2, productName: "MERV 13 Filter",
                            productURL: "https://amazon.com/filter", unitCost: 18.99)
        let data = try JSONEncoder().encode(supply)
        let decoded = try JSONDecoder().decode(Supply.self, from: data)
        #expect(decoded.stockOnHand == 3)
        #expect(decoded.quantityPerUse == 2)
        #expect(decoded.productName == "MERV 13 Filter")
        #expect(decoded.productURL == "https://amazon.com/filter")
        #expect(decoded.unitCost == 18.99)
    }

    @Test("unit cost formatted")
    func unitCostFormatted() {
        let withCost = Supply(unitCost: 18.99)
        #expect(withCost.unitCostFormatted != nil)

        let noCost = Supply()
        #expect(noCost.unitCostFormatted == nil)
    }
}

// MARK: - MaintenanceItem with Supply

@Suite("MaintenanceItem+Supply")
struct MaintenanceItemSupplyTests {
    @Test("item with supply round-trips")
    func roundTrip() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let item = MaintenanceItem(
            name: "Replace filter", category: .hvac,
            supply: Supply(stockOnHand: 3, quantityPerUse: 1, productName: "MERV 13")
        )
        let data = try encoder.encode(item)
        let decoded = try decoder.decode(MaintenanceItem.self, from: data)
        #expect(decoded.supply != nil)
        #expect(decoded.supply?.stockOnHand == 3)
        #expect(decoded.supply?.productName == "MERV 13")
    }

    @Test("item without supply decodes from old JSON")
    func backwardCompatible() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Create an item without supply
        let item = MaintenanceItem(name: "Clean gutters")
        let data = try encoder.encode(item)
        let decoded = try decoder.decode(MaintenanceItem.self, from: data)
        #expect(decoded.supply == nil)
    }
}

// MARK: - LogEntry

@Suite("LogEntry")
struct LogEntryTests {
    @Test("JSON round-trip")
    func jsonRoundTrip() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let entry = LogEntry(
            itemID: UUID(),
            title: "Changed HVAC filter",
            category: .hvac,
            notes: "Used MERV 13",
            cost: 24.99,
            performedBy: "Self"
        )

        let data = try encoder.encode(entry)
        let decoded = try decoder.decode(LogEntry.self, from: data)

        #expect(decoded.id == entry.id)
        #expect(decoded.itemID == entry.itemID)
        #expect(decoded.title == "Changed HVAC filter")
        #expect(decoded.category == .hvac)
        #expect(decoded.cost == 24.99)
        #expect(decoded.performedBy == "Self")
    }

    @Test("standalone entry has no itemID")
    func standalone() {
        let entry = LogEntry(title: "Fixed loose railing")
        #expect(entry.isStandalone == true)
        #expect(entry.itemID == nil)
    }

    @Test("linked entry has itemID")
    func linked() {
        let itemID = UUID()
        let entry = LogEntry(itemID: itemID, title: "Changed filter")
        #expect(entry.isStandalone == false)
        #expect(entry.itemID == itemID)
    }

    @Test("cost formatting")
    func costFormatted() {
        let withCost = LogEntry(title: "Test", cost: 149.50)
        #expect(withCost.costFormatted != nil)

        let noCost = LogEntry(title: "Test")
        #expect(noCost.costFormatted == nil)
    }
}

// MARK: - Vendor

@Suite("Vendor")
struct VendorTests {
    @Test("JSON round-trip")
    func jsonRoundTrip() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let vendor = Vendor(
            name: "Bob's Plumbing",
            phone: "555-0123",
            email: "bob@plumbing.com",
            website: "https://bobsplumbing.com",
            specialty: "Residential plumbing",
            notes: "Great service"
        )

        let data = try encoder.encode(vendor)
        let decoded = try decoder.decode(Vendor.self, from: data)

        #expect(decoded.id == vendor.id)
        #expect(decoded.name == "Bob's Plumbing")
        #expect(decoded.phone == "555-0123")
        #expect(decoded.specialty == "Residential plumbing")
    }

    @Test("default empty strings")
    func defaults() {
        let vendor = Vendor(name: "Test")
        #expect(vendor.phone.isEmpty)
        #expect(vendor.email.isEmpty)
        #expect(vendor.website.isEmpty)
        #expect(vendor.specialty.isEmpty)
        #expect(vendor.notes.isEmpty)
    }

    @Test("has contact info")
    func hasContactInfo() {
        let noInfo = Vendor(name: "Test")
        #expect(noInfo.hasContactInfo == false)

        let withPhone = Vendor(name: "Test", phone: "555-0123")
        #expect(withPhone.hasContactInfo == true)

        let withEmail = Vendor(name: "Test", email: "a@b.com")
        #expect(withEmail.hasContactInfo == true)
    }

    @Test("touch updates timestamp")
    func touch() {
        var vendor = Vendor(name: "Test")
        let before = vendor.updatedAt
        Thread.sleep(forTimeInterval: 0.01)
        vendor.touch()
        #expect(vendor.updatedAt > before)
    }
}

// MARK: - AppConfig

@Suite("AppConfig")
struct AppConfigTests {
    @Test("defaults")
    func defaults() {
        let config = AppConfig()
        #expect(config.defaultReminderDaysBefore == 3)
        #expect(config.showCompletedInDashboard == true)
        #expect(config.recentHistoryDays == 30)
    }

    @Test("JSON round-trip")
    func jsonRoundTrip() throws {
        var config = AppConfig()
        config.defaultReminderDaysBefore = 7
        config.recentHistoryDays = 60

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)

        #expect(decoded.defaultReminderDaysBefore == 7)
        #expect(decoded.recentHistoryDays == 60)
    }
}
