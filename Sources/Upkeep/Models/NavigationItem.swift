import Foundation

enum NavigationItem: Hashable {
    case dashboard
    case inventoryUpcoming
    case inventoryOverdue
    case inventoryAll
    case itemDetail(UUID)
    case log
    case logEntryDetail(UUID)
    case vendors
    case vendorDetail(UUID)
    case homeProfile

    /// Section-level key for persisting last-used navigation.
    var sectionKey: String {
        switch self {
        case .dashboard: "dashboard"
        case .inventoryUpcoming: "inventoryUpcoming"
        case .inventoryOverdue: "inventoryOverdue"
        case .inventoryAll, .itemDetail: "inventoryAll"
        case .log, .logEntryDetail: "log"
        case .vendors, .vendorDetail: "vendors"
        case .homeProfile: "homeProfile"
        }
    }

    static func from(sectionKey: String) -> NavigationItem? {
        switch sectionKey {
        case "dashboard": .dashboard
        case "inventoryUpcoming": .inventoryUpcoming
        case "inventoryOverdue": .inventoryOverdue
        case "inventoryAll": .inventoryAll
        case "log": .log
        case "vendors": .vendors
        case "homeProfile": .homeProfile
        default: nil
        }
    }
}
