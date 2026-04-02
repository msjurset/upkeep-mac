import Testing
import Foundation
@testable import Upkeep

@Suite("Persistence")
struct PersistenceTests {
    private func makeTempPersistence() -> (Persistence, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return (Persistence(baseURL: dir), dir)
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Items

    @Test("save and load item")
    func itemRoundTrip() async throws {
        let (p, dir) = makeTempPersistence()
        defer { cleanup(dir) }

        let item = MaintenanceItem(name: "Change filter", category: .hvac, frequencyInterval: 3, frequencyUnit: .months)
        try await p.saveItem(item)

        let loaded = try await p.loadItems()
        #expect(loaded.count == 1)
        #expect(loaded[0].id == item.id)
        #expect(loaded[0].name == "Change filter")
        #expect(loaded[0].category == .hvac)
    }

    @Test("delete item")
    func deleteItem() async throws {
        let (p, dir) = makeTempPersistence()
        defer { cleanup(dir) }

        let item = MaintenanceItem(name: "Test")
        try await p.saveItem(item)
        try await p.deleteItem(id: item.id)

        let loaded = try await p.loadItems()
        #expect(loaded.isEmpty)
    }

    @Test("delete nonexistent item throws")
    func deleteNonexistent() async throws {
        let (p, dir) = makeTempPersistence()
        defer { cleanup(dir) }

        await #expect(throws: PersistenceError.self) {
            try await p.deleteItem(id: UUID())
        }
    }

    @Test("multiple items stored independently")
    func multipleItems() async throws {
        let (p, dir) = makeTempPersistence()
        defer { cleanup(dir) }

        let a = MaintenanceItem(name: "Item A")
        let b = MaintenanceItem(name: "Item B")
        try await p.saveItem(a)
        try await p.saveItem(b)

        let loaded = try await p.loadItems()
        #expect(loaded.count == 2)
    }

    @Test("update overwrites existing item")
    func updateItem() async throws {
        let (p, dir) = makeTempPersistence()
        defer { cleanup(dir) }

        var item = MaintenanceItem(name: "Original")
        try await p.saveItem(item)
        item.name = "Updated"
        try await p.saveItem(item)

        let loaded = try await p.loadItems()
        #expect(loaded.count == 1)
        #expect(loaded[0].name == "Updated")
    }

    // MARK: - Log Entries

    @Test("save and load log entry")
    func logEntryRoundTrip() async throws {
        let (p, dir) = makeTempPersistence()
        defer { cleanup(dir) }

        let entry = LogEntry(title: "Changed filter", category: .hvac, cost: 24.99)
        try await p.saveLogEntry(entry)

        let loaded = try await p.loadLogEntries()
        #expect(loaded.count == 1)
        #expect(loaded[0].id == entry.id)
        #expect(loaded[0].title == "Changed filter")
        #expect(loaded[0].cost == 24.99)
    }

    @Test("delete log entry")
    func deleteLogEntry() async throws {
        let (p, dir) = makeTempPersistence()
        defer { cleanup(dir) }

        let entry = LogEntry(title: "Test")
        try await p.saveLogEntry(entry)
        try await p.deleteLogEntry(id: entry.id)

        let loaded = try await p.loadLogEntries()
        #expect(loaded.isEmpty)
    }

    // MARK: - Vendors

    @Test("save and load vendor")
    func vendorRoundTrip() async throws {
        let (p, dir) = makeTempPersistence()
        defer { cleanup(dir) }

        let vendor = Vendor(name: "Bob's Plumbing", phone: "555-0123", specialty: "Plumbing")
        try await p.saveVendor(vendor)

        let loaded = try await p.loadVendors()
        #expect(loaded.count == 1)
        #expect(loaded[0].id == vendor.id)
        #expect(loaded[0].name == "Bob's Plumbing")
    }

    @Test("delete vendor")
    func deleteVendor() async throws {
        let (p, dir) = makeTempPersistence()
        defer { cleanup(dir) }

        let vendor = Vendor(name: "Test")
        try await p.saveVendor(vendor)
        try await p.deleteVendor(id: vendor.id)

        let loaded = try await p.loadVendors()
        #expect(loaded.isEmpty)
    }

    // MARK: - Config

    @Test("config round-trip")
    func configRoundTrip() async throws {
        let (p, dir) = makeTempPersistence()
        defer { cleanup(dir) }

        var config = AppConfig()
        config.defaultReminderDaysBefore = 7
        try await p.saveConfig(config)

        let loaded = try await p.loadConfig()
        #expect(loaded.defaultReminderDaysBefore == 7)
    }

    @Test("config defaults when no file exists")
    func configDefaults() async throws {
        let (p, dir) = makeTempPersistence()
        defer { cleanup(dir) }

        let config = try await p.loadConfig()
        #expect(config.defaultReminderDaysBefore == 3)
    }

    @Test("empty load returns empty array")
    func emptyLoad() async throws {
        let (p, dir) = makeTempPersistence()
        defer { cleanup(dir) }

        #expect(try await p.loadItems().isEmpty)
        #expect(try await p.loadLogEntries().isEmpty)
        #expect(try await p.loadVendors().isEmpty)
    }
}
