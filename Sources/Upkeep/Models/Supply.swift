import Foundation

struct Supply: Codable, Hashable, Sendable {
    var stockOnHand: Int
    var quantityPerUse: Int
    var productName: String
    var productURL: String
    var unitCost: Decimal?

    init(stockOnHand: Int = 0, quantityPerUse: Int = 1,
         productName: String = "", productURL: String = "",
         unitCost: Decimal? = nil) {
        self.stockOnHand = stockOnHand
        self.quantityPerUse = quantityPerUse
        self.productName = productName
        self.productURL = productURL
        self.unitCost = unitCost
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

    var unitCostFormatted: String? {
        guard let unitCost else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: unitCost as NSDecimalNumber)
    }
}
