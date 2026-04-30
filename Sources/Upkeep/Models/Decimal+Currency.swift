import Foundation

extension Decimal {
    /// Parses common currency input — accepts "$50", "$1,234.56", "1,234", "50.00", "-5",
    /// trims whitespace, and strips currency symbols, commas, and other formatting chars.
    /// Returns nil only when no numeric digits remain.
    static func fromCurrencyInput(_ raw: String) -> Decimal? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let stripped = trimmed.filter { $0.isNumber || $0 == "." || $0 == "-" }
        guard !stripped.isEmpty else { return nil }
        return Decimal(string: stripped)
    }
}
