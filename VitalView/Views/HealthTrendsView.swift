import SwiftUI
import HealthKit
import Charts

struct HealthTrendsView: View {
    // MARK: - State
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var selectedMetric: HealthMetric = .heartRate
    @State private var timeRange: TimeRange = .threeMonths
    @State private var healthData: [HealthTrendsView.HealthDataPoint] = []
    @State private var isLoading = false
    @State private var isAuthorized = false

    // MARK: - Nested Types
    enum HealthMetric: String, CaseIterable {
        case heartRate = "Heart Rate"
        case bloodPressure = "Blood Pressure"
        case oxygenSaturation = "Oxygen Saturation"
        case bodyTemperature = "Body Temperature"
        case respiratoryRate = "Respiratory Rate"
        case heartRateVariability = "Heart Rate Variability"

        var icon: String {
            switch self {
            case .heartRate: return "heart.fill"
            case .bloodPressure: return "waveform.path.ecg"
            case .oxygenSaturation: return "lungs.fill"
            case .bodyTemperature: return "thermometer"
            case .respiratoryRate: return "wind"
            case .heartRateVariability: return "heart.text.square"
            }
        }

        var color: Color {
            switch self {
            case .heartRate: return .red
            case .bloodPressure: return .blue
            case .oxygenSaturation: return .green
            case .bodyTemperature: return .orange
            case .respiratoryRate: return .purple
            case .heartRateVariability: return .indigo
            }
        }

        var unit: String {
            switch self {
            case .heartRate: return "BPM"
            case .bloodPressure: return "mmHg"
            case .oxygenSaturation: return "%"
            case .bodyTemperature: return "°F"
            case .respiratoryRate: return "breaths/min"
            case .heartRateVariability: return "ms"
            }
        }

        var healthKitType: HKObjectType? {
            switch self {
            case .heartRate: return HKObjectType.quantityType(forIdentifier: .heartRate)
            case .bloodPressure: return HKObjectType.correlationType(forIdentifier: .bloodPressure)
            case .oxygenSaturation: return HKObjectType.quantityType(forIdentifier: .oxygenSaturation)
            case .bodyTemperature: return HKObjectType.quantityType(forIdentifier: .bodyTemperature)
            case .respiratoryRate: return HKObjectType.quantityType(forIdentifier: .respiratoryRate)
            case .heartRateVariability: return HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
            }
        }

        var isCorrelation: Bool { self == .bloodPressure }
    }

    enum TimeRange: String, CaseIterable {
        case month = "1 Month"
        case threeMonths = "3 Months"
        case sixMonths = "6 Months"
        case year = "1 Year"

        var days: Int {
            switch self {
            case .month: return 30
            case .threeMonths: return 90
            case .sixMonths: return 180
            case .year: return 365
            }
        }
    }

    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Text("Health Trends")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    Text("Monitor your health metrics over time")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
                .padding(.horizontal, 20)

