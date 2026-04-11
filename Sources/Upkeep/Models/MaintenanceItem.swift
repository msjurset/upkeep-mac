import Foundation

struct SeasonalWindow: Codable, Hashable, Sendable {
    var startMonth: Int  // 1-12
    var startDay: Int    // 1-31
    var endMonth: Int    // 1-12
    var endDay: Int      // 1-31

    /// Description like "May 25 – Jul 7"
    var description: String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        let cal = Calendar.current
        let startComps = DateComponents(month: startMonth, day: startDay)
        let endComps = DateComponents(month: endMonth, day: endDay)
        let startStr = cal.date(from: startComps).map { df.string(from: $0) } ?? "\(startMonth)/\(startDay)"
        let endStr = cal.date(from: endComps).map { df.string(from: $0) } ?? "\(endMonth)/\(endDay)"
        return "\(startStr) – \(endStr)"
    }

    /// Returns the window start date for a given year.
    func startDate(in year: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: startMonth, day: startDay)) ?? .now
    }

    /// Returns the window end date for a given year.
    func endDate(in year: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: endMonth, day: endDay)) ?? .now
    }
}

struct MaintenanceItem: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var category: MaintenanceCategory
    var priority: Priority
    var frequencyInterval: Int
    var frequencyUnit: FrequencyUnit
    var startDate: Date
    var notes: String
    var vendorID: UUID?
    var supply: Supply?
    var tags: [String]
    var seasonalWindow: SeasonalWindow?
    var snoozedUntil: Date?
    var followUps: [FollowUp]
    var isActive: Bool
    var version: Int
    var lastModifiedBy: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, category: MaintenanceCategory = .other,
         priority: Priority = .medium, frequencyInterval: Int = 1,
         frequencyUnit: FrequencyUnit = .months, startDate: Date = .now,
         notes: String = "", vendorID: UUID? = nil, supply: Supply? = nil,
         tags: [String] = [], seasonalWindow: SeasonalWindow? = nil,
         snoozedUntil: Date? = nil, followUps: [FollowUp] = [],
         isActive: Bool = true,
         version: Int = 1, lastModifiedBy: UUID? = nil,
         createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.name = name
        self.category = category
        self.priority = priority
        self.frequencyInterval = frequencyInterval
        self.frequencyUnit = frequencyUnit
        self.startDate = startDate
        self.notes = notes
        self.vendorID = vendorID
        self.supply = supply
        self.tags = tags
        self.seasonalWindow = seasonalWindow
        self.snoozedUntil = snoozedUntil
        self.followUps = followUps
        self.isActive = isActive
        self.version = version
        self.lastModifiedBy = lastModifiedBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(MaintenanceCategory.self, forKey: .category)
        priority = try container.decode(Priority.self, forKey: .priority)
        frequencyInterval = try container.decode(Int.self, forKey: .frequencyInterval)
        frequencyUnit = try container.decode(FrequencyUnit.self, forKey: .frequencyUnit)
        startDate = try container.decode(Date.self, forKey: .startDate)
        notes = try container.decode(String.self, forKey: .notes)
        vendorID = try container.decodeIfPresent(UUID.self, forKey: .vendorID)
        supply = try container.decodeIfPresent(Supply.self, forKey: .supply)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        seasonalWindow = try container.decodeIfPresent(SeasonalWindow.self, forKey: .seasonalWindow)
        snoozedUntil = try container.decodeIfPresent(Date.self, forKey: .snoozedUntil)
        followUps = try container.decodeIfPresent([FollowUp].self, forKey: .followUps) ?? []
        isActive = try container.decode(Bool.self, forKey: .isActive)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        lastModifiedBy = try container.decodeIfPresent(UUID.self, forKey: .lastModifiedBy)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    mutating func touch(by memberID: UUID? = nil) {
        updatedAt = .now
        version += 1
        if let memberID { lastModifiedBy = memberID }
    }

    var isSnoozed: Bool {
        guard let snoozedUntil else { return false }
        return snoozedUntil > .now
    }

    var isSeasonal: Bool { seasonalWindow != nil }

    var frequencyDescription: String {
        if let window = seasonalWindow {
            return window.description
        }
        if frequencyInterval == 1 {
            return "Every \(frequencyUnit.singular)"
        }
        return "Every \(frequencyInterval) \(frequencyUnit.label.lowercased())"
    }
}
