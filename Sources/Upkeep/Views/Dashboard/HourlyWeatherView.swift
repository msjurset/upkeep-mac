import SwiftUI
import Charts

struct HourlyWeatherView: View {
    let day: DailyForecast
    let hourly: [HourlyForecast]
    let metric: WeatherMetric

    enum WeatherMetric {
        case temperature
        case precipitation
        case wind
        case humidityUV
        case dewPointPressure
    }

    @State private var selectedDate: Date?
    @State private var scrollPosition: Date
    @State private var scrollTask: Task<Void, Never>? = nil
    
    @State private var cursorSpeed: Double = 0.0
    @State private var lastCursorUpdate: Date = Date()
    @State private var lastSelectedDate: Date?
    @State private var isPaused: Bool = true
    @State private var pauseTask: Task<Void, Never>? = nil

    init(day: DailyForecast, hourly: [HourlyForecast], metric: WeatherMetric) {
        self.day = day
        self.hourly = hourly
        self.metric = metric
        
        let now = Date.now
        if Calendar.current.isDateInToday(day.date) {
            let startOfVisible = now.addingTimeInterval(-3600 * 4)
            self._scrollPosition = State(initialValue: max(day.date, startOfVisible))
        } else {
            self._scrollPosition = State(initialValue: day.date)
        }
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(day.date)
    }

    private var yDomain: ClosedRange<Double> {
        switch metric {
        case .temperature:
            let temps = hourly.map { $0.tempF }
            let feels = hourly.map { $0.feelsLikeF }
            let minTemp = min(temps.min() ?? 0, feels.min() ?? 0)
            let maxTemp = max(temps.max() ?? 100, feels.max() ?? 100)
            return (minTemp - 5)...(maxTemp + 5)
            
        case .precipitation:
            let maxAmount = hourly.map { $0.precipitationInches * 50.0 }.max() ?? 0
            let maxVal = max(100.0, maxAmount)
            return 0...maxVal
            
        case .wind:
            let speeds = hourly.map { $0.windSpeedMph }
            let gusts = hourly.map { $0.windGustMph }
            let maxSpeed = max(speeds.max() ?? 15, gusts.max() ?? 15)
            return 0...max(15, maxSpeed + 5)
            
        case .humidityUV:
            return 0...100
            
        case .dewPointPressure:
            return pressureDomain
        }
    }

    private var pressureDomain: ClosedRange<Double> {
        let pressures = hourly.map { $0.pressureHpa }
        let minP = pressures.min() ?? 1000
        let maxP = pressures.max() ?? 1020
        return (minP - 2)...(maxP + 2)
    }

    private var dewPointDomain: ClosedRange<Double> {
        let dews = hourly.map { $0.dewPointF }
        let minD = dews.min() ?? 30
        let maxD = dews.max() ?? 70
        return (minD - 5)...(maxD + 5)
    }

    private func normalizedDewPoint(_ dp: Double) -> Double {
        let dDomain = dewPointDomain
        let pDomain = pressureDomain
        let ratio = (dp - dDomain.lowerBound) / (dDomain.upperBound - dDomain.lowerBound)
        return pDomain.lowerBound + ratio * (pDomain.upperBound - pDomain.lowerBound)
    }

