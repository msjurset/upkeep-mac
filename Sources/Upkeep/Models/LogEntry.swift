import Foundation

struct LogEntry: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var itemID: UUID?
    /// When set, identifies which `SubEvent` of the parent item this log
    /// entry recorded. Nil for items without sub-events (the common case).
    var subEventID: UUID?
    var title: String
    var category: MaintenanceCategory
    var completedDate: Date
    var notes: String
    var cost: Decimal?
    var performedBy: String
    var rating: Int?
    var photoFilenames: [String]
    var attachments: [Attachment]
    var createdAt: Date
    /// When false, this entry is a progress note that does not reset the
    /// item's schedule (recurring/seasonal next-due, one-time auto-deactivate).
    /// Default true preserves prior behavior for entries written before this
    /// field existed.
    var countsAsCompletion: Bool

    init(id: UUID = UUID(), itemID: UUID? = nil, subEventID: UUID? = nil, title: String,
         category: MaintenanceCategory = .other, completedDate: Date = .now,
         notes: String = "", cost: Decimal? = nil, performedBy: String = "",
         rating: Int? = nil, photoFilenames: [String] = [],
         attachments: [Attachment] = [], createdAt: Date = .now,
         countsAsCompletion: Bool = true) {
        self.id = id
        self.itemID = itemID
        self.subEventID = subEventID
        self.title = title
        self.category = category
        self.completedDate = completedDate
        self.notes = notes
        self.cost = cost
        self.performedBy = performedBy
        self.rating = rating
        self.photoFilenames = photoFilenames
        self.attachments = attachments
        self.createdAt = createdAt
        self.countsAsCompletion = countsAsCompletion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        itemID = try container.decodeIfPresent(UUID.self, forKey: .itemID)
        subEventID = try container.decodeIfPresent(UUID.self, forKey: .subEventID)
        title = try container.decode(String.self, forKey: .title)
        category = try container.decode(MaintenanceCategory.self, forKey: .category)
        completedDate = try container.decode(Date.self, forKey: .completedDate)
        notes = try container.decode(String.self, forKey: .notes)
        cost = try container.decodeIfPresent(Decimal.self, forKey: .cost)
        performedBy = try container.decode(String.self, forKey: .performedBy)
        rating = try container.decodeIfPresent(Int.self, forKey: .rating)
        photoFilenames = try container.decodeIfPresent([String].self, forKey: .photoFilenames) ?? []
        attachments = try container.decodeIfPresent([Attachment].self, forKey: .attachments) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        countsAsCompletion = try container.decodeIfPresent(Bool.self, forKey: .countsAsCompletion) ?? true
    }

    var isStandalone: Bool { itemID == nil }

    var costFormatted: String? {
        guard let cost else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: cost as NSDecimalNumber)
    }
}