                // Metric picker
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Select Metric")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Spacer()
                        Button {
                            healthData = []
                            loadHealthData()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(HealthMetric.allCases, id: \.self) { metric in
                                MetricButton(metric: metric, isSelected: selectedMetric == metric) {
                                    selectedMetric = metric
                                    healthData = []
                                    loadHealthData()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                // Time range
                VStack(alignment: .leading, spacing: 16) {
                    Text("Time Period")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                    HStack(spacing: 12) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            TimeRangeButton(range: range, isSelected: timeRange == range) {
                                timeRange = range
                                loadHealthData()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Content states
                if !isAuthorized {
                    HealthKitAuthorizationView {
                        requestHealthKitAuthorization()
                    }
                    .padding(.horizontal, 20)
                } else if isLoading {
                    VStack(spacing: 20) {
                        ProgressView().scaleEffect(1.2)
                        Text("Loading health data...")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                } else if healthData.isEmpty {
                    EmptyHealthDataView(metric: selectedMetric)
                        .padding(.horizontal, 20)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Trend Chart")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                        HealthChartView(data: healthData, metric: selectedMetric, timeRange: timeRange)
                            .frame(height: 300)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .padding(.horizontal, 20)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Statistics")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                        HealthStatisticsView(data: healthData, metric: selectedMetric)
                            .padding(.horizontal, 20)
                    }
                    // Personalized insight for heart rate: "What we can say about your heart"
                    if selectedMetric == .heartRate && !healthData.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("What we can say about your heart")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 20)
                            HeartRateInsightView(data: healthData)
                                .padding(.horizontal, 20)
                        }
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        Text("About \(selectedMetric.rawValue)")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                        HealthMetricExplanationView(metric: selectedMetric)
                            .padding(.horizontal, 20)
                    }
                }
                Spacer(minLength: 120)
            }
        }
        .scrollIndicators(.visible)
        .scrollDismissesKeyboard(.immediately)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear { checkHealthKitAuthorization() }
    }

    // MARK: - HealthKit
    func checkHealthKitAuthorization() {
        guard let type = selectedMetric.healthKitType else { return }

        if let qty = type as? HKQuantityType {
            // ✅ call the object, NOT the binding
            isAuthorized = healthKitManager.authorizationStatus(for: qty) == .sharingAuthorized
        } else if type is HKCorrelationType {
            // Blood pressure needs both
            let systolic = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!
            let diastolic = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!
            let sOK = healthKitManager.authorizationStatus(for: systolic) == .sharingAuthorized
            let dOK = healthKitManager.authorizationStatus(for: diastolic) == .sharingAuthorized
            isAuthorized = sOK && dOK
        }
    }

    func requestHealthKitAuthorization() {
        guard let type = selectedMetric.healthKitType else { return }

        var readTypes = Set<HKObjectType>()
        if let qty = type as? HKQuantityType {
            readTypes.insert(qty)
        } else if type is HKCorrelationType {
            readTypes.insert(HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!)
            readTypes.insert(HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!)
        }

        healthKitManager.requestAuthorization(read: readTypes) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.isAuthorized = true
                    self.loadHealthData()
                } else {
                    print("HealthKit auth failed: \(error?.localizedDescription ?? "Unknown")")
                }
            }
        }
    }

    func loadHealthData() {
        guard isAuthorized, let healthKitType = selectedMetric.healthKitType else { return }
        isLoading = true
        Task {
            let data: [HealthTrendsView.HealthDataPoint]
            if selectedMetric.isCorrelation {
                data = await fetchCorrelationData(for: healthKitType as! HKCorrelationType)
            } else {
                data = await fetchQuantityData(for: healthKitType as! HKQuantityType)
            }
            await MainActor.run {
                healthData = data
                isLoading = false
            }
        }
    }

    func fetchQuantityData(for healthKitType: HKQuantityType) async -> [HealthTrendsView.HealthDataPoint] {
        await withCheckedContinuation { continuation in
            let calendar = Calendar.current
            let now = Date()
            let startDate = calendar.date(byAdding: .day, value: -timeRange.days, to: now) ?? now
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
            let query = HKSampleQuery(sampleType: healthKitType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                guard let samples = samples as? [HKQuantitySample], error == nil else {
                    continuation.resume(returning: [])
                    return
                }
                let points = samples.map { sample -> HealthTrendsView.HealthDataPoint in
                    let value = convertHealthKitValue(sample.quantity, for: selectedMetric)
                    return HealthTrendsView.HealthDataPoint(date: sample.endDate, value: value, unit: selectedMetric.unit)
                }
                continuation.resume(returning: points)
            }
            healthKitManager.healthStore.execute(query)
        }
    }

    func fetchCorrelationData(for healthKitType: HKCorrelationType) async -> [HealthTrendsView.HealthDataPoint] {
        await withCheckedContinuation { continuation in
            let calendar = Calendar.current
            let now = Date()
            let startDate = calendar.date(byAdding: .day, value: -timeRange.days, to: now) ?? now
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
            let query = HKSampleQuery(sampleType: healthKitType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                guard let samples = samples as? [HKCorrelation], error == nil else {
                    continuation.resume(returning: [])
                    return
                }
                let points: [HealthTrendsView.HealthDataPoint] = samples.compactMap { correlation in
                    guard let systolic = correlation.objects(for: HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!).first as? HKQuantitySample else { return nil }
                    let value = systolic.quantity.doubleValue(for: .millimeterOfMercury())
                    return HealthTrendsView.HealthDataPoint(date: correlation.endDate, value: value, unit: selectedMetric.unit)
                }
                continuation.resume(returning: points)
            }
            healthKitManager.healthStore.execute(query)
        }
    }

    func convertHealthKitValue(_ quantity: HKQuantity, for metric: HealthMetric) -> Double {
        switch metric {
        case .heartRate:
            return quantity.doubleValue(for: HKUnit(from: "count/min"))
        case .bloodPressure:
            return quantity.doubleValue(for: .millimeterOfMercury())
        case .oxygenSaturation:
            return quantity.doubleValue(for: .percent()) * 100 // 0-1 -> 0-100
        case .bodyTemperature:
            return quantity.doubleValue(for: .degreeFahrenheit())
        case .respiratoryRate:
            return quantity.doubleValue(for: HKUnit(from: "count/min"))
        case .heartRateVariability:
            return quantity.doubleValue(for: .secondUnit(with: .milli))
        }
    }

    // MARK: - Data Models
    struct HealthDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let unit: String
    }

    struct HealthStatistics {
        let count: Int
        let average: Double
        let min: Double
        let max: Double
        let trend: String
    }
}

