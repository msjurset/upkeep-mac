import Foundation

struct FollowUp: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var dueDate: Date?
    var assignedTo: UUID?
    var isDone: Bool
    var createdAt: Date

    init(id: UUID = UUID(), title: String, dueDate: Date? = nil,
         assignedTo: UUID? = nil, isDone: Bool = false, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.assignedTo = assignedTo
        self.isDone = isDone
        self.createdAt = createdAt
    }

    var isOverdue: Bool {
        guard let dueDate, !isDone else { return false }
        return dueDate < .now
    }
}
