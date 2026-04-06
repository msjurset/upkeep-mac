import Foundation

extension Date {
    /// "Apr 3, 2026" — standard short date used throughout the app
    var shortDate: String {
        formatted(date: .abbreviated, time: .omitted)
    }

    /// "April 3, 2026" — longer form for detail views
    var longDate: String {
        formatted(date: .long, time: .omitted)
    }
}

enum DueDateText {
    /// Relative description: "Today", "Tomorrow", "In 7 days", "3 days overdue"
    static func relative(days: Int) -> String {
        switch days {
        case ..<0:
            let overdue = abs(days)
            return overdue == 1 ? "1 day overdue" : "\(overdue) days overdue"
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "In \(days) days"
        }
    }

    /// Badge label: "Due today", "Due tomorrow", "Due in 7 days", "3 days overdue"
    static func badge(days: Int) -> String {
        switch days {
        case ..<0:
            let overdue = abs(days)
            return overdue == 1 ? "1 day overdue" : "\(overdue) days overdue"
        case 0: return "Due today"
        case 1: return "Due tomorrow"
        default: return "Due in \(days) days"
        }
    }
}
