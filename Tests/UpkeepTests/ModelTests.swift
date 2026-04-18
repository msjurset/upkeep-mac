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

    @Test("to-do frequency description shows due date")
    func todoDescription() {
        let todo = MaintenanceItem(name: "Test", scheduleKind: .oneTime)
        #expect(todo.frequencyDescription.hasPrefix("Do by"))
    }

    @Test("scheduleKind round-trip with seasonal window")
    func scheduleKindSeasonal() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let item = MaintenanceItem(
            name: "Trim",
            scheduleKind: .seasonal,
            seasonalWindow: SeasonalWindow(startMonth: 5, startDay: 1, endMonth: 6, endDay: 30)
        )
        let data = try encoder.encode(item)
        let decoded = try decoder.decode(MaintenanceItem.self, from: data)
        #expect(decoded.scheduleKind == .seasonal)
        #expect(decoded.isSeasonal)
        #expect(decoded.seasonalWindow != nil)
    }

    @Test("scheduleKind round-trip for to-do")
    func scheduleKindTodo() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let item = MaintenanceItem(name: "Fix ceiling", scheduleKind: .oneTime)
        let data = try encoder.encode(item)
        let decoded = try decoder.decode(MaintenanceItem.self, from: data)
        #expect(decoded.scheduleKind == .oneTime)
        #expect(decoded.isOneTime)
    }

    @Test("pre-1.6 JSON without scheduleKind infers recurring")
    func backCompatRecurring() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Encode, strip the scheduleKind key to simulate pre-1.6 data
        let item = MaintenanceItem(name: "Filter", frequencyInterval: 3, frequencyUnit: .months)
        let data = try encoder.encode(item)
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "scheduleKind")
        let stripped = try JSONSerialization.data(withJSONObject: json)
        let decoded = try decoder.decode(MaintenanceItem.self, from: stripped)
        #expect(decoded.scheduleKind == .recurring)
    }

    @Test("pre-1.6 JSON with seasonalWindow infers seasonal")
    func backCompatSeasonal() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let item = MaintenanceItem(
            name: "Trim",
            seasonalWindow: SeasonalWindow(startMonth: 5, startDay: 1, endMonth: 6, endDay: 30)
        )
        let data = try encoder.encode(item)
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "scheduleKind")
        let stripped = try JSONSerialization.data(withJSONObject: json)
        let decoded = try decoder.decode(MaintenanceItem.self, from: stripped)
        #expect(decoded.scheduleKind == .seasonal)
        #expect(decoded.isSeasonal)
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
        #expect(vendor.location.isEmpty)
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

        let withLocation = Vendor(name: "Test", location: "https://maps.google.com/?q=test")
        #expect(withLocation.hasContactInfo == true)
    }

    // MARK: - Location URL: Map URLs

    @Test("locationURL passes through https map URL")
    func locationURLHttps() {
        let vendor = Vendor(name: "Test", location: "https://maps.google.com/?q=test")
        #expect(vendor.locationURL?.absoluteString == "https://maps.google.com/?q=test")
    }

    @Test("locationURL passes through http URL")
    func locationURLHttp() {
        let vendor = Vendor(name: "Test", location: "http://maps.google.com/?q=test")
        #expect(vendor.locationURL?.absoluteString == "http://maps.google.com/?q=test")
    }

    @Test("locationURL passes through non-Google map URL")
    func locationURLNonGoogle() {
        let vendor = Vendor(name: "Test", location: "https://www.openstreetmap.org/#map=15/33.829/-84.493")
        #expect(vendor.locationURL?.absoluteString == "https://www.openstreetmap.org/#map=15/33.829/-84.493")
    }

    // MARK: - Location URL: Plus Codes

    @Test("locationURL from global Plus Code",
          arguments: [
            ("849VCWC8+R9", "https://www.google.com/maps/search/?api=1&query=849VCWC8%2BR9"),
            ("87G8Q2PQ+7V", "https://www.google.com/maps/search/?api=1&query=87G8Q2PQ%2B7V"),
          ])
    func locationURLGlobalPlusCode(input: String, expected: String) {
        let vendor = Vendor(name: "Test", location: input)
        #expect(vendor.locationURL?.absoluteString == expected)
    }

    @Test("locationURL from short Plus Code with locality",
          arguments: [
            ("CWC8+R9 Mountain View", "https://www.google.com/maps/search/?api=1&query=CWC8%2BR9%20Mountain%20View"),
            ("RGH4+HQ Smyrna, Georgia", "https://www.google.com/maps/search/?api=1&query=RGH4%2BHQ%20Smyrna,%20Georgia"),
          ])
    func locationURLShortPlusCode(input: String, expected: String) {
        let vendor = Vendor(name: "Test", location: input)
        #expect(vendor.locationURL?.absoluteString == expected)
    }

    @Test("locationURL Plus Code encodes + as %2B")
    func locationURLPlusCodeEncoding() {
        let vendor = Vendor(name: "Test", location: "849VCWC8+R9")
        let url = vendor.locationURL!.absoluteString
        #expect(url.contains("%2B"))
        #expect(!url.contains("+"))
    }

    // MARK: - Location URL: Coordinates

    @Test("locationURL from coordinates",
          arguments: [
            ("33.82898680162221, -84.49300463162628", "https://www.google.com/maps/search/?api=1&query=33.82898680162221,-84.49300463162628"),
            ("40.7128, -74.0060", "https://www.google.com/maps/search/?api=1&query=40.7128,-74.0060"),
            ("-33.8688, 151.2093", "https://www.google.com/maps/search/?api=1&query=-33.8688,151.2093"),
          ])
    func locationURLCoordinates(input: String, expected: String) {
        let vendor = Vendor(name: "Test", location: input)
        #expect(vendor.locationURL?.absoluteString == expected)
    }

    @Test("locationURL rejects out-of-range coordinates")
    func locationURLInvalidCoordinates() {
        #expect(Vendor(name: "T", location: "91.0, -84.0").locationURL == nil)
        #expect(Vendor(name: "T", location: "-91.0, -84.0").locationURL == nil)
        #expect(Vendor(name: "T", location: "33.0, 181.0").locationURL == nil)
        #expect(Vendor(name: "T", location: "33.0, -181.0").locationURL == nil)
    }

    @Test("locationURL handles coordinates without spaces")
    func locationURLCoordinatesNoSpace() {
        let vendor = Vendor(name: "Test", location: "33.829,-84.493")
        #expect(vendor.locationURL?.absoluteString == "https://www.google.com/maps/search/?api=1&query=33.829,-84.493")
    }

    // MARK: - Location URL: DMS Coordinates

    @Test("locationURL from DMS coordinates")
    func locationURLDMS() {
        let vendor = Vendor(name: "Test", location: "33°49'44.4\"N 84°29'34.8\"W")
        let url = vendor.locationURL
        #expect(url != nil)
        // 33 + 49/60 + 44.4/3600 = 33.829, negated W = -84.4930
        let str = url!.absoluteString
        #expect(str.hasPrefix("https://www.google.com/maps/search/?api=1&query=33.82"))
        #expect(str.contains(",-84.49"))
    }

    @Test("locationURL from DMS southern/eastern hemisphere")
    func locationURLDMSSouthEast() {
        let vendor = Vendor(name: "Test", location: "33°52'07.7\"S 151°12'33.5\"E")
        let url = vendor.locationURL
        #expect(url != nil)
        let str = url!.absoluteString
        #expect(str.contains("-33."))
        #expect(str.contains(",151."))
    }

    @Test("locationURL DMS with typographic quotes")
    func locationURLDMSTypographic() {
        let vendor = Vendor(name: "Test", location: "33\u{00B0}49\u{2032}44.4\u{2033}N 84\u{00B0}29\u{2032}34.8\u{2033}W")
        #expect(vendor.locationURL != nil)
    }

    // MARK: - Location URL: Nil cases

    @Test("locationURL nil for empty or plain text")
    func locationURLNil() {
        #expect(Vendor(name: "Test").locationURL == nil)
        #expect(Vendor(name: "Test", location: "").locationURL == nil)
        #expect(Vendor(name: "Test", location: "   ").locationURL == nil)
        #expect(Vendor(name: "Test", location: "123 Main St").locationURL == nil)
        #expect(Vendor(name: "Test", location: "Bob's shop downtown").locationURL == nil)
    }

    @Test("account manager defaults to empty")
    func accountManagerDefaults() {
        let vendor = Vendor(name: "Test")
        #expect(vendor.accountManager.isEmpty)
        #expect(vendor.accountManager.name.isEmpty)
        #expect(vendor.accountManager.phone.isEmpty)
        #expect(vendor.accountManager.email.isEmpty)
    }

    @Test("account manager round-trips through JSON")
    func accountManagerRoundTrip() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let vendor = Vendor(
            name: "Test",
            accountManager: AccountManager(name: "Jane", phone: "555-9999", email: "jane@vendor.com")
        )
        let data = try encoder.encode(vendor)
        let decoded = try decoder.decode(Vendor.self, from: data)
        #expect(decoded.accountManager.name == "Jane")
        #expect(decoded.accountManager.phone == "555-9999")
        #expect(decoded.accountManager.email == "jane@vendor.com")
        #expect(!decoded.accountManager.isEmpty)
    }

    @Test("account manager backward-compatible when missing from JSON")
    func accountManagerBackwardCompat() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Encode a vendor, strip the accountManager key, decode again
        let vendor = Vendor(name: "Test")
        let data = try encoder.encode(vendor)
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "accountManager")
        let stripped = try JSONSerialization.data(withJSONObject: json)
        let decoded = try decoder.decode(Vendor.self, from: stripped)
        #expect(decoded.accountManager.isEmpty)
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
        #expect(config.autoDeactivateCompletedTodos == true)
    }

    @Test("JSON round-trip")
    func jsonRoundTrip() throws {
        var config = AppConfig()
        config.defaultReminderDaysBefore = 7
        config.recentHistoryDays = 60
        config.autoDeactivateCompletedTodos = false

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)

        #expect(decoded.defaultReminderDaysBefore == 7)
        #expect(decoded.recentHistoryDays == 60)
        #expect(decoded.autoDeactivateCompletedTodos == false)
    }

    @Test("pre-1.6 JSON without autoDeactivateCompletedTodos decodes with default true")
    func backCompat() throws {
        let json = """
        {
          "defaultReminderDaysBefore": 5,
          "showCompletedInDashboard": true,
          "recentHistoryDays": 45
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AppConfig.self, from: json)
        #expect(decoded.defaultReminderDaysBefore == 5)
        #expect(decoded.autoDeactivateCompletedTodos == true)
    }

    @Test("empty JSON decodes to defaults")
    func emptyDecode() throws {
        let data = "{}".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
        #expect(decoded.defaultReminderDaysBefore == 3)
        #expect(decoded.showCompletedInDashboard == true)
        #expect(decoded.recentHistoryDays == 30)
        #expect(decoded.autoDeactivateCompletedTodos == true)
    }
}
