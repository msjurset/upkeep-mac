import Foundation

struct Supply: Codable, Hashable, Sendable {
    var stockOnHand: Int
    var quantityPerUse: Int
    var productName: String
    var productURL: String
    var unitCost: Decimal?
    /// Set when the user dismisses the dashboard "Reorder Needed" reminder.
    /// Reorder alerts auto-resurface after 30 days, or when stock changes
    /// (callers clear this on restock).
    var reorderDismissedAt: Date?

    init(stockOnHand: Int = 0, quantityPerUse: Int = 1,
         productName: String = "", productURL: String = "",
         unitCost: Decimal? = nil, reorderDismissedAt: Date? = nil) {
        self.stockOnHand = stockOnHand
        self.quantityPerUse = quantityPerUse
        self.productName = productName
        self.productURL = productURL
        self.unitCost = unitCost
        self.reorderDismissedAt = reorderDismissedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stockOnHand = try container.decodeIfPresent(Int.self, forKey: .stockOnHand) ?? 0
        quantityPerUse = try container.decodeIfPresent(Int.self, forKey: .quantityPerUse) ?? 1
        productName = try container.decodeIfPresent(String.self, forKey: .productName) ?? ""
        productURL = try container.decodeIfPresent(String.self, forKey: .productURL) ?? ""
        unitCost = try container.decodeIfPresent(Decimal.self, forKey: .unitCost)
        reorderDismissedAt = try container.decodeIfPresent(Date.self, forKey: .reorderDismissedAt)
    }

    var usesRemaining: Int {
        guard quantityPerUse > 0 else { return 0 }
        return stockOnHand / quantityPerUse
    }

    var needsReorder: Bool {
        stockOnHand < quantityPerUse * 2
    }

    var isOutOfStock: Bool {
        stockOnHand < quantityPerUse
    }

    /// Whether the dismiss flag is still active. Auto-expires after 30 days
    /// so the user gets re-reminded if they dismissed and never restocked.
    var isReorderDismissalActive: Bool {
        guard let dismissed = reorderDismissedAt else { return false }
        let daysSince = Calendar.current.dateComponents([.day], from: dismissed, to: .now).day ?? 0
        return daysSince < 30
    }

    var unitCostFormatted: String? {
        guard let unitCost else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: unitCost as NSDecimalNumber)
    }
}
