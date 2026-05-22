import Foundation
import SwiftUI

struct DailyForecast: Identifiable, Sendable, Hashable {
    let id: UUID
    let date: Date
    let highF: Double
    let lowF: Double
    let feelsLikeHighF: Double
    let feelsLikeLowF: Double
    let weatherCode: Int
    let precipitationInches: Double
    let precipitationProbability: Int
    let windSpeedMph: Double
    let windGustMph: Double
    let humidity: Int
    let uvIndex: Double

    init(date: Date, highF: Double, lowF: Double, feelsLikeHighF: Double = 0, feelsLikeLowF: Double = 0,
         weatherCode: Int, precipitationInches: Double = 0, precipitationProbability: Int = 0,
         windSpeedMph: Double = 0, windGustMph: Double = 0, humidity: Int = 0, uvIndex: Double = 0) {
        self.id = UUID()
        self.date = date
        self.highF = highF
        self.lowF = lowF
        self.feelsLikeHighF = feelsLikeHighF
        self.feelsLikeLowF = feelsLikeLowF
        self.weatherCode = weatherCode
        self.precipitationInches = precipitationInches
        self.precipitationProbability = precipitationProbability
        self.windSpeedMph = windSpeedMph
        self.windGustMph = windGustMph
        self.humidity = humidity
        self.uvIndex = uvIndex
    }

    var condition: String { WeatherCode.description(for: weatherCode) }
    var symbol: String { WeatherCode.sfSymbol(for: weatherCode) }
    var symbolColor: Color { WeatherCode.color(for: weatherCode) }
    var dayAbbrev: String { date.formatted(.dateTime.weekday(.abbreviated)) }
    var dateShort: String { date.formatted(.dateTime.month(.abbreviated).day()) }

    var isLikelyWet: Bool {
        precipitationProbability >= 50 || precipitationInches >= 0.05
    }

    var isWindy: Bool { windSpeedMph >= 12 || windGustMph >= 20 }
    var isFrosty: Bool { lowF <= 32 }
    var isHighUV: Bool { uvIndex >= 8 }
}

struct HourlyForecast: Identifiable, Sendable, Hashable {
    let id: UUID
    let date: Date
    let tempF: Double
    let weatherCode: Int
    let precipitationProbability: Int
    let precipitationInches: Double
    let windSpeedMph: Double
    let windGustMph: Double

    init(date: Date, tempF: Double, weatherCode: Int, precipitationProbability: Int,
         precipitationInches: Double, windSpeedMph: Double, windGustMph: Double) {
        self.id = UUID()
        self.date = date
        self.tempF = tempF
        self.weatherCode = weatherCode
        self.precipitationProbability = precipitationProbability
        self.precipitationInches = precipitationInches
        self.windSpeedMph = windSpeedMph
        self.windGustMph = windGustMph
    }

    var symbol: String { WeatherCode.sfSymbol(for: weatherCode) }
    var symbolColor: Color { WeatherCode.color(for: weatherCode) }
}

struct Forecast: Sendable {
    let daily: [DailyForecast]
    let hourly: [HourlyForecast]
    let fetchedAt: Date

    static let empty = Forecast(daily: [], hourly: [], fetchedAt: .distantPast)
}

// MARK: - Weather Service (Open-Meteo, free, no API key)

actor WeatherService {
    static let shared = WeatherService()

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// Fetch a 14-day forecast (daily + hourly for the first 48h).
    func fetchForecast(latitude: Double, longitude: Double) async throws -> Forecast {
        let urlStr = "https://api.open-meteo.com/v1/forecast?" +
            "latitude=\(latitude)&longitude=\(longitude)" +
            "&daily=temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min," +
            "weathercode,precipitation_sum,precipitation_probability_max," +
            "windspeed_10m_max,windgusts_10m_max,relative_humidity_2m_mean,uv_index_max" +
            "&hourly=temperature_2m,weathercode,precipitation,precipitation_probability," +
            "windspeed_10m,windgusts_10m" +
            "&forecast_days=14&forecast_hours=48" +
            "&temperature_unit=fahrenheit&windspeed_unit=mph&precipitation_unit=inch" +
            "&timezone=auto"
        guard let url = URL(string: urlStr) else { throw WeatherError.invalidURL }
        let (data, _) = try await URLSession.shared.data(from: url)
        let r = try JSONDecoder().decode(OMResponse.self, from: data)
        return Forecast(
            daily: parseDaily(r.daily, timezone: r.timezone),
            hourly: parseHourly(r.hourly, timezone: r.timezone),
            fetchedAt: .now
        )
    }

    // MARK: - Helpers

    private func parseDaily(_ daily: OMDaily?, timezone: String?) -> [DailyForecast] {
        guard let daily else { return [] }
        let tz = timezone.flatMap { TimeZone(identifier: $0) } ?? .current
        var fmt = dateFormatter
        fmt.timeZone = tz
        var forecasts: [DailyForecast] = []
        for i in 0..<(daily.time?.count ?? 0) {
            guard let dateStr = daily.time?[i], let date = fmt.date(from: dateStr) else { continue }
            forecasts.append(DailyForecast(
                date: date,
                highF: daily.temperature_2m_max?[i] ?? 0,
                lowF: daily.temperature_2m_min?[i] ?? 0,
                feelsLikeHighF: daily.apparent_temperature_max?[i] ?? 0,
                feelsLikeLowF: daily.apparent_temperature_min?[i] ?? 0,
                weatherCode: daily.weathercode?[i] ?? 0,
                precipitationInches: daily.precipitation_sum?[i] ?? 0,
                precipitationProbability: daily.precipitation_probability_max?[i] ?? 0,
                windSpeedMph: daily.windspeed_10m_max?[i] ?? 0,
                windGustMph: daily.windgusts_10m_max?[i] ?? 0,
                humidity: daily.relative_humidity_2m_mean?[i] ?? 0,
                uvIndex: daily.uv_index_max?[i] ?? 0
            ))
        }
        return forecasts
    }

    private func parseHourly(_ hourly: OMHourly?, timezone: String?) -> [HourlyForecast] {
        guard let hourly else { return [] }
        let tz = timezone.flatMap { TimeZone(identifier: $0) } ?? .current
        let isoFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd'T'HH:mm"
            f.timeZone = tz
            return f
        }()
        var forecasts: [HourlyForecast] = []
        for i in 0..<(hourly.time?.count ?? 0) {
            guard let dateStr = hourly.time?[i], let date = isoFormatter.date(from: dateStr) else { continue }
            forecasts.append(HourlyForecast(
                date: date,
                tempF: hourly.temperature_2m?[i] ?? 0,
                weatherCode: hourly.weathercode?[i] ?? 0,
                precipitationProbability: hourly.precipitation_probability?[i] ?? 0,
                precipitationInches: hourly.precipitation?[i] ?? 0,
                windSpeedMph: hourly.windspeed_10m?[i] ?? 0,
                windGustMph: hourly.windgusts_10m?[i] ?? 0
            ))
        }
        return forecasts
    }
}

