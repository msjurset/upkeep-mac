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
}
