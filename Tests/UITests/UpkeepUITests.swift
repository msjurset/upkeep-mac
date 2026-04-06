import XCTest

@MainActor
final class UpkeepUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
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
