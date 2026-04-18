import Foundation

struct AppConfig: Codable, Equatable, Sendable {
    var defaultReminderDaysBefore: Int = 3
    var showCompletedInDashboard: Bool = true
    var recentHistoryDays: Int = 30
    var autoDeactivateCompletedTodos: Bool = true

    init(
        defaultReminderDaysBefore: Int = 3,
        showCompletedInDashboard: Bool = true,
        recentHistoryDays: Int = 30,
        autoDeactivateCompletedTodos: Bool = true
    ) {
        self.defaultReminderDaysBefore = defaultReminderDaysBefore
        self.showCompletedInDashboard = showCompletedInDashboard
        self.recentHistoryDays = recentHistoryDays
        self.autoDeactivateCompletedTodos = autoDeactivateCompletedTodos
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        defaultReminderDaysBefore = try c.decodeIfPresent(Int.self, forKey: .defaultReminderDaysBefore) ?? 3
        showCompletedInDashboard = try c.decodeIfPresent(Bool.self, forKey: .showCompletedInDashboard) ?? true
        recentHistoryDays = try c.decodeIfPresent(Int.self, forKey: .recentHistoryDays) ?? 30
        autoDeactivateCompletedTodos = try c.decodeIfPresent(Bool.self, forKey: .autoDeactivateCompletedTodos) ?? true
    }
}