    private func denormalizedDewPoint(from p: Double) -> Double {
        let dDomain = dewPointDomain
        let pDomain = pressureDomain
        let ratio = (p - pDomain.lowerBound) / (pDomain.upperBound - pDomain.lowerBound)
        return dDomain.lowerBound + ratio * (dDomain.upperBound - dDomain.lowerBound)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            
            chartView
            .chartXSelection(value: $selectedDate)
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: 3600 * 8)
            .chartScrollPosition(x: $scrollPosition)
            .chartYScale(domain: yDomain)
            .onChange(of: selectedDate) { _, newValue in
                let now = Date()
                if let old = lastSelectedDate, let new = newValue {
                    let timeDelta = now.timeIntervalSince(lastCursorUpdate)
                    if timeDelta > 0 {
                        let valueDelta = abs(new.timeIntervalSince(old))
                        let rawSpeed = valueDelta / timeDelta
                        cursorSpeed = (cursorSpeed * 0.7) + (rawSpeed * 0.3)
                    }
                } else if newValue == nil {
                    cursorSpeed = 0
                }
                
                lastSelectedDate = newValue
                lastCursorUpdate = now
                isPaused = false
                
                pauseTask?.cancel()
                if newValue != nil {
                    pauseTask = Task {
                        do {
                            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                            if !Task.isCancelled {
                                await MainActor.run {
                                    isPaused = true
                                }
                            }
                        } catch {}
                    }
                }
                
                handleSelectionChange(newValue)
            }
            .onDisappear {
                scrollTask?.cancel()
                scrollTask = nil
            }
            .chartXAxis {
                // Primary time labels every 2 hours
                AxisMarks(values: .stride(by: .hour, count: 2)) { value in
                    AxisGridLine()
                    AxisTick(length: 4)
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(formatTime(date))
                        }
                    }
                }
                
                // Weather icons and temps every 1 hour (below time labels)
                AxisMarks(values: .stride(by: .hour, count: 1)) { value in
                    if let date = value.as(Date.self), 
                       let hour = hourly.first(where: { Calendar.current.isDate($0.date, equalTo: date, toGranularity: .minute) }) {
                        AxisValueLabel(anchor: .top, verticalSpacing: 34) {
                            VStack(spacing: 4) {
                                Image(systemName: hour.symbol)
                                    .font(.system(size: 12))
                                    .foregroundStyle(hour.symbolColor)
                                
                                Text("\(Int(hour.tempF))°")
                                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                                
                                if metric == .precipitation {
                                    Text("\(hour.precipitationProbability)%")
                                        .font(.system(size: 8).monospacedDigit())
                                        .foregroundStyle(.cyan)
                                } else if metric == .wind {
                                    Text("\(Int(hour.windSpeedMph))")
                                        .font(.system(size: 8).monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 40)
                        }
                    }
                }
            }
            .chartYAxis {
                if metric == .humidityUV {
                    // Left Y-axis (leading) for UV Index: 0 to 10 mapped from 0 to 100
                    AxisMarks(position: .leading, values: [0, 20, 40, 60, 80, 100]) { value in
                        if let yVal = value.as(Double.self) {
                            let uv = Int(yVal / 10)
                            AxisValueLabel {
                                Text("\(uv)")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    // Right Y-axis (trailing) for Humidity: 0% to 100%
                    AxisMarks(position: .trailing, values: [0, 20, 40, 60, 80, 100]) { value in
                        AxisGridLine()
                        if let yVal = value.as(Double.self) {
                            AxisValueLabel {
                                Text("\(Int(yVal))%")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                } else if metric == .dewPointPressure {
                    AxisMarks(position: .leading) { value in
                        if let yVal = value.as(Double.self) {
                            AxisValueLabel {
                                Text("\(Int(yVal)) hPa")
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine()
                        if let yVal = value.as(Double.self) {
                            let dew = denormalizedDewPoint(from: yVal)
                            AxisValueLabel {
                                Text("\(Int(dew))°")
                                    .foregroundStyle(.teal)
                            }
                        }
                    }
                } else {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
            }
            .chartBackground { proxy in
                GeometryReader { geo in
                    if let plotFrameAnchor = proxy.plotFrame {
                        let plotFrame = geo[plotFrameAnchor]
                        let plotWidth = plotFrame.width
                        let plotHeight = plotFrame.height
                        
                        let xStartVal = proxy.position(forX: hourly.first?.date ?? day.date)
                        let xEndVal = proxy.position(forX: hourly.last?.date ?? day.date.addingTimeInterval(3600 * 24))
                        
                        // Map coordinates relative to the plotFrame (visible area)
                        let xStart = (xStartVal ?? 0) + plotFrame.minX
                        let xEnd = (xEndVal ?? plotWidth) + plotFrame.minX
                        
                        let xSunrise = (proxy.position(forX: sunriseTime) ?? (sunriseTime < scrollPosition ? -1000 : plotWidth + 1000)) + plotFrame.minX
                        let xSunset = (proxy.position(forX: sunsetTime) ?? (sunsetTime < scrollPosition ? -1000 : plotWidth + 1000)) + plotFrame.minX
                        
                        let yMin = plotFrame.minY
                        let yMax = plotFrame.maxY
                        
                        // Night shading path (slash marks) restricted to plot area
                        Path { path in
                            // Before sunrise
                            let shadeSunriseEnd = min(plotFrame.maxX, max(plotFrame.minX, xSunrise))
                            let shadeSunriseStart = min(plotFrame.maxX, max(plotFrame.minX, xStart))
                            if shadeSunriseEnd > shadeSunriseStart {
                                drawSlashPattern(in: CGRect(x: shadeSunriseStart, y: yMin, width: shadeSunriseEnd - shadeSunriseStart, height: plotHeight), path: &path)
                            }
                            
                            // After sunset
                            let shadeSunsetStart = min(plotFrame.maxX, max(plotFrame.minX, xSunset))
                            let shadeSunsetEnd = min(plotFrame.maxX, max(plotFrame.minX, xEnd))
                            if shadeSunsetEnd > shadeSunsetStart {
                                drawSlashPattern(in: CGRect(x: shadeSunsetStart, y: yMin, width: shadeSunsetEnd - shadeSunsetStart, height: plotHeight), path: &path)
                            }
                        }
                        .stroke(Color.primary.opacity(0.04), lineWidth: 1.2)
                        
                        // Sunrise line and watermark icon
                        if xSunrise > xStart && xSunrise < xEnd {
                            Path { path in
                                path.move(to: CGPoint(x: xSunrise, y: yMin))
                                path.addLine(to: CGPoint(x: xSunrise, y: yMax))
                            }
                            .stroke(Color.orange.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            
                            Image(systemName: "sunrise")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.orange.opacity(0.35))
                                .position(x: xSunrise, y: yMin + plotHeight * 0.25)
                        }
                        
                        // Sunset line and watermark icon
                        if xSunset > xStart && xSunset < xEnd {
                            Path { path in
                                path.move(to: CGPoint(x: xSunset, y: yMin))
                                path.addLine(to: CGPoint(x: xSunset, y: yMax))
                            }
                            .stroke(Color.blue.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            
                            Image(systemName: "sunset")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.blue.opacity(0.35))
                                .position(x: xSunset, y: yMin + plotHeight * 0.25)
                        }
                    }
                }
            }
            .frame(height: 180) // Taller frame to fit everything
            .padding(.bottom, 40) // Extra padding for the stacked axis labels

            if metric == .precipitation {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(.cyan.opacity(0.4)).frame(width: 8, height: 8)
                        Text("Probability").font(.system(size: 8)).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(.blue.opacity(0.5)).frame(width: 8, height: 8)
                        Text("Amount (inches)").font(.system(size: 8)).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .frame(width: 450)
    }

    @ViewBuilder
    private var chartView: some View {
        switch metric {
        case .temperature:
            Chart {
                ForEach(hourly) { hour in
                    LineMark(
                        x: .value("Time", hour.date),
                        y: .value("Value", hour.tempF)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .foregroundStyle(by: .value("Metric", "Temperature"))

                    LineMark(
                        x: .value("Time", hour.date),
                        y: .value("Value", hour.feelsLikeF)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .foregroundStyle(by: .value("Metric", "Feels Like"))
                }
                commonMarks
            }
            .chartForegroundStyleScale([
                "Temperature": .orange,
                "Feels Like": .pink
            ])
            .chartLegend(.hidden)
        case .precipitation:
            Chart {
                ForEach(hourly) { hour in
                    BarMark(
                        x: .value("Time", hour.date),
                        y: .value("Probability", Double(hour.precipitationProbability)),
                        width: .fixed(30)
                    )
                    .foregroundStyle(.cyan.opacity(0.4))
                }
                ForEach(hourly) { hour in
                    AreaMark(
                        x: .value("Time", hour.date),
                        y: .value("Amount", hour.precipitationInches * 50.0)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.blue.opacity(0.5))
                }
                commonMarks
            }
        case .wind:
            Chart {
                ForEach(hourly) { hour in
                    LineMark(
                        x: .value("Time", hour.date),
                        y: .value("Speed", hour.windSpeedMph)
                    )
                    .foregroundStyle(.gray)
                }
                ForEach(hourly) { hour in
                    AreaMark(
                        x: .value("Time", hour.date),
                        y: .value("Gust", hour.windGustMph)
                    )
                    .foregroundStyle(.gray.opacity(0.1))
                }
                commonMarks
            }
        case .humidityUV:
            Chart {
                ForEach(hourly) { hour in
                    BarMark(
                        x: .value("Time", hour.date),
                        y: .value("UV", hour.uvIndex * 10)
                    )
                    .foregroundStyle(.orange.opacity(0.6))
                }
                ForEach(hourly) { hour in
                    LineMark(
                        x: .value("Time", hour.date),
                        y: .value("Humidity", Double(hour.humidity))
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                }
                commonMarks
            }
        case .dewPointPressure:
            Chart {
                ForEach(hourly) { hour in
                    BarMark(
                        x: .value("Time", hour.date),
                        yStart: .value("Start", pressureDomain.lowerBound),
                        yEnd: .value("End", normalizedDewPoint(hour.dewPointF))
                    )
                    .foregroundStyle(.teal.opacity(0.4))
                }
                ForEach(hourly) { hour in
                    LineMark(
                        x: .value("Time", hour.date),
                        y: .value("Pressure", hour.pressureHpa)
                    )
                    .foregroundStyle(.gray.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
                commonMarks
            }
        }
    }

    @ChartContentBuilder
    private var commonMarks: some ChartContent {
        if isToday {
            let now = Date.now
            RuleMark(x: .value("Now", now))
                .foregroundStyle(.upkeepRed)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .annotation(position: .top, spacing: 0) {
                    Text("NOW")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.upkeepRed)
                        .padding(.horizontal, 2)
                        .background(.windowBackground)
                }
            
            if let currentHour = hourly.min(by: { abs($0.date.timeIntervalSince(now)) < abs($1.date.timeIntervalSince(now)) }) {
                PointMark(
                    x: .value("Now", now),
                    y: .value("NowValue", value(for: currentHour))
                )
                .foregroundStyle(.upkeepRed)
                .symbolSize(30)
            }
        }

        if let selectedDate, let nearest = nearestHour(for: selectedDate) {
            let snapped = magneticallySnappedDate(for: selectedDate)
            
            RuleMark(x: .value("Selected", snapped))
                .foregroundStyle(.blue.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1))
            
            let pos = tooltipPosition(for: snapped)
            
            if metric == .humidityUV {
                PointMark(
                    x: .value("Time", snapped),
                    y: .value("HumidityValue", interpolatedValue(for: snapped))
                )
                .foregroundStyle(Color.blue)
                .symbolSize(60)
                .annotation(position: pos, spacing: 5) {
                    humidityTooltip(for: selectedDate, nearest: nearest)
                }
            } else {
                PointMark(
                    x: .value("Time", snapped),
                    y: .value("Value", interpolatedValue(for: snapped))
                )
                .foregroundStyle(.blue)
                .symbolSize(60)
                .annotation(position: pos, spacing: 5) {
                    defaultTooltip(for: selectedDate, nearest: nearest)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            Text(day.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var title: String {
        switch metric {
        case .temperature: "Temperature"
        case .precipitation: "Precipitation"
        case .wind: "Wind"
        case .humidityUV: "Humidity & UV"
        case .dewPointPressure: "Dew Point & Pressure"
        }
    }

    private func formatTime(_ date: Date) -> String {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        
        if minute == 0 {
            if hour == 0 { return "12 AM" }
            if hour == 12 { return "Noon" }
            return date.formatted(.dateTime.hour())
        } else {
            return date.formatted(.dateTime.hour().minute())
        }
    }

    private func nearestHour(for date: Date) -> HourlyForecast? {
        hourly.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }

    private func magneticallySnappedDate(for date: Date) -> Date {
        guard let nearest = nearestHour(for: date) else { return date }
        
        let effectiveSpeed = isPaused ? 0.0 : cursorSpeed
        
        // Thresholds for speed (data seconds per real second)
        // Sweeping 1 hour in 1 second is speed 3600.
        let fastThreshold: Double = 15000 // Fast movement (no magnet)
        let slowThreshold: Double = 4000  // Slow movement (full magnet)
        
        var magnetStrength: Double = 1.0
        if effectiveSpeed > fastThreshold {
            magnetStrength = 0.0
        } else if effectiveSpeed > slowThreshold {
            magnetStrength = 1.0 - (effectiveSpeed - slowThreshold) / (fastThreshold - slowThreshold)
        }
        
        let diff = date.timeIntervalSince(nearest.date)
        let detentRadius: TimeInterval = 1800
        
        if abs(diff) <= detentRadius {
            let normalized = diff / detentRadius
            let eased = normalized * normalized * normalized
            
            let fullSnapOffset = eased * detentRadius
            let actualOffset = diff + (fullSnapOffset - diff) * magnetStrength
            
            return nearest.date.addingTimeInterval(actualOffset)
        }
        
        return date
    }

    private func interpolatedValue(for date: Date) -> Double {
        guard let first = hourly.first, let last = hourly.last else { return 0 }
        if date <= first.date { return value(for: first) }
        if date >= last.date { return value(for: last) }
        
        guard let index = hourly.firstIndex(where: { $0.date > date }), index > 0 else { return value(for: last) }
        let h1 = hourly[index - 1]
        let h2 = hourly[index]
        
        let t1 = h1.date.timeIntervalSince1970
        let t2 = h2.date.timeIntervalSince1970
        let t = date.timeIntervalSince1970
        
        let v1 = value(for: h1)
        let v2 = value(for: h2)
        
        let ratio = (t - t1) / (t2 - t1)
        return v1 + (v2 - v1) * ratio
    }

    private func value(for hour: HourlyForecast) -> Double {
        switch metric {
        case .temperature: hour.tempF
        case .precipitation: Double(hour.precipitationProbability)
        case .wind: hour.windSpeedMph
        case .humidityUV: Double(hour.humidity)
        case .dewPointPressure: hour.pressureHpa
        }
    }

    private func tooltipPosition(for date: Date) -> AnnotationPosition {
        let val = interpolatedValue(for: date)
        let values = hourly.map { value(for: $0) }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 100
        let range = maxValue - minValue
        if range > 0 && (val - minValue) / range > 0.5 {
            return .bottomLeading
        } else {
            return .topLeading
        }
    }

    @ViewBuilder
    private func humidityTooltip(for date: Date, nearest: HourlyForecast) -> some View {
        VStack(spacing: 2) {
            Text(formatTime(date))
                .font(.system(size: 8, weight: .bold))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.blue)
                    Text("\(nearest.humidity)%")
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                }
                HStack(spacing: 4) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange)
                    Text("UV \(Int(nearest.uvIndex))")
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(radius: 2)
    }

    @ViewBuilder
    private func defaultTooltip(for date: Date, nearest: HourlyForecast) -> some View {
        VStack(spacing: 2) {
            Text(formatTime(date))
                .font(.system(size: 8, weight: .bold))
            Text(valueString(for: nearest))
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
            if metric == .temperature {
                Text("feels like \(Int(nearest.feelsLikeF))°")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
            if metric == .precipitation && nearest.precipitationInches > 0 {
                Text(String(format: "%.2f\"", nearest.precipitationInches))
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
            if metric == .dewPointPressure {
                Text("dew point \(Int(nearest.dewPointF))°")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(radius: 2)
    }

    private func valueString(for hour: HourlyForecast) -> String {
        switch metric {
        case .temperature: "\(Int(hour.tempF))°"
        case .precipitation: "\(hour.precipitationProbability)%"
        case .wind: "\(Int(hour.windSpeedMph)) mph"
        case .humidityUV: "UV \(Int(hour.uvIndex))"
        case .dewPointPressure: "\(Int(hour.pressureHpa)) hPa"
        }
    }

    private var sunriseTime: Date {
        day.sunrise ?? Calendar.current.date(bySettingHour: 6, minute: 0, second: 0, of: day.date)!
    }
    
    private var sunsetTime: Date {
        day.sunset ?? Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: day.date)!
    }

    private func handleSelectionChange(_ newValue: Date?) {
        guard let newValue else {
            scrollTask?.cancel()
            scrollTask = nil
            return
        }
        
        let visibleWindow: TimeInterval = 3600 * 8
        let scrollZone: TimeInterval = 3600 * 0.75
        
        let start = scrollPosition
        let end = start.addingTimeInterval(visibleWindow)
        
        let inLeftZone = newValue < start.addingTimeInterval(scrollZone)
        let inRightZone = newValue > end.addingTimeInterval(-scrollZone)
        
        if inLeftZone || inRightZone {
            if scrollTask == nil {
                scrollTask = Task {
                    await runScrollLoop()
                }
            }
        } else {
            if scrollTask != nil {
                scrollTask?.cancel()
                scrollTask = nil
            }
        }
    }
    
    @MainActor
    private func runScrollLoop() async {
        let visibleWindow: TimeInterval = 3600 * 8
        let scrollZone: TimeInterval = 3600 * 0.75
        let stepDuration: TimeInterval = 0.05
        let baseStep: TimeInterval = 3600 * 0.1 // 6 minutes per step (2 hours/sec)
        
        while !Task.isCancelled {
            guard let currentSelection = selectedDate else { break }
            
            let start = scrollPosition
            let end = start.addingTimeInterval(visibleWindow)
            
            let inLeftZone = currentSelection < start.addingTimeInterval(scrollZone)
            let inRightZone = currentSelection > end.addingTimeInterval(-scrollZone)
            
            if inLeftZone {
                let distance = currentSelection.timeIntervalSince(start)
                let speedMultiplier = max(0.2, min(2.5, (scrollZone - distance) / scrollZone))
                let step = -baseStep * speedMultiplier
                
                let target = max(hourly.first?.date ?? start, start.addingTimeInterval(step))
                if target == scrollPosition {
                    break
                }
                
                withAnimation(.linear(duration: stepDuration)) {
                    scrollPosition = target
                }
            } else if inRightZone {
                let distance = end.timeIntervalSince(currentSelection)
                let speedMultiplier = max(0.2, min(2.5, (scrollZone - distance) / scrollZone))
                let step = baseStep * speedMultiplier
                
                let maxScroll = (hourly.last?.date ?? end).addingTimeInterval(-visibleWindow)
                let target = min(maxScroll, start.addingTimeInterval(step))
                if target == scrollPosition {
                    break
                }
                
                withAnimation(.linear(duration: stepDuration)) {
                    scrollPosition = target
                }
            } else {
                break
            }
            
            do {
                try await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
            } catch {
                break
            }
        }
        
        scrollTask = nil
    }

    private func drawSlashPattern(in rect: CGRect, path: inout Path, spacing: CGFloat = 5) {
        let yMin = rect.minY
        let yMax = rect.maxY
        let xMin = rect.minX
        let xMax = rect.maxX
        
        var offset = xMin - (yMax - yMin)
        while offset < xMax {
            let startPoint = CGPoint(x: max(xMin, offset), y: max(yMin, yMin + (xMin - offset)))
            let endPoint = CGPoint(x: min(xMax, offset + (yMax - yMin)), y: min(yMax, yMin + (xMax - offset)))
            if startPoint.x < endPoint.x && startPoint.y < endPoint.y {
                path.move(to: startPoint)
                path.addLine(to: endPoint)
            }
            offset += spacing
        }
    }
}
