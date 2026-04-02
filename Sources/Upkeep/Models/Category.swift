import Foundation

enum MaintenanceCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case hvac
    case plumbing
    case electrical
    case exterior
    case interior
    case appliances
    case lawnAndGarden
    case safety
    case seasonal
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hvac: return "HVAC"
        case .plumbing: return "Plumbing"
        case .electrical: return "Electrical"
        case .exterior: return "Exterior"
        case .interior: return "Interior"
        case .appliances: return "Appliances"
        case .lawnAndGarden: return "Lawn & Garden"
        case .safety: return "Safety"
        case .seasonal: return "Seasonal"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .hvac: return "fan"
        case .plumbing: return "drop"
        case .electrical: return "bolt"
        case .exterior: return "house"
        case .interior: return "sofa"
        case .appliances: return "washer"
        case .lawnAndGarden: return "leaf"
        case .safety: return "shield.checkered"
        case .seasonal: return "calendar"
        case .other: return "wrench"
        }
    }
}
