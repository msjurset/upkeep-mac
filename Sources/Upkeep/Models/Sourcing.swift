import Foundation

enum SourcingStatus: String, Codable, CaseIterable, Sendable {
    case open
    case decided
    case cancelled

    var label: String {
        switch self {
        case .open: "Open"
        case .decided: "Decided"
        case .cancelled: "Cancelled"
        }
    }
}

enum CandidateStatus: String, Codable, CaseIterable, Sendable {
    case notContacted
    case contacted
    case quoted
    case declined
    case hired

    var label: String {
        switch self {
        case .notContacted: "Not contacted"
        case .contacted: "Contacted"
        case .quoted: "Quoted"
        case .declined: "Declined"
        case .hired: "Hired"
        }
    }

    var sortOrder: Int {
        switch self {
        case .hired: return 0
        case .quoted: return 1
        case .contacted: return 2
        case .notContacted: return 3
        case .declined: return 4
        }
    }

    /// Candidates at or above this threshold are promoted to inactive Vendor records on close.
    var reachedQuoted: Bool {
        switch self {
        case .quoted, .hired: return true
        case .notContacted, .contacted, .declined: return false
        }
    }
}

struct Candidate: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var phone: String
    var email: String
    var source: String
    var status: CandidateStatus
    var quoteAmount: Decimal?
    var notes: String
    var attachments: [Attachment]
    var createdAt: Date
    var promotedToVendorID: UUID?

    init(id: UUID = UUID(), name: String, phone: String = "", email: String = "",
         source: String = "", status: CandidateStatus = .notContacted,
         quoteAmount: Decimal? = nil, notes: String = "",
         attachments: [Attachment] = [], createdAt: Date = .now,
         promotedToVendorID: UUID? = nil) {
        self.id = id
        self.name = name
        self.phone = phone
        self.email = email
        self.source = source
        self.status = status
        self.quoteAmount = quoteAmount
        self.notes = notes
        self.attachments = attachments
        self.createdAt = createdAt
        self.promotedToVendorID = promotedToVendorID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        phone = try container.decodeIfPresent(String.self, forKey: .phone) ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? ""
        status = try container.decodeIfPresent(CandidateStatus.self, forKey: .status) ?? .notContacted
        quoteAmount = try container.decodeIfPresent(Decimal.self, forKey: .quoteAmount)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        attachments = try container.decodeIfPresent([Attachment].self, forKey: .attachments) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        promotedToVendorID = try container.decodeIfPresent(UUID.self, forKey: .promotedToVendorID)
    }
}

struct Sourcing: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var linkedItemIDs: [UUID]
    var replacingVendorID: UUID?
    var status: SourcingStatus
    var decideBy: Date?
    var notes: String
    var candidates: [Candidate]
    var hiredCandidateID: UUID?
    var cancelReason: String
    var version: Int
    var lastModifiedBy: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, linkedItemIDs: [UUID] = [],
         replacingVendorID: UUID? = nil, status: SourcingStatus = .open,
         decideBy: Date? = nil, notes: String = "",
         candidates: [Candidate] = [], hiredCandidateID: UUID? = nil,
         cancelReason: String = "", version: Int = 1,
         lastModifiedBy: UUID? = nil, createdAt: Date = .now,
         updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.linkedItemIDs = linkedItemIDs
        self.replacingVendorID = replacingVendorID
        self.status = status
        self.decideBy = decideBy
        self.notes = notes
        self.candidates = candidates
        self.hiredCandidateID = hiredCandidateID
        self.cancelReason = cancelReason
        self.version = version
        self.lastModifiedBy = lastModifiedBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        // Read new plural form first; fall back to legacy single-ID form for pre-multi sourcings.
        if let arr = try container.decodeIfPresent([UUID].self, forKey: .linkedItemIDs) {
            linkedItemIDs = arr
        } else if let legacy = try container.decodeIfPresent(UUID.self, forKey: .linkedItemID) {
            linkedItemIDs = [legacy]
        } else {
            linkedItemIDs = []
        }
        replacingVendorID = try container.decodeIfPresent(UUID.self, forKey: .replacingVendorID)
        status = try container.decodeIfPresent(SourcingStatus.self, forKey: .status) ?? .open
        decideBy = try container.decodeIfPresent(Date.self, forKey: .decideBy)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        candidates = try container.decodeIfPresent([Candidate].self, forKey: .candidates) ?? []
        hiredCandidateID = try container.decodeIfPresent(UUID.self, forKey: .hiredCandidateID)
        cancelReason = try container.decodeIfPresent(String.self, forKey: .cancelReason) ?? ""
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        lastModifiedBy = try container.decodeIfPresent(UUID.self, forKey: .lastModifiedBy)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, linkedItemIDs, linkedItemID, replacingVendorID, status,
             decideBy, notes, candidates, hiredCandidateID, cancelReason,
             version, lastModifiedBy, createdAt, updatedAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(linkedItemIDs, forKey: .linkedItemIDs)
        // Backward-compat dual-write: pre-multi clients (e.g. household members on the older
        // build sharing the same Google Drive folder) read `linkedItemID` as a single UUID.
        // Writing the first ID lets them load without errors. They'll only see the first
        // linked item and degrade to single-link semantics on edit, but won't crash.
        try container.encodeIfPresent(linkedItemIDs.first, forKey: .linkedItemID)
        try container.encodeIfPresent(replacingVendorID, forKey: .replacingVendorID)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(decideBy, forKey: .decideBy)
        try container.encode(notes, forKey: .notes)
        try container.encode(candidates, forKey: .candidates)
        try container.encodeIfPresent(hiredCandidateID, forKey: .hiredCandidateID)
        try container.encode(cancelReason, forKey: .cancelReason)
        try container.encode(version, forKey: .version)
        try container.encodeIfPresent(lastModifiedBy, forKey: .lastModifiedBy)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    mutating func touch(by memberID: UUID? = nil) {
        updatedAt = .now
        version += 1
        if let memberID { lastModifiedBy = memberID }
    }

    var isOpen: Bool { status == .open }

    var hiredCandidate: Candidate? {
        guard let hiredCandidateID else { return nil }
        return candidates.first { $0.id == hiredCandidateID }
    }

    /// Days since the most recent candidate was added or the sourcing was created, whichever is later.
    var daysSinceLastActivity: Int {
        let mostRecent = candidates.map(\.createdAt).max() ?? createdAt
        let seconds = Date.now.timeIntervalSince(mostRecent)
        return max(0, Int(seconds / 86400))
    }
}
