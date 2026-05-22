import Foundation

/// A timed sub-task within a `MaintenanceItem`. Sub-events let one item track
/// several distinct events on different dates — e.g. a lawn-care program with
/// 13 timed treatments per year, or an HVAC item with separate electrical /
/// plumbing / HVAC inspections.
///
/// A sub-event inherits its parent item's recurrence:
/// - If the parent's `scheduleKind` is `.seasonal` or `.recurring`, a sub-event's
///   `seasonalWindow` repeats every cycle (typically once per year).
/// - If the parent's `scheduleKind` is `.oneTime`, a sub-event's `dueDate` is an
///   absolute calendar date — the parent item is a project broken into stages.
///
/// At most one of `seasonalWindow` / `dueDate` should be set per sub-event.
struct SubEvent: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var seasonalWindow: SeasonalWindow?
    var dueDate: Date?
    var notes: String
    /// Optional vendor override — when nil, the parent item's vendor applies.
    /// Useful for items like HVAC where each sub-event has a different specialist.
    var vendorID: UUID?
    /// Skip this sub-event for one specific year (the parent item's
    /// `skippedYear` skips ALL sub-events for that year).
    var skippedYear: Int?
    /// Snooze this sub-event until a date (parent's `snoozedUntil` snoozes all).
    var snoozedUntil: Date?
    var version: Int
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String,
         seasonalWindow: SeasonalWindow? = nil, dueDate: Date? = nil,
         notes: String = "", vendorID: UUID? = nil,
         skippedYear: Int? = nil, snoozedUntil: Date? = nil,
         version: Int = 1, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.name = name
        self.seasonalWindow = seasonalWindow
        self.dueDate = dueDate
        self.notes = notes
        self.vendorID = vendorID
        self.skippedYear = skippedYear
        self.snoozedUntil = snoozedUntil
        self.version = version
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        seasonalWindow = try container.decodeIfPresent(SeasonalWindow.self, forKey: .seasonalWindow)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        vendorID = try container.decodeIfPresent(UUID.self, forKey: .vendorID)
        skippedYear = try container.decodeIfPresent(Int.self, forKey: .skippedYear)
        snoozedUntil = try container.decodeIfPresent(Date.self, forKey: .snoozedUntil)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
    }

    var isSnoozed: Bool {
        guard let snoozedUntil else { return false }
        return snoozedUntil > .now
    }

    mutating func touch() {
        updatedAt = .now
        version += 1
    }
}
