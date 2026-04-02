import Foundation

struct HomeProfile: Codable, Equatable, Sendable {
    var address: String = ""
    var yearBuilt: Int?
    var squareFootage: Int?
    var notes: String = ""

    var systems: [HomeSystem] = []

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