enum WeatherError: Error, LocalizedError {
    case invalidURL
    case missingLocation

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Couldn't build weather request URL."
        case .missingLocation: "Set your home address in Settings → Home Profile to see local weather."
        }
    }
}

// MARK: - Open-Meteo Response Models

private struct OMResponse: Decodable {
    let daily: OMDaily?
    let hourly: OMHourly?
    let timezone: String?
}

private struct OMDaily: Decodable {
    let time: [String]?
    let temperature_2m_max: [Double]?
    let temperature_2m_min: [Double]?
    let apparent_temperature_max: [Double]?
    let apparent_temperature_min: [Double]?
    let weathercode: [Int]?
    let precipitation_sum: [Double]?
    let precipitation_probability_max: [Int]?
    let windspeed_10m_max: [Double]?
    let windgusts_10m_max: [Double]?
    let relative_humidity_2m_mean: [Int]?
    let uv_index_max: [Double]?
}

private struct OMHourly: Decodable {
    let time: [String]?
    let temperature_2m: [Double]?
    let weathercode: [Int]?
    let precipitation: [Double]?
    let precipitation_probability: [Int]?
    let windspeed_10m: [Double]?
    let windgusts_10m: [Double]?
}

// MARK: - WMO Weather Codes

enum WeatherCode {
    static func sfSymbol(for code: Int) -> String {
        switch code {
        case 0: "sun.max.fill"
        case 1: "sun.min.fill"
        case 2: "cloud.sun.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51, 53, 55: "cloud.drizzle.fill"
        case 56, 57: "cloud.sleet.fill"
        case 61, 63, 65: "cloud.rain.fill"
        case 66, 67: "cloud.sleet.fill"
        case 71, 73, 75: "cloud.snow.fill"
        case 77: "snowflake"
        case 80, 81, 82: "cloud.heavyrain.fill"
        case 85, 86: "cloud.snow.fill"
        case 95: "cloud.bolt.fill"
        case 96, 99: "cloud.bolt.rain.fill"
        default: "questionmark.circle"
        }
    }

    static func description(for code: Int) -> String {
        switch code {
        case 0: "Clear sky"
        case 1: "Mainly clear"
        case 2: "Partly cloudy"
        case 3: "Overcast"
        case 45: "Fog"
        case 48: "Depositing rime fog"
        case 51: "Light drizzle"
        case 53: "Moderate drizzle"
        case 55: "Dense drizzle"
        case 56: "Light freezing drizzle"
        case 57: "Dense freezing drizzle"
        case 61: "Slight rain"
        case 63: "Moderate rain"
        case 65: "Heavy rain"
        case 66: "Light freezing rain"
        case 67: "Heavy freezing rain"
        case 71: "Slight snow"
        case 73: "Moderate snow"
        case 75: "Heavy snow"
        case 77: "Snow grains"
        case 80: "Slight showers"
        case 81: "Moderate showers"
        case 82: "Violent showers"
        case 85: "Slight snow showers"
        case 86: "Heavy snow showers"
        case 95: "Thunderstorm"
        case 96: "Thunderstorm with slight hail"
        case 99: "Thunderstorm with heavy hail"
        default: "Unknown"
        }
    }

    static func color(for code: Int) -> Color {
        switch code {
        case 0, 1: .yellow
        case 2, 3: .gray
        case 45, 48: .secondary
        case 51...57: .cyan
        case 61...67: .blue
        case 71...77, 85, 86: .white
        case 80...82: .blue
        case 95...99: .purple
        default: .secondary
        }
    }
}
