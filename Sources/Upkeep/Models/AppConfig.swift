import Foundation

struct AppConfig: Codable, Equatable, Sendable {
    var defaultReminderDaysBefore: Int = 3
    var showCompletedInDashboard: Bool = true
    var recentHistoryDays: Int = 30
}
