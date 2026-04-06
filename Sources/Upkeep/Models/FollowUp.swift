import Foundation

struct FollowUp: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var dueDate: Date?
    var isDone: Bool
    var createdAt: Date

    init(id: UUID = UUID(), title: String, dueDate: Date? = nil,
         isDone: Bool = false, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.isDone = isDone
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        isDone = try container.decode(Bool.self, forKey: .isDone)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    var isOverdue: Bool {
        guard let dueDate, !isDone else { return false }
        return dueDate < .now
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, dueDate, isDone, createdAt
    }
}
