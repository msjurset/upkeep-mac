import Foundation

struct LogEntry: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var itemID: UUID?
    var title: String
    var category: MaintenanceCategory
    var completedDate: Date
    var notes: String
    var cost: Decimal?
    var performedBy: String
    var rating: Int?
    var photoFilenames: [String]
    var createdAt: Date

    init(id: UUID = UUID(), itemID: UUID? = nil, title: String,
         category: MaintenanceCategory = .other, completedDate: Date = .now,
         notes: String = "", cost: Decimal? = nil, performedBy: String = "",
         rating: Int? = nil, photoFilenames: [String] = [], createdAt: Date = .now) {
        self.id = id
        self.itemID = itemID
        self.title = title
        self.category = category
        self.completedDate = completedDate
        self.notes = notes
        self.cost = cost
        self.performedBy = performedBy
        self.rating = rating
        self.photoFilenames = photoFilenames
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        itemID = try container.decodeIfPresent(UUID.self, forKey: .itemID)
        title = try container.decode(String.self, forKey: .title)
        category = try container.decode(MaintenanceCategory.self, forKey: .category)
        completedDate = try container.decode(Date.self, forKey: .completedDate)
        notes = try container.decode(String.self, forKey: .notes)
        cost = try container.decodeIfPresent(Decimal.self, forKey: .cost)
        performedBy = try container.decode(String.self, forKey: .performedBy)
        rating = try container.decodeIfPresent(Int.self, forKey: .rating)
        photoFilenames = try container.decodeIfPresent([String].self, forKey: .photoFilenames) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    var isStandalone: Bool { itemID == nil }

    var costFormatted: String? {
        guard let cost else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: cost as NSDecimalNumber)
    }
}
