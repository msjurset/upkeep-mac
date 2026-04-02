import Foundation

enum FrequencyUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case days
    case weeks
    case months
    case years

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    var singular: String {
        String(rawValue.dropLast())
    }
}
