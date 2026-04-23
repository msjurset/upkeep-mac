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

    /// Whether the window spans a year boundary (e.g. Nov – Jan).
    var spansYearBoundary: Bool { endMonth < startMonth }

    /// Returns the window start date for a given year.
    func startDate(in year: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: startMonth, day: startDay)) ?? .now
    }

    /// Returns the window end date for a given year.
    /// If the window spans a year boundary (e.g. Nov–Jan), the end date is in year+1.
    func endDate(in year: Int) -> Date {
        let endYear = spansYearBoundary ? year + 1 : year
        return Calendar.current.date(from: DateComponents(year: endYear, month: endMonth, day: endDay)) ?? .now
    }
}

enum ScheduleKind: String, Codable, CaseIterable, Sendable {
    case recurring
    case seasonal
    case oneTime
    case idea

    var label: String {
        switch self {
        case .recurring: "Recurring"
        case .seasonal: "Seasonal"
        case .oneTime: "To-do"
        case .idea: "Idea"
        }
    }
}

struct MaintenanceItem: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var category: MaintenanceCategory
    var priority: Priority
    var scheduleKind: ScheduleKind
    var frequencyInterval: Int
    var frequencyUnit: FrequencyUnit
    var startDate: Date
    var notes: String
    var vendorID: UUID?
    var supply: Supply?
    var tags: [String]
    var customIcon: String?
    var attachments: [Attachment]
    var seasonalWindow: SeasonalWindow?
    var skippedYear: Int?
    var snoozedUntil: Date?
    var followUps: [FollowUp]
    var isActive: Bool
    var version: Int
    var lastModifiedBy: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, category: MaintenanceCategory = .other,
         priority: Priority = .medium, scheduleKind: ScheduleKind? = nil,
         frequencyInterval: Int = 1,
         frequencyUnit: FrequencyUnit = .months, startDate: Date = .now,
         notes: String = "", vendorID: UUID? = nil, supply: Supply? = nil,
         tags: [String] = [], customIcon: String? = nil,
         attachments: [Attachment] = [],
         seasonalWindow: SeasonalWindow? = nil,
         skippedYear: Int? = nil, snoozedUntil: Date? = nil, followUps: [FollowUp] = [],
         isActive: Bool = true,
         version: Int = 1, lastModifiedBy: UUID? = nil,
         createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.name = name
        self.category = category
        self.priority = priority
        self.scheduleKind = scheduleKind ?? (seasonalWindow != nil ? .seasonal : .recurring)
        self.frequencyInterval = frequencyInterval
        self.frequencyUnit = frequencyUnit
        self.startDate = startDate
        self.notes = notes
        self.vendorID = vendorID
        self.supply = supply
        self.tags = tags
        self.customIcon = customIcon
        self.attachments = attachments
        self.seasonalWindow = seasonalWindow
        self.skippedYear = skippedYear
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
        customIcon = try container.decodeIfPresent(String.self, forKey: .customIcon)
        attachments = try container.decodeIfPresent([Attachment].self, forKey: .attachments) ?? []
        seasonalWindow = try container.decodeIfPresent(SeasonalWindow.self, forKey: .seasonalWindow)
        skippedYear = try container.decodeIfPresent(Int.self, forKey: .skippedYear)
        snoozedUntil = try container.decodeIfPresent(Date.self, forKey: .snoozedUntil)
        followUps = try container.decodeIfPresent([FollowUp].self, forKey: .followUps) ?? []
        isActive = try container.decode(Bool.self, forKey: .isActive)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        lastModifiedBy = try container.decodeIfPresent(UUID.self, forKey: .lastModifiedBy)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        // Pre-1.6 JSON: infer scheduleKind from seasonalWindow presence
        scheduleKind = try container.decodeIfPresent(ScheduleKind.self, forKey: .scheduleKind)
            ?? (seasonalWindow != nil ? .seasonal : .recurring)
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

    var isSeasonal: Bool { scheduleKind == .seasonal }
    var isOneTime: Bool { scheduleKind == .oneTime }
    var isIdea: Bool { scheduleKind == .idea }

    /// The SF Symbol to display for this item. Falls back to the category's icon when no override is set,
    /// and further falls back via `IconCatalog.resolvedSymbolName` if the chosen symbol doesn't render
    /// on the current macOS (e.g. data saved on a newer SF Symbols release opened on an older one).
    var effectiveIcon: String {
        let trimmed = customIcon?.trimmingCharacters(in: .whitespaces) ?? ""
        let preferred = trimmed.isEmpty ? category.icon : trimmed
        return IconCatalog.resolvedSymbolName(preferred, fallback: category.icon)
    }

    var frequencyDescription: String {
        switch scheduleKind {
        case .seasonal:
            return seasonalWindow?.description ?? "Seasonal"
        case .oneTime:
            return "Do by \(startDate.shortDate)"
        case .idea:
            return "Idea"
        case .recurring:
            if frequencyInterval == 1 {
                return "Every \(frequencyUnit.singular)"
            }
            return "Every \(frequencyInterval) \(frequencyUnit.label.lowercased())"
        }
    }
}
