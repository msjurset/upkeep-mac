import SwiftUI

/// Compact weather strip shown on item detail / editor for outdoor items with a
/// due date inside the forecast window. Surfaces the conditions on the due date
/// and, if those conditions are poor (rain, high wind), a nearby alternative day.
struct ItemWeatherHint: View {
    @Environment(WeatherStore.self) private var weather
    @Environment(UpkeepStore.self) private var store
    let item: MaintenanceItem

    private static let outdoorCategories: Set<MaintenanceCategory> = [
        .lawnAndGarden, .exterior, .seasonal
    ]

    var body: some View {
        if shouldShow, let forecast = weather.forecast(for: dueDate) {
            content(for: forecast)
        }
    }

    private var shouldShow: Bool {
        guard item.isActive, !item.isIdea else { return false }
        guard Self.outdoorCategories.contains(item.category) else { return false }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: cal.startOfDay(for: dueDate)).day ?? 0
        return days >= 0 && days <= 13
    }

    private var dueDate: Date { store.nextDueDate(for: item) }

    @ViewBuilder
    private func content(for day: DailyForecast) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "cloud.sun.fill")
                    .font(.caption)
                    .foregroundStyle(.upkeepAmber)
                Text("Weather on due date")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 10) {
                Image(systemName: day.symbol)
                    .font(.title3)
                    .foregroundStyle(day.symbolColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(day.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())) — \(day.condition)")
                        .font(.callout.weight(.medium))

                    HStack(spacing: 10) {
                        Label("\(Int(day.highF))°/\(Int(day.lowF))°",
                              systemImage: "thermometer.medium")
                            .labelStyle(.titleAndIcon)
                        if day.precipitationProbability > 0 {
                            Label("\(day.precipitationProbability)% rain", systemImage: "drop.fill")
                        }
                        if day.windSpeedMph >= 5 {
                            Label("\(Int(day.windSpeedMph)) mph", systemImage: "wind")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if let badge = verdict(for: day) {
                    Text(badge.text)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(badge.tint.opacity(0.18)))
                        .foregroundStyle(badge.tint)
                }
            }

            if let suggestion = alternativeSuggestion(currentDay: day) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.turn.up.right")
                        .font(.caption2)
                        .foregroundStyle(.upkeepGreen)
                    Text(suggestion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .cardStyle()
    }

    private struct Verdict {
        let text: String
        let tint: Color
    }

    private func verdict(for day: DailyForecast) -> Verdict? {
        if day.isLikelyWet { return Verdict(text: "Likely wet", tint: .blue) }
        if day.isWindy {
            return Verdict(text: "Windy", tint: .upkeepAmber)
        }
        if day.isFrosty { return Verdict(text: "Frost", tint: .cyan) }
        if isOutdoorWorkFriendly(day) { return Verdict(text: "Looks good", tint: .upkeepGreen) }
        return nil
    }

    private func isOutdoorWorkFriendly(_ day: DailyForecast) -> Bool {
        !day.isLikelyWet && !day.isWindy && day.highF >= 45 && day.highF <= 90
    }

    private func alternativeSuggestion(currentDay: DailyForecast) -> String? {
        // Only suggest if the due date isn't already friendly.
        guard !isOutdoorWorkFriendly(currentDay) else { return nil }
        let cal = Calendar.current
        let dueStart = cal.startOfDay(for: currentDay.date)
        // Look at days within +/- 3 days of due date, prefer the closest friendly one.
        let candidates = weather.forecast.daily
            .filter { day in
                let delta = cal.dateComponents([.day], from: dueStart, to: cal.startOfDay(for: day.date)).day ?? 0
                return abs(delta) <= 3 && delta != 0 && isOutdoorWorkFriendly(day)
            }
            .sorted { a, b in
                let da = abs(cal.dateComponents([.day], from: dueStart, to: cal.startOfDay(for: a.date)).day ?? 0)
                let db = abs(cal.dateComponents([.day], from: dueStart, to: cal.startOfDay(for: b.date)).day ?? 0)
                return da < db
            }
        guard let pick = candidates.first else { return nil }
        let day = pick.date.formatted(.dateTime.weekday(.wide))
        return "Better window: \(day) (\(Int(pick.highF))°, \(pick.precipitationProbability)% rain)"
    }
}
