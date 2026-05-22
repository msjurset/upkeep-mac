import Foundation
import SwiftUI

/// Owns the cached forecast for the home location. Refreshes once per app launch and
/// then every 6 hours. Views observe `forecast`, `isLoading`, and `error`.
@Observable
@MainActor
final class WeatherStore {
    private(set) var forecast: Forecast = .empty
    private(set) var isLoading = false
    private(set) var error: String?

    private var latitude: Double?
    private var longitude: Double?
    private var refreshTimer: Timer?
    private var inFlight: Task<Void, Never>?

    /// Refresh forecast at most every this many seconds when `refresh()` is called
    /// without `force`.
    private let staleAfter: TimeInterval = 60 * 60 * 6

    init() {}

    /// Call once after `HomeProfile` has loaded.
    func applyLocation(latitude: Double?, longitude: Double?) {
        let changed = latitude != self.latitude || longitude != self.longitude
        self.latitude = latitude
        self.longitude = longitude
        guard latitude != nil, longitude != nil else {
            forecast = .empty
            error = nil
            return
        }
        if changed || forecast.daily.isEmpty {
            refresh(force: true)
        }
    }

    func refresh(force: Bool = false) {
        guard let lat = latitude, let lon = longitude else { return }
        if !force, !forecast.daily.isEmpty,
           Date.now.timeIntervalSince(forecast.fetchedAt) < staleAfter {
            return
        }
        inFlight?.cancel()
        isLoading = true
        error = nil
        inFlight = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await WeatherService.shared.fetchForecast(latitude: lat, longitude: lon)
                if Task.isCancelled { return }
                self.forecast = result
                self.error = nil
            } catch {
                if Task.isCancelled { return }
                self.error = "Unable to load forecast: \(error.localizedDescription)"
            }
            self.isLoading = false
        }
    }

    func startBackgroundRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh(force: false) }
        }
    }

    func stopBackgroundRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Lookups

    /// The daily forecast covering `date`, if any.
    func forecast(for date: Date) -> DailyForecast? {
        let cal = Calendar.current
        let target = cal.startOfDay(for: date)
        return forecast.daily.first { cal.startOfDay(for: $0.date) == target }
    }

    /// The next day in the forecast that is "likely wet". Returns `nil` if no rain in the window.
    var nextWetDay: DailyForecast? {
        forecast.daily.first { $0.isLikelyWet }
    }

    /// The longest contiguous run of dry, low-wind days starting from today.
    var nextSprayWindow: ClosedRange<Date>? {
        guard !forecast.daily.isEmpty else { return nil }
        var bestStart: Date?
        var bestEnd: Date?
        var bestLength = 0
        var currentStart: Date?
        var currentEnd: Date?
        var currentLength = 0
        for f in forecast.daily {
            let good = !f.isLikelyWet && f.windSpeedMph < 10 && f.windGustMph < 15
            if good {
                if currentStart == nil { currentStart = f.date }
                currentEnd = f.date
                currentLength += 1
            } else {
                if currentLength > bestLength, let s = currentStart, let e = currentEnd {
                    bestLength = currentLength
                    bestStart = s
                    bestEnd = e
                }
                currentStart = nil
                currentEnd = nil
                currentLength = 0
            }
        }
        if currentLength > bestLength, let s = currentStart, let e = currentEnd {
            bestStart = s
            bestEnd = e
        }
        guard let s = bestStart, let e = bestEnd else { return nil }
        return s...e
    }

    /// The next day with low <= 32°F, if any.
    var nextFrostDay: DailyForecast? {
        forecast.daily.first { $0.isFrosty }
    }

    /// The next day with very high UV (>= 8), if any.
    var nextHighUVDay: DailyForecast? {
        forecast.daily.first { $0.isHighUV }
    }
}
