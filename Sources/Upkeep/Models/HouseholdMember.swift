import Foundation

struct HouseholdMember: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var color: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, color: String = "amber",
         createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.color = color
        self.createdAt = createdAt
    }

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    static let availableColors = ["amber", "blue", "green", "purple", "red", "teal", "pink", "orange"]
}
