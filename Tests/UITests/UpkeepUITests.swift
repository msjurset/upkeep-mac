import XCTest

@MainActor
final class UpkeepUITests: XCTestCase {
    let app = XCUIApplication()
    private var testDataDir: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Create isolated temp data directory with seed data
        testDataDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("upkeep-uitest-\(UUID().uuidString)")
        let fm = FileManager.default
        let itemsDir = testDataDir.appendingPathComponent("items")
        let logDir = testDataDir.appendingPathComponent("log")
        let vendorsDir = testDataDir.appendingPathComponent("vendors")
        try fm.createDirectory(at: itemsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: logDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: vendorsDir, withIntermediateDirectories: true)

        // Seed one item, one log entry, one vendor
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let itemID = UUID()
        let itemJSON = try encoder.encode(SeedItem(id: itemID, name: "Test Filter Change", category: "hvac",
            priority: "medium", frequencyInterval: 3, frequencyUnit: "months",
            startDate: Date.now.addingTimeInterval(-86400 * 30), notes: "", tags: ["test"],
            isActive: true, version: 1, createdAt: .now, updatedAt: .now))
        try itemJSON.write(to: itemsDir.appendingPathComponent("\(itemID.uuidString).json"))

        let logID = UUID()
        let logJSON = try encoder.encode(SeedLogEntry(id: logID, itemID: itemID, title: "Changed filter",
            category: "hvac", completedDate: Date.now.addingTimeInterval(-86400 * 10),
            notes: "", performedBy: "Self", createdAt: .now))
        try logJSON.write(to: logDir.appendingPathComponent("\(logID.uuidString).json"))

        let vendorID = UUID()
        let vendorJSON = try encoder.encode(SeedVendor(id: vendorID, name: "Test HVAC Co",
            phone: "555-0123", email: "test@hvac.com", website: "", location: "",
            specialty: "HVAC", tags: [], notes: "", version: 1, createdAt: .now, updatedAt: .now))
        try vendorJSON.write(to: vendorsDir.appendingPathComponent("\(vendorID.uuidString).json"))

        app.launchEnvironment["UI_TEST_DATA_DIR"] = testDataDir.path
        app.launch()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: testDataDir)
    }

    private func waitForSidebar() {
        let sidebar = findElement("sidebar")
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5), "Sidebar not found")
    }

    private func findElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func tapSidebarItem(_ identifier: String) {
        let item = findElement(identifier)
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Sidebar item '\(identifier)' not found")
        item.click()
    }

    private func waitForElement(_ identifier: String, timeout: TimeInterval = 10) {
        let element = findElement(identifier)
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Element '\(identifier)' not found")
    }

    // MARK: - Window & Layout

    func testAppLaunches() throws {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
    }

    func testSidebarIsVisible() throws {
        waitForSidebar()
    }

    func testDashboardShownByDefault() throws {
        waitForElement("detail.dashboard")
    }

    // MARK: - Sidebar Navigation: Inventory

    func testNavigateToUpcoming() throws {
        waitForSidebar()
        tapSidebarItem("sidebar.upcoming")
        waitForElement("list.items")
    }

    func testNavigateToOverdue() throws {
        waitForSidebar()
        tapSidebarItem("sidebar.overdue")
        waitForElement("list.items")
    }

    func testNavigateToAllItems() throws {
        waitForSidebar()
        tapSidebarItem("sidebar.allItems")
        waitForElement("list.items")
    }

    // MARK: - Sidebar Navigation: Journal

    func testNavigateToLog() throws {
        waitForSidebar()
        tapSidebarItem("sidebar.log")
        waitForElement("list.log")
    }

    // MARK: - Sidebar Navigation: Contacts

    func testNavigateToVendors() throws {
        waitForSidebar()
        tapSidebarItem("sidebar.vendors")
        waitForElement("list.vendors")
    }

    // MARK: - Sidebar Navigation: Home

    func testNavigateToHomeProfile() throws {
        waitForSidebar()
        tapSidebarItem("sidebar.homeProfile")
        waitForElement("detail.homeProfile")
    }

    // MARK: - Item Selection

    func testSelectItemFromList() throws {
        waitForSidebar()
        tapSidebarItem("sidebar.allItems")

        let list = findElement("list.items")
        XCTAssertTrue(list.waitForExistence(timeout: 5))

        let firstItem = list.buttons.firstMatch
        if firstItem.waitForExistence(timeout: 5) {
            firstItem.click()
            waitForElement("detail.item")
        }
    }

    // MARK: - Vendor Selection

    func testSelectVendorFromList() throws {
        waitForSidebar()
        tapSidebarItem("sidebar.vendors")

        let list = findElement("list.vendors")
        XCTAssertTrue(list.waitForExistence(timeout: 5))

        let firstVendor = list.buttons.firstMatch
        if firstVendor.waitForExistence(timeout: 5) {
            firstVendor.click()
            waitForElement("detail.vendor")
        }
    }

    // MARK: - Empty States

    func testEmptyDetailForItems() throws {
        waitForSidebar()
        tapSidebarItem("sidebar.allItems")
        waitForElement("detail.empty.item")
    }

    func testEmptyDetailForVendors() throws {
        waitForSidebar()
        tapSidebarItem("sidebar.vendors")
        waitForElement("detail.empty.vendor")
    }

    func testEmptyDetailForLog() throws {
        waitForSidebar()
        tapSidebarItem("sidebar.log")
        waitForElement("detail.empty.log")
    }

    // MARK: - Navigation Round-Trip

    func testNavigateAwayAndBack() throws {
        waitForSidebar()

        tapSidebarItem("sidebar.vendors")
        waitForElement("list.vendors")

        tapSidebarItem("sidebar.dashboard")
        waitForElement("detail.dashboard")
    }
}

// MARK: - Seed Data Structs

// Minimal Codable structs matching the app's JSON format.
// UI tests can't import the app module, so we define lightweight versions here.

private struct SeedItem: Codable {
    let id: UUID
    let name: String
    let category: String
    let priority: String
    let frequencyInterval: Int
    let frequencyUnit: String
    let startDate: Date
    let notes: String
    let tags: [String]
    let isActive: Bool
    let version: Int
    let createdAt: Date
    let updatedAt: Date
}

private struct SeedLogEntry: Codable {
    let id: UUID
    let itemID: UUID?
    let title: String
    let category: String
    let completedDate: Date
    let notes: String
    let performedBy: String
    let createdAt: Date
}

private struct SeedVendor: Codable {
    let id: UUID
    let name: String
    let phone: String
    let email: String
    let website: String
    let location: String
    let specialty: String
    let tags: [String]
    let notes: String
    let version: Int
    let createdAt: Date
    let updatedAt: Date
}
