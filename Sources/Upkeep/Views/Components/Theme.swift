import SwiftUI

// MARK: - Brand Colors

extension Color {
    static let upkeepAmber = Color(nsColor: .init(name: "upkeepAmber") { appearance in
        appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
            ? NSColor(red: 0.90, green: 0.65, blue: 0.25, alpha: 1)
            : NSColor(red: 0.75, green: 0.50, blue: 0.15, alpha: 1)
    })
    static let upkeepAmberLight = Color(nsColor: .init(name: "upkeepAmberLight") { appearance in
        appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
            ? NSColor(red: 1.0, green: 0.78, blue: 0.38, alpha: 1)
            : NSColor(red: 0.85, green: 0.62, blue: 0.22, alpha: 1)
    })
    static let upkeepAmberMuted = Color(nsColor: .init(name: "upkeepAmberMuted") { appearance in
        appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
            ? NSColor(red: 0.90, green: 0.65, blue: 0.25, alpha: 0.18)
            : NSColor(red: 0.75, green: 0.50, blue: 0.15, alpha: 0.12)
    })
    static let upkeepGreen = Color(nsColor: .init(name: "upkeepGreen") { appearance in
        appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
            ? NSColor(red: 0.40, green: 0.85, blue: 0.55, alpha: 1)
            : NSColor(red: 0.25, green: 0.70, blue: 0.40, alpha: 1)
    })
    static let upkeepRed = Color(nsColor: .init(name: "upkeepRed") { appearance in
        appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
            ? NSColor(red: 1.0, green: 0.40, blue: 0.35, alpha: 1)
            : NSColor(red: 0.88, green: 0.28, blue: 0.22, alpha: 1)
    })
    static let upkeepBrown = Color(nsColor: .init(name: "upkeepBrown") { appearance in
        appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
            ? NSColor(red: 0.72, green: 0.55, blue: 0.38, alpha: 1)
            : NSColor(red: 0.55, green: 0.40, blue: 0.25, alpha: 1)
    })
}

extension ShapeStyle where Self == Color {
    static var upkeepAmber: Color { .upkeepAmber }
    static var upkeepAmberLight: Color { .upkeepAmberLight }
    static var upkeepGreen: Color { .upkeepGreen }
    static var upkeepRed: Color { .upkeepRed }
    static var upkeepBrown: Color { .upkeepBrown }

    static func priorityColor(_ priority: Priority) -> Color {
        switch priority {
        case .low: return .secondary
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .upkeepRed
        }
    }

    static func dueDateColor(_ daysUntilDue: Int) -> Color {
        switch daysUntilDue {
        case ..<0: return .upkeepRed
        case 0...7: return .orange
        case 8...14: return .upkeepAmber
        default: return .upkeepGreen
        }
    }

    static func categoryColor(_ category: MaintenanceCategory) -> Color {
        switch category {
        case .hvac: return Color(red: 0.2, green: 0.6, blue: 1.0)
        case .plumbing: return Color(red: 0.0, green: 0.7, blue: 0.85)
        case .electrical: return Color(red: 1.0, green: 0.75, blue: 0.0)
        case .exterior: return Color(red: 0.45, green: 0.75, blue: 0.35)
        case .interior: return Color(red: 0.7, green: 0.5, blue: 1.0)
        case .appliances: return Color(red: 0.55, green: 0.55, blue: 0.65)
        case .lawnAndGarden: return Color(red: 0.3, green: 0.8, blue: 0.4)
        case .safety: return Color(red: 1.0, green: 0.3, blue: 0.3)
        case .seasonal: return Color(red: 0.9, green: 0.55, blue: 0.2)
        case .other: return .upkeepBrown
        }
    }
}

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    var isHovered: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.background)
                    .shadow(color: .black.opacity(isHovered ? 0.12 : 0.06), radius: isHovered ? 6 : 3, y: isHovered ? 2 : 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.separator.opacity(0.3), lineWidth: 0.5)
            )
    }
}

extension View {
    func cardStyle(isHovered: Bool = false) -> some View {
        modifier(CardStyle(isHovered: isHovered))
    }
}

// MARK: - Priority Badge

struct PriorityBadge: View {
    let priority: Priority

    var body: some View {
        Image(systemName: priority.icon)
            .font(.caption2)
            .foregroundStyle(Color.priorityColor(priority))
    }
}

// MARK: - Category Badge

struct CategoryBadge: View {
    let category: MaintenanceCategory
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
                .font(compact ? .system(size: 9) : .caption2)
            if !compact {
                Text(category.label)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 2 : 3)
        .background(Color.categoryColor(category).opacity(0.12))
        .foregroundStyle(Color.categoryColor(category))
        .clipShape(Capsule())
    }
}

// MARK: - Due Date Badge

struct DueDateBadge: View {
    let daysUntilDue: Int

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.dueDateColor(daysUntilDue).opacity(0.12))
            .foregroundStyle(Color.dueDateColor(daysUntilDue))
            .clipShape(Capsule())
    }

    private var label: String {
        DueDateText.badge(days: daysUntilDue)
    }
}

// MARK: - Supply Badge

struct SupplyBadge: View {
    let supply: Supply

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: supply.isOutOfStock ? "exclamationmark.triangle.fill" : "shippingbox")
                .font(.system(size: 9))
            Text(supply.isOutOfStock ? "Reorder" : "\(supply.stockOnHand) left")
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background((supply.isOutOfStock ? Color.upkeepRed : .orange).opacity(0.12))
        .foregroundStyle(supply.isOutOfStock ? .upkeepRed : .orange)
        .clipShape(Capsule())
    }
}

// MARK: - Add Button (circle +)

struct AddCircleButton: View {
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.upkeepAmber)
                .frame(width: 28, height: 28)
                .background(Color.upkeepAmber.opacity(0.15))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

func addButton(action: @escaping @MainActor () -> Void) -> AddCircleButton {
    AddCircleButton(action: action)
}

// MARK: - Rating Picker

struct RatingPicker: View {
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    rating = rating == star ? 0 : star
                } label: {
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .font(.callout)
                        .foregroundStyle(star <= rating ? ratingColor(rating) : .secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func ratingColor(_ rating: Int) -> Color {
        switch rating {
        case 1...2: return .upkeepRed
        case 3: return .upkeepAmber
        case 4...5: return .upkeepGreen
        default: return .secondary
        }
    }
}

// MARK: - Rating Display (read-only)

struct RatingDisplay: View {
    let rating: Int?

    var body: some View {
        if let rating, rating > 0 {
            HStack(spacing: 1) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .font(.system(size: 9))
                        .foregroundStyle(star <= rating ? ratingColor(rating) : .secondary.opacity(0.3))
                }
            }
        }
    }

    private func ratingColor(_ rating: Int) -> Color {
        switch rating {
        case 1...2: return .upkeepRed
        case 3: return .upkeepAmber
        case 4...5: return .upkeepGreen
        default: return .secondary
        }
    }
}

// MARK: - Cost Display

struct CostText: View {
    let cost: Decimal?

    var body: some View {
        if let cost, let formatted = format(cost) {
            Text(formatted)
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundStyle(.upkeepAmber)
        }
    }

    private func format(_ value: Decimal) -> String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: value as NSDecimalNumber)
    }
}
