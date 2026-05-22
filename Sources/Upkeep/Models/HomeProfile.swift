import Foundation

struct HomeProfile: Codable, Equatable, Sendable {
    var address: String = ""
    var yearBuilt: Int?
    var squareFootage: Int?
    var notes: String = ""

    /// Cached geocoded coordinates of `address`. Refreshed by the home-profile editor
    /// whenever the address changes. Used by the weather widget.
    var latitude: Double?
    var longitude: Double?
    /// The exact address string that produced the cached coordinates. Used to detect
    /// stale geocoding when the user edits `address`.
    var geocodedAddress: String?

    var systems: [HomeSystem] = []

    var hasCoordinates: Bool { latitude != nil && longitude != nil }

    /// True when `address` differs from the address that was geocoded.
    var needsGeocoding: Bool {
        let a = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !a.isEmpty else { return false }
        return a != (geocodedAddress ?? "")
    }

    init(
        address: String = "",
        yearBuilt: Int? = nil,
        squareFootage: Int? = nil,
        notes: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        geocodedAddress: String? = nil,
        systems: [HomeSystem] = []
    ) {
        self.address = address
        self.yearBuilt = yearBuilt
        self.squareFootage = squareFootage
        self.notes = notes
        self.latitude = latitude
        self.longitude = longitude
        self.geocodedAddress = geocodedAddress
        self.systems = systems
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        address = try c.decodeIfPresent(String.self, forKey: .address) ?? ""
        yearBuilt = try c.decodeIfPresent(Int.self, forKey: .yearBuilt)
        squareFootage = try c.decodeIfPresent(Int.self, forKey: .squareFootage)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        geocodedAddress = try c.decodeIfPresent(String.self, forKey: .geocodedAddress)
        systems = try c.decodeIfPresent([HomeSystem].self, forKey: .systems) ?? []
    }

    struct HomeSystem: Codable, Identifiable, Equatable, Hashable, Sendable {
        var id: UUID = UUID()
        var name: String
        var brand: String = ""
        var model: String = ""
        var installedDate: Date?
        var expectedLifespanYears: Int?
        var notes: String = ""

        var age: Int? {
            guard let installed = installedDate else { return nil }
            return Calendar.current.dateComponents([.year], from: installed, to: .now).year
        }

        var remainingLifespan: Int? {
            guard let age, let lifespan = expectedLifespanYears else { return nil }
            return max(0, lifespan - age)
        }
    }
}
