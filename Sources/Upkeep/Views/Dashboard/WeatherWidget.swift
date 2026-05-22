import SwiftUI

struct WeatherWidget: View {
    @Environment(WeatherStore.self) private var weather
    @Environment(UpkeepStore.self) private var store
    @State private var showDetail = false
    @State private var profileAddress: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if !weather.forecast.daily.isEmpty {
                actionableCaption

                Button { showDetail = true } label: {
                    forecastStrip
                }
                .buttonStyle(.plain)
                .help("Click for full forecast")
            } else if weather.isLoading {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading forecast...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            } else if let error = weather.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.upkeepRed)
            } else {
                emptyState
            }
        }
        .panelStyle()
        .task {
            // First load: fetch the home profile address & re-apply location.
            if let profile = try? await store.loadHomeProfile() {
                profileAddress = profile.address
                weather.applyLocation(latitude: profile.latitude, longitude: profile.longitude)
            }
        }
        .sheet(isPresented: $showDetail) {
            WeatherDetailSheet(address: profileAddress)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "cloud.sun.fill")
                .font(.subheadline)
                .foregroundStyle(.upkeepAmber)
            Text("Weather")
                .font(.headline)
            if !profileAddress.isEmpty {
                Text("· \(profileAddress)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
            if weather.isLoading {
                ProgressView().controlSize(.small)
            } else if !weather.forecast.daily.isEmpty {
                Button {
                    weather.refresh(force: true)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Refresh forecast")
            }
        }
    }

    private var actionableCaption: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(captions, id: \.self) { line in
                HStack(spacing: 6) {
                    Image(systemName: line.icon)
                        .font(.caption)
                        .foregroundStyle(line.tint)
                        .frame(width: 14)
                    Text(line.text)
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private struct Caption: Hashable {
        let icon: String
        let tint: Color
        let text: String
    }

    private var captions: [Caption] {
        var lines: [Caption] = []
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        if let wet = weather.nextWetDay {
            let days = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: wet.date)).day ?? 0
            let when: String = switch days {
            case ...0: "today"
            case 1: "tomorrow"
            default: wet.date.formatted(.dateTime.weekday(.wide))
            }
            lines.append(Caption(
                icon: "drop.fill",
                tint: .blue,
                text: "Next rain: \(when) (\(wet.precipitationProbability)% — \(String(format: "%.2f", wet.precipitationInches))\")"
            ))
        } else {
            lines.append(Caption(icon: "sun.max.fill", tint: .yellow,
                                 text: "No rain in the 14-day forecast"))
        }

        if let window = weather.nextSprayWindow {
            let days = cal.dateComponents([.day], from: window.lowerBound, to: window.upperBound).day ?? 0
            let label: String
            if days == 0 {
                label = window.lowerBound.formatted(.dateTime.weekday(.wide))
            } else {
                let s = window.lowerBound.formatted(.dateTime.month(.abbreviated).day())
                let e = window.upperBound.formatted(.dateTime.month(.abbreviated).day())
                label = "\(s) – \(e)"
            }
            lines.append(Caption(
                icon: "leaf.fill",
                tint: .upkeepGreen,
                text: "Good for spraying/painting: \(label)"
            ))
        }

        if let frost = weather.nextFrostDay {
            let days = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: frost.date)).day ?? 0
            let when: String = switch days {
            case ...0: "tonight"
            case 1: "tomorrow night"
            default: frost.date.formatted(.dateTime.weekday(.wide))
            }
            lines.append(Caption(
                icon: "snowflake",
                tint: .cyan,
                text: "Frost risk \(when) (low \(Int(frost.lowF))°F)"
            ))
        }

        if let uv = weather.nextHighUVDay {
            let days = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: uv.date)).day ?? 0
            if days <= 2 {
                let when = days <= 0 ? "today" : (days == 1 ? "tomorrow" : uv.date.formatted(.dateTime.weekday(.wide)))
                lines.append(Caption(
                    icon: "sun.max.trianglebadge.exclamationmark.fill",
                    tint: .orange,
                    text: "Very high UV \(when) (\(Int(uv.uvIndex)))"
                ))
            }
        }

        return lines
    }

    private var forecastStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(weather.forecast.daily) { day in
                    dayColumn(day)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity)
        .background(.secondary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func dayColumn(_ day: DailyForecast) -> some View {
        VStack(spacing: 3) {
            Text(day.dayAbbrev)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
            Image(systemName: day.symbol)
                .font(.system(size: 13))
                .foregroundStyle(day.symbolColor)
                .frame(height: 16)
            Text("\(Int(day.highF))°")
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
            Text("\(Int(day.lowF))°")
                .font(.system(size: 9).monospacedDigit())
                .foregroundStyle(.tertiary)
            HStack(spacing: 1) {
                if day.precipitationProbability > 20 {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.cyan)
                    Text("\(day.precipitationProbability)%")
                        .font(.system(size: 7).monospacedDigit())
                        .foregroundStyle(.cyan)
                } else {
                    Text(" ")
                        .font(.system(size: 7).monospacedDigit())
                }
            }
            .frame(height: 10)
        }
        .frame(width: 38)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "location.slash")
                .font(.title3)
                .foregroundStyle(.tertiary)
            Text("Set your home address in Settings to see weather here.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}

// MARK: - Detail Sheet

struct WeatherDetailSheet: View {
    let address: String
    @Environment(WeatherStore.self) private var weather
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weather Forecast")
                        .font(.headline)
                    if !address.isEmpty {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button { weather.refresh(force: true) } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(weather.forecast.daily.enumerated()), id: \.element.id) { index, day in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(day.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                                    .font(.callout.weight(.medium))
                                HStack(spacing: 4) {
                                    Image(systemName: day.symbol)
                                        .foregroundStyle(day.symbolColor)
                                        .font(.callout)
                                    Text(day.condition)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 160, alignment: .leading)

                            VStack(spacing: 1) {
                                Text("\(Int(day.highF))°/\(Int(day.lowF))°")
                                    .font(.callout.weight(.semibold).monospacedDigit())
                                Text("Feels \(Int(day.feelsLikeHighF))°/\(Int(day.feelsLikeLowF))°")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 90)

                            VStack(spacing: 1) {
                                HStack(spacing: 2) {
                                    Image(systemName: "drop.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.cyan)
                                    Text("\(day.precipitationProbability)%")
                                        .font(.caption.monospacedDigit())
                                }
                                if day.precipitationInches > 0 {
                                    Text(String(format: "%.2f\"", day.precipitationInches))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 60)

                            VStack(spacing: 1) {
                                HStack(spacing: 2) {
                                    Image(systemName: "wind")
                                        .font(.caption2)
                                    Text("\(Int(day.windSpeedMph))")
                                        .font(.caption.monospacedDigit())
                                }
                                Text("gust \(Int(day.windGustMph))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 60)

                            VStack(spacing: 1) {
                                HStack(spacing: 2) {
                                    Image(systemName: "humidity.fill")
                                        .font(.caption2)
                                    Text("\(day.humidity)%")
                                        .font(.caption.monospacedDigit())
                                }
                                Text("UV \(Int(day.uvIndex))")
                                    .font(.caption2)
                                    .foregroundStyle(day.uvIndex >= 6 ? .orange : .secondary)
                            }
                            .frame(width: 60)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(index.isMultiple(of: 2) ? Color.secondary.opacity(0.04) : .clear)
                    }
                }
            }

            Divider()

            HStack {
                Text("Powered by Open-Meteo")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 640, height: 480)
    }
}
