import Foundation

struct Vendor: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var phone: String
    var email: String
    var website: String
    var specialty: String
    var notes: String
    var version: Int
    var lastModifiedBy: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, phone: String = "",
         email: String = "", website: String = "", specialty: String = "",
         notes: String = "", version: Int = 1, lastModifiedBy: UUID? = nil,
         createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.name = name
        self.phone = phone
        self.email = email
        self.website = website
        self.specialty = specialty
        self.notes = notes
        self.version = version
        self.lastModifiedBy = lastModifiedBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        phone = try container.decode(String.self, forKey: .phone)
        email = try container.decode(String.self, forKey: .email)
        website = try container.decode(String.self, forKey: .website)
        specialty = try container.decode(String.self, forKey: .specialty)
        notes = try container.decode(String.self, forKey: .notes)
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

    var hasContactInfo: Bool {
        !phone.isEmpty || !email.isEmpty || !website.isEmpty
    }
}