// MARK: - Subviews (file-scope for clarity)
struct MetricButton: View {
    let metric: HealthTrendsView.HealthMetric
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: metric.icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(isSelected ? .white : metric.color)
                    .frame(height: 32)
                Text(metric.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(width: 90, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? metric.color : Color(.systemBackground))
                    .shadow(color: isSelected ? metric.color.opacity(0.3) : Color.black.opacity(0.05), radius: isSelected ? 8 : 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? metric.color : Color(.systemGray4), lineWidth: isSelected ? 0 : 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct TimeRangeButton: View {
    let range: HealthTrendsView.TimeRange
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(range.rawValue)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? .blue : Color(.systemBackground))
                        .shadow(color: isSelected ? .blue.opacity(0.3) : Color.black.opacity(0.05), radius: isSelected ? 6 : 3, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? .blue : Color(.systemGray4), lineWidth: isSelected ? 0 : 1)
                )
                .scaleEffect(isSelected ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct HealthKitAuthorizationView: View {
    let onAuthorize: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 70))
                .foregroundColor(.blue)
                .padding(.top, 20)
            VStack(spacing: 16) {
                Text("HealthKit Access Required")
                    .font(.title2).bold()
                    .multilineTextAlignment(.center)
                Text("To view your health trends, please allow access to your health data in the Health app. This enables us to display your vital signs and create meaningful health insights.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
            }
            Button("Grant Access", action: onAuthorize)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

struct EmptyHealthDataView: View {
    let metric: HealthTrendsView.HealthMetric
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: metric.icon)
                .font(.system(size: 70))
                .foregroundColor(.secondary)
                .padding(.top, 20)
            VStack(spacing: 16) {
                Text("No \(metric.rawValue) Data Available")
                    .font(.title2).bold()
                    .multilineTextAlignment(.center)
                Text("We couldn't find any \(metric.rawValue.lowercased()) data in your Health app for the selected time period. Try selecting a different time range or ensure your device is recording this health metric.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
            }
            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

struct HealthChartView: View {
    let data: [HealthTrendsView.HealthDataPoint]
    let metric: HealthTrendsView.HealthMetric
    var timeRange: HealthTrendsView.TimeRange = .threeMonths
    @State private var selectedPoint: HealthTrendsView.HealthDataPoint?
    @State private var gestureDebounceTimer: Timer?

    /// Display data: aggregated by day when > 200 points to reduce noise
    private var displayData: [HealthTrendsView.HealthDataPoint] {
        guard data.count > 200 else { return data }
        let calendar = Calendar.current
        var dayBuckets: [Date: [Double]] = [:]
        let unit = data.first?.unit ?? metric.unit
        for point in data {
            let dayStart = calendar.startOfDay(for: point.date)
            dayBuckets[dayStart, default: []].append(point.value)
        }
        return dayBuckets.sorted(by: { $0.key < $1.key }).map { dayStart, values in
            let avg = values.reduce(0, +) / Double(values.count)
            return HealthTrendsView.HealthDataPoint(date: dayStart, value: avg, unit: unit)
        }
    }

    /// Sensible Y-axis range per metric to avoid over-zooming on small variation
    private var yScaleDomain: ClosedRange<Double>? {
        switch metric {
        case .heartRate: return 40...120
        case .oxygenSaturation: return 90...100
        case .bodyTemperature: return 96...100
        case .respiratoryRate: return 8...30
        case .heartRateVariability: return 0...150
        case .bloodPressure: return 60...180
        }
    }

    /// Resolved Y domain: fixed range when set, otherwise data range with 10% padding
    private var yScaleDomainResolved: ClosedRange<Double> {
        if let fixed = yScaleDomain { return fixed }
        let values = displayData.map(\.value)
        guard let mn = values.min(), let mx = values.max(), mn != mx else {
            if let single = values.first { return (single - 10)...(single + 10) }
            return 0...100
        }
        let pad = max((mx - mn) * 0.1, 1)
        return (mn - pad)...(mx + pad)
    }

    /// Reference range for band (low/high) when we want to show "in range"
    private var referenceRange: (low: Double, high: Double)? {
        switch metric {
        case .heartRate: return (60, 100)
        case .oxygenSaturation: return (95, 100)
        case .bodyTemperature: return (97.8, 99.0)
        case .respiratoryRate: return (12, 20)
        case .heartRateVariability: return (20, 100)
        case .bloodPressure: return nil
        }
    }

    /// Linear regression trend (slope * x + intercept) for overlay when >= 3 points
    private var trendLinePoints: [HealthTrendsView.HealthDataPoint]? {
        let d = displayData.sorted { $0.date < $1.date }
        guard d.count >= 3 else { return nil }
        let firstDate = d.first!.date
        let calendar = Calendar.current
        let n = Double(d.count)
        let sumX = d.reduce(0.0) { acc, el in acc + Double(calendar.dateComponents([.day], from: firstDate, to: el.date).day ?? 0) }
        let sumY = d.reduce(0.0) { $0 + $1.value }
        let sumXY = d.reduce(0.0) { acc, el in
            let x = Double(calendar.dateComponents([.day], from: firstDate, to: el.date).day ?? 0)
            return acc + x * el.value
        }
        let sumX2 = d.reduce(0.0) { acc, el in
            let x = Double(calendar.dateComponents([.day], from: firstDate, to: el.date).day ?? 0)
            return acc + x * x
        }
        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        let intercept = (sumY - slope * sumX) / n
        let unit = data.first?.unit ?? metric.unit
        return d.map { point in
            let days = Double(calendar.dateComponents([.day], from: firstDate, to: point.date).day ?? 0)
            let value = slope * days + intercept
            return HealthTrendsView.HealthDataPoint(date: point.date, value: value, unit: unit)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(metric.rawValue).font(.headline).fontWeight(.semibold)
                    Text("\(data.count) data points · \(timeRange.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let latest = displayData.last {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f", latest.value)).font(.title2).bold().foregroundColor(metric.color)
                        Text(metric.unit).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)

            if displayData.count < 2 {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text("Add more data to see a trend")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    if let single = displayData.first {
                        Text("\(String(format: "%.1f", single.value)) \(metric.unit) on \(formatDate(single.date))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Not enough data for trend. \(displayData.count) point. Add more data to see a trend.")
            } else {
                Chart {
                    if let ref = referenceRange {
                        RuleMark(y: .value("Ref low", ref.low))
                            .foregroundStyle(Color.green.opacity(0.2))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        RuleMark(y: .value("Ref high", ref.high))
                            .foregroundStyle(Color.green.opacity(0.2))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    ForEach(displayData) { point in
                        AreaMark(x: .value("Date", point.date), y: .value("Value", point.value))
                            .foregroundStyle(LinearGradient(colors: [metric.color.opacity(0.3), metric.color.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Date", point.date), y: .value("Value", point.value))
                            .foregroundStyle(metric.color)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Date", point.date), y: .value("Value", point.value))
                            .foregroundStyle(metric.color)
                            .symbolSize(selectedPoint?.id == point.id ? 12 : 8)
                            .symbol(.circle)
                            .opacity(selectedPoint?.id == point.id ? 1.0 : 0.7)
                    }
                    if let trendPoints = trendLinePoints {
                        ForEach(trendPoints) { point in
                            LineMark(x: .value("Date", point.date), y: .value("Trend", point.value))
                        }
                        .foregroundStyle(.blue.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    }
                    if let selected = selectedPoint {
                        RuleMark(x: .value("Sel", selected.date))
                            .foregroundStyle(Color(.systemGray).opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                        RuleMark(y: .value("Sel", selected.value))
                            .foregroundStyle(Color(.systemGray).opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    }
                }
                .chartYScale(domain: yScaleDomainResolved)
                .chartXAxis {
                    AxisMarks(values: .stride(by: getTimeStride())) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                            .foregroundStyle(Color(.systemGray4))
                        if let date = value.as(Date.self) {
                            AxisValueLabel { Text(formatDate(date)).font(.caption2).foregroundColor(.secondary) }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color(.systemGray4))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(formatYAxisValue(v)).font(.caption2).foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .onChanged { value in
                                    gestureDebounceTimer?.invalidate()
                                    gestureDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { _ in
                                        Task { @MainActor in
                                            let location = value.location
                                            if let date = proxy.value(atX: location.x, as: Date.self), let pt = findClosestDataPoint(to: date) { selectedPoint = pt }
                                        }
                                    }
                                }
                        )
                        .onTapGesture { location in
                            if let date = proxy.value(atX: location.x, as: Date.self), let pt = findClosestDataPoint(to: date) {
                                withAnimation(.easeOut(duration: 0.15)) { selectedPoint = pt }
                            }
                        }
                }
                .frame(height: 250)
                .padding(.horizontal, 20)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityChartLabel)
                .accessibilityValue(selectedPoint != nil ? accessibilitySelectionValue : "")
            }

            if let selected = selectedPoint {
                VStack(spacing: 8) {
                    HStack {
                        Text(formatDate(selected.date)).font(.subheadline).fontWeight(.medium)
                        Spacer()
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) { selectedPoint = nil }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    HStack {
                        Text("\(String(format: "%.1f", selected.value)) \(metric.unit)").font(.subheadline).bold().foregroundColor(metric.color)
                        Spacer()
                    }
                    if displayData.count >= 2 {
                        let trend = calculateTrendForPoint(selected)
                        HStack { Image(systemName: trend.icon).foregroundColor(trend.color); Text(trend.description).font(.caption).foregroundColor(.secondary) }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 20)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .onDisappear { gestureDebounceTimer?.invalidate() }
    }

    private var accessibilityChartLabel: String {
        let latest = displayData.last.map { String(format: "%.0f", $0.value) } ?? "—"
        return "\(metric.rawValue) over time, \(displayData.count) points, latest \(latest) \(metric.unit). \(timeRange.rawValue)."
    }

    private var accessibilitySelectionValue: String {
        guard let s = selectedPoint else { return "" }
        let trend = displayData.count >= 2 ? calculateTrendForPoint(s).description : ""
        return "Selected \(formatDate(s.date)), \(String(format: "%.1f", s.value)) \(metric.unit). \(trend)"
    }

    private func getTimeStride() -> Calendar.Component {
        let first = displayData.first?.date ?? Date()
        let last = displayData.last?.date ?? Date()
        let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
        if days <= 7 { return .day } else if days <= 30 { return .weekOfYear } else { return .month }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        switch getTimeStride() {
        case .day, .weekOfYear: f.dateFormat = "MMM d"
        default: f.dateFormat = "MMM"
        }
        return f.string(from: date)
    }

    private func formatYAxisValue(_ value: Double) -> String {
        switch metric {
        case .heartRate, .bloodPressure, .respiratoryRate: return "\(Int(value))"
        case .oxygenSaturation: return "\(Int(value))%"
        case .bodyTemperature: return String(format: "%.1f°", value)
        case .heartRateVariability: return String(format: "%.1f", value)
        }
    }

    private func findClosestDataPoint(to date: Date) -> HealthTrendsView.HealthDataPoint? {
        displayData.min { a, b in abs(a.date.timeIntervalSince(date)) < abs(b.date.timeIntervalSince(date)) }
    }

    /// Heart rate: down = often good (green), up = watch (orange). Others: neutral (blue).
    private func calculateTrendForPoint(_ point: HealthTrendsView.HealthDataPoint) -> (icon: String, color: Color, description: String) {
        guard let idx = displayData.firstIndex(where: { $0.id == point.id }), idx > 0 else {
            return ("arrow.right", .blue, "No trend data")
        }
        let current = point.value
        let previous = displayData[idx - 1].value
        let change = current - previous
        let percent = (previous == 0) ? 0 : (change / previous) * 100
        if abs(percent) < 2 { return ("arrow.right", .blue, "Stable") }
        if metric == .heartRate {
            return change > 0
                ? ("arrow.up", .orange, "Up \(String(format: "%.1f", percent))%")
                : ("arrow.down", .green, "Down \(String(format: "%.1f", abs(percent)))%")
        }
        return change > 0
            ? ("arrow.up", .green, "Up \(String(format: "%.1f", percent))%")
            : ("arrow.down", .red, "Down \(String(format: "%.1f", abs(percent)))%")
    }
}

// MARK: - Heart rate insight (factual summary, not medical advice)
struct HeartRateInsightView: View {
    let data: [HealthTrendsView.HealthDataPoint]
    var body: some View {
        Group {
            if data.isEmpty {
                Text("No heart rate data to summarize.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                let avg = data.reduce(0.0) { $0 + $1.value } / Double(data.count)
                let minV = data.map(\.value).min() ?? 0
                let maxV = data.map(\.value).max() ?? 0
                let first = data.sorted { $0.date < $1.date }.first?.value ?? 0
                let last = data.sorted { $0.date < $1.date }.last?.value ?? 0
                let trend = first == 0 ? "stable" : (last > first ? "up" : (last < first ? "down" : "stable"))
                VStack(alignment: .leading, spacing: 12) {
                    (Text("Over this period your heart rate readings averaged ")
                        + Text(String(format: "%.0f", avg)).fontWeight(.semibold)
                        + Text(" BPM, with a range of ")
                        + Text("\(Int(minV))–\(Int(maxV))").fontWeight(.semibold)
                        + Text(" and a ")
                        + Text(trend).fontWeight(.semibold)
                        + Text(" trend."))
                        .font(.subheadline)
                    Text("These values can include both rest and activity. A commonly cited resting range is 60–100 BPM. If you're at rest and often see numbers well outside that range, or if the trend worries you, discuss with your doctor.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
}

struct HealthStatisticsView: View {
    let data: [HealthTrendsView.HealthDataPoint]
    let metric: HealthTrendsView.HealthMetric

    private var statistics: HealthTrendsView.HealthStatistics {
        let values = data.map { $0.value }
        let sorted = values.sorted()
        return HealthTrendsView.HealthStatistics(
            count: values.count,
            average: values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count),
            min: sorted.first ?? 0,
            max: sorted.last ?? 0,
            trend: calculateTrend(values: values)
        )
    }

    private func calculateTrend(values: [Double]) -> String {
        guard values.count >= 2 else { return "Insufficient data" }
        let first = values.first ?? 0, last = values.last ?? 0
        let change = last - first
        let percent = (first == 0) ? 0 : (change / first) * 100
        if change > 0 { return "↗️ Trending up by \(String(format: "%.1f", percent))%" }
        if change < 0 { return "↘️ Trending down by \(String(format: "%.1f", abs(percent)))%" }
        return "→ Stable trend"
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Statistics").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatCard(title: "Data Points", value: "\(statistics.count)")
                StatCard(title: "Average", value: String(format: "%.1f", statistics.average))
                StatCard(title: "Range", value: String(format: "%.1f - %.1f", statistics.min, statistics.max))
            }
            VStack(spacing: 8) {
                Text("Trend Analysis").font(.subheadline).fontWeight(.medium)
                Text(statistics.trend).font(.body).foregroundColor(.secondary).multilineTextAlignment(.center)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

struct HealthMetricExplanationView: View {
    let metric: HealthTrendsView.HealthMetric
    private var metricDescription: String {
        switch metric {
        case .heartRate:
            return "Heart rate measures how many times your heart beats per minute. It's a key indicator of cardiovascular health and fitness level."
        case .bloodPressure:
            return "Blood pressure measures the force of blood against your artery walls. It consists of systolic and diastolic values."
        case .oxygenSaturation:
            return "Oxygen saturation (SpO2) measures how much oxygen your blood is carrying. Low levels can indicate breathing or cardiovascular issues."
        case .bodyTemperature:
            return "Body temperature indicates your body's ability to regulate heat. Elevated temperature can signal infection."
        case .respiratoryRate:
            return "Respiratory rate measures how many breaths you take per minute. Changes can indicate stress, illness, or respiratory conditions."
        case .heartRateVariability:
            return "Heart rate variability measures the variation in time between heartbeats. Higher HRV often indicates better recovery and resilience."
        }
    }
    private var metricNormalRange: String? {
        switch metric {
        case .heartRate: return "60-100 BPM (resting)"
        case .bloodPressure: return "<120 / <80 mmHg"
        case .oxygenSaturation: return "95-100% (sea level)"
        case .bodyTemperature: return "97.8-99.0°F (36.5-37.2°C)"
        case .respiratoryRate: return "12-20 breaths/min (resting)"
        case .heartRateVariability: return "20-100 ms (varies by age/fitness)"
        }
    }
    private var metricHealthTips: String? {
        switch metric {
        case .heartRate:
            return "• Exercise regularly\n• Manage stress\n• Limit caffeine/alcohol\n• Prioritize sleep"
        case .bloodPressure:
            return "• Reduce sodium\n• Exercise and maintain weight\n• Limit alcohol\n• Manage stress"
        case .oxygenSaturation:
            return "• Deep breathing\n• Good posture\n• Regular exercise\n• Avoid smoke"
        case .bodyTemperature:
            return "• Stay hydrated\n• Dress for weather\n• Monitor illness signs\n• Keep hygiene"
        case .respiratoryRate:
            return "• Diaphragmatic breathing\n• Cardio training\n• Good posture\n• Avoid irritants"
        case .heartRateVariability:
            return "• Meditation\n• Regular exercise\n• Quality sleep\n• Stress management"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill").foregroundColor(.blue).font(.title2)
                Text("About \(metric.rawValue)").font(.headline).fontWeight(.semibold)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 12) {
                Text(metricDescription)
                if let normal = metricNormalRange {
                    HStack { Text("Normal Range:").font(.subheadline).fontWeight(.medium); Text(normal).font(.subheadline).foregroundColor(.secondary) }
                }
                if let tips = metricHealthTips {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Health Tips:").font(.subheadline).fontWeight(.medium)
                        Text(tips).font(.subheadline).foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
    }
}

#Preview {
    NavigationStack { HealthTrendsView() }
}
