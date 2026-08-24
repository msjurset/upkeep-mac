import Foundation
import SwiftUI

struct Property: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var name: String
    var address: String
    var yearBuilt: Int?
    var squareFootage: Int?
    var notes: String
    var icon: String
    var isPrimary: Bool

    /// Cached geocoded coordinates of `address`. Used by the weather widget.
    var latitude: Double?
    var longitude: Double?
    var geocodedAddress: String?

    var systems: [HomeProfile.HomeSystem]

    var createdAt: Date
    var updatedAt: Date

    var hasCoordinates: Bool { latitude != nil && longitude != nil }

    /// True when `address` differs from the address that was geocoded.
    var needsGeocoding: Bool {
        let a = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !a.isEmpty else { return false }
        return a != (geocodedAddress ?? "")
    }

    init(
        id: UUID = UUID(),
        name: String = "Primary Home",
        address: String = "",
        yearBuilt: Int? = nil,
        squareFootage: Int? = nil,
        notes: String = "",
        icon: String = "house.fill",
        isPrimary: Bool = false,
        latitude: Double? = nil,
        longitude: Double? = nil,
        geocodedAddress: String? = nil,
        systems: [HomeProfile.HomeSystem] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.yearBuilt = yearBuilt
        self.squareFootage = squareFootage
        self.notes = notes
        self.icon = icon
        self.isPrimary = isPrimary
        self.latitude = latitude
        self.longitude = longitude
        self.geocodedAddress = geocodedAddress
        self.systems = systems
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Primary Home"
        address = try c.decodeIfPresent(String.self, forKey: .address) ?? ""
        yearBuilt = try c.decodeIfPresent(Int.self, forKey: .yearBuilt)
        squareFootage = try c.decodeIfPresent(Int.self, forKey: .squareFootage)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "house.fill"
        isPrimary = try c.decodeIfPresent(Bool.self, forKey: .isPrimary) ?? false
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        geocodedAddress = try c.decodeIfPresent(String.self, forKey: .geocodedAddress)
        systems = try c.decodeIfPresent([HomeProfile.HomeSystem].self, forKey: .systems) ?? []
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
    }
}

// MARK: - Reusable Property Icon Views

struct PropertyIconView: View {
    let icon: String
    var font: Font = .body

    init(_ icon: String, font: Font = .body) {
        self.icon = icon
        self.font = font
    }

    var body: some View {
        if icon == "cabin.log" || icon == "cabin" || icon == "house.lodge.fill" {
            Image("cabin.log")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: icon)
                .font(font)
        }
    }
}

struct PropertyLabel: View {
    let title: String
    let icon: String

    init(_ title: String, icon: String) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            PropertyIconView(icon)
        }
    }
}
