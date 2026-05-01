import Foundation

struct AccountManager: Codable, Hashable, Sendable {
    var name: String = ""
    var phone: String = ""
    var email: String = ""

    var isEmpty: Bool { name.isEmpty && phone.isEmpty && email.isEmpty }
}

struct Vendor: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var phone: String
    var email: String
    var website: String
    var location: String
    var specialty: String
    var tags: [String]
    var accountManager: AccountManager
    var notes: String
    var source: String
    var isActive: Bool
    var version: Int
    var lastModifiedBy: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, phone: String = "",
         email: String = "", website: String = "", location: String = "",
         specialty: String = "", tags: [String] = [],
         accountManager: AccountManager = AccountManager(),
         notes: String = "", source: String = "", isActive: Bool = true,
         version: Int = 1,
         lastModifiedBy: UUID? = nil, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.name = name
        self.phone = phone
        self.email = email
        self.website = website
        self.location = location
        self.specialty = specialty
        self.tags = tags
        self.accountManager = accountManager
        self.notes = notes
        self.source = source
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
        phone = try container.decode(String.self, forKey: .phone)
        email = try container.decode(String.self, forKey: .email)
        website = try container.decode(String.self, forKey: .website)
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        specialty = try container.decode(String.self, forKey: .specialty)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        accountManager = try container.decodeIfPresent(AccountManager.self, forKey: .accountManager) ?? AccountManager()
        notes = try container.decode(String.self, forKey: .notes)
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? ""
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
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
        !phone.isEmpty || !email.isEmpty || !website.isEmpty || !location.isEmpty
    }

    /// Returns a URL for the location field — detects Plus Codes and wraps them
    /// in a Google Maps search URL, or returns the value directly if already a URL.
    var locationURL: URL? {
        let trimmed = location.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Already a URL
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)
        }

        // Plus Code: contains "+" e.g. "849VCWC8+R9" or "CWC8+R9 Smyrna, Georgia"
        if trimmed.contains("+"),
           let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .replacingOccurrences(of: "+", with: "%2B") {
            return URL(string: "https://www.google.com/maps/search/?api=1&query=\(encoded)")
        }

        // Decimal coordinates: "lat, lng" e.g. "33.828986, -84.493004"
        let parts = trimmed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count == 2, let lat = Double(parts[0]), let lng = Double(parts[1]),
           (-90...90).contains(lat), (-180...180).contains(lng) {
            return URL(string: "https://www.google.com/maps/search/?api=1&query=\(parts[0]),\(parts[1])")
        }

        // DMS coordinates: e.g. 33°49'44.4"N 84°29'34.8"W
        if let (lat, lng) = parseDMS(trimmed) {
            return URL(string: "https://www.google.com/maps/search/?api=1&query=\(lat),\(lng)")
        }

        return nil
    }

    /// Parses DMS (degrees/minutes/seconds) coordinates into decimal lat/lng.
    /// Accepts formats like: `33°49'44.4"N 84°29'34.8"W`
    private static let dmsPattern = #"(\d+)[°]\s*(\d+)[''′]\s*([\d.]+)[""″]?\s*([NSns])\s+(\d+)[°]\s*(\d+)[''′]\s*([\d.]+)[""″]?\s*([EWew])"#

    private func parseDMS(_ input: String) -> (Double, Double)? {
        guard let regex = try? NSRegularExpression(pattern: Self.dmsPattern),
              let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
              match.numberOfRanges == 9 else { return nil }

        func str(_ i: Int) -> String {
            String(input[Range(match.range(at: i), in: input)!])
        }

        guard let latD = Double(str(1)), let latM = Double(str(2)), let latS = Double(str(3)),
              let lngD = Double(str(5)), let lngM = Double(str(6)), let lngS = Double(str(7)) else {
            return nil
        }

        var lat = latD + latM / 60.0 + latS / 3600.0
        var lng = lngD + lngM / 60.0 + lngS / 3600.0

        if str(4).uppercased() == "S" { lat = -lat }
        if str(8).uppercased() == "W" { lng = -lng }

        guard (-90...90).contains(lat), (-180...180).contains(lng) else { return nil }
        return (lat, lng)
    }
}
