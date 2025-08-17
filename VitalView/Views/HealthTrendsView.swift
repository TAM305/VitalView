import SwiftUI
import HealthKit
import Charts

struct HealthTrendsView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var selectedMetric: HealthMetric = .heartRate
    @State private var timeRange: TimeRange = .threeMonths
    @State private var healthData: [HealthDataPoint] = []
    @State private var isLoading = false
    @State private var isAuthorized = false
    
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
        
        var isCorrelation: Bool {
            return self == .bloodPressure
        }
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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header with improved spacing and typography
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
                
                // Metric Selection with enhanced visual design
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Select Metric")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            healthData = [] // Clear cached data
                            loadHealthData()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(HealthMetric.allCases, id: \.self) { metric in
                                MetricButton(
                                    metric: metric,
                                    isSelected: selectedMetric == metric
                                ) {
                                    selectedMetric = metric
                                    healthData = [] // Clear cached data when switching metrics
                                    loadHealthData()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .scrollDisabled(false) // Ensure horizontal scrolling works
                }
                
                // Time Range Selection with improved visual separation
                VStack(alignment: .leading, spacing: 16) {
                    Text("Time Period")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                    
                    HStack(spacing: 12) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            TimeRangeButton(
                                range: range,
                                isSelected: timeRange == range
                            ) {
                                timeRange = range
                                loadHealthData()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Main Content with better organization and spacing
                if !isAuthorized {
                    HealthKitAuthorizationView {
                        requestHealthKitAuthorization()
                    }
                    .padding(.horizontal, 20)
                } else if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
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
                    // Health Chart with enhanced presentation
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Trend Chart")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                        
                        HealthChartView(data: healthData, metric: selectedMetric)
                            .frame(height: 300)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .padding(.horizontal, 20)
                    }
                    
                    // Health Statistics with better visual separation
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Statistics")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                        
                        HealthStatisticsView(data: healthData, metric: selectedMetric)
                            .padding(.horizontal, 20)
                    }
                    
                    // Health Metric Explanation with enhanced presentation
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
                
                // Bottom spacing for better scrolling
                Spacer(minLength: 120)
            }
        }
        .scrollIndicators(.visible) // Show scroll indicators for better UX
        .scrollDismissesKeyboard(.immediately) // Dismiss keyboard when scrolling
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            checkHealthKitAuthorization()
        }
    }
    
    // MARK: - HealthKit Integration
    
    private func checkHealthKitAuthorization() {
        guard let healthKitType = selectedMetric.healthKitType else { return }
        
        if let quantityType = healthKitType as? HKQuantityType {
            isAuthorized = healthKitManager.getAuthorizationStatus(for: quantityType) == .sharingAuthorized
        } else if healthKitType is HKCorrelationType {
            // For blood pressure, check authorization for both systolic and diastolic
            let systolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!
            let diastolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!
            isAuthorized = healthKitManager.getAuthorizationStatus(for: systolicType) == .sharingAuthorized &&
                          healthKitManager.getAuthorizationStatus(for: diastolicType) == .sharingAuthorized

    }
    
    private func requestHealthKitAuthorization() {
        guard let healthKitType = selectedMetric.healthKitType else { return }
        
        var typesToRequest: Set<HKObjectType> = []
        
        if let quantityType = healthKitType as? HKQuantityType {
            typesToRequest.insert(quantityType)
        } else if healthKitType is HKCorrelationType {
            // For blood pressure, request authorization for both systolic and diastolic
            let systolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!
            let diastolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!
            typesToRequest.insert(systolicType)
            typesToRequest.insert(diastolicType)

        
        healthKitManager.requestAuthorization(for: typesToRequest) { success, error in
            DispatchQueue.main.async {
                if success {
                    isAuthorized = true
                    loadHealthData()
                } else {
                    print("HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
    
    private func loadHealthData() {
        guard isAuthorized, let healthKitType = selectedMetric.healthKitType else { return }
        
        print("=== Loading Health Data ===")
        print("Selected metric: \(selectedMetric.rawValue)")
        print("HealthKit type: \(healthKitType)")
        
        isLoading = true
        
        Task {
            let data: [HealthDataPoint]
            
            if selectedMetric.isCorrelation {
                data = await fetchCorrelationData(for: healthKitType as! HKCorrelationType)
            } else {
                data = await fetchQuantityData(for: healthKitType as! HKQuantityType)
            }
            
            print("Fetched \(data.count) data points")
            if !data.isEmpty {
                print("Sample data point: date=\(data.first?.date ?? Date()), value=\(data.first?.value ?? 0), unit=\(data.first?.unit ?? "unknown")")
            }
            
            await MainActor.run {
                healthData = data
                isLoading = false
            }
        }
    }
    
    private func fetchQuantityData(for healthKitType: HKQuantityType) async -> [HealthDataPoint] {
        return await withCheckedContinuation { continuation in
            let calendar = Calendar.current
            let now = Date()
            let startDate = calendar.date(byAdding: .day, value: -timeRange.days, to: now) ?? now
            
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
            
            let query = HKSampleQuery(sampleType: healthKitType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                guard let samples = samples as? [HKQuantitySample], error == nil else {
                    continuation.resume(returning: [])
                    return
                }
                
                let dataPoints = samples.map { sample in
                    // Get raw value using the appropriate unit for each metric
                    let rawValue: Double
                    switch self.selectedMetric {
                    case .oxygenSaturation:
                        rawValue = sample.quantity.doubleValue(for: HKUnit.percent())
                    case .heartRate, .respiratoryRate:
                        rawValue = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    case .bodyTemperature:
                        rawValue = sample.quantity.doubleValue(for: HKUnit.degreeFahrenheit())
                    case .heartRateVariability:
                        rawValue = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                    case .bloodPressure:
                        rawValue = sample.quantity.doubleValue(for: HKUnit.millimeterOfMercury())
                    }
                    
                    let value = self.convertHealthKitValue(sample.quantity, for: self.selectedMetric)
                    
                    if self.selectedMetric == .oxygenSaturation {
                        print("Oxygen sample: raw=\(rawValue), converted=\(value), date=\(sample.endDate)")
                    } else if self.selectedMetric == .respiratoryRate {
                        print("Respiratory rate sample: raw=\(rawValue), converted=\(value), date=\(sample.endDate)")
                    }
                    
                    return HealthDataPoint(
                        date: sample.endDate,
                        value: value,
                        unit: self.selectedMetric.unit
                    )
                }
                
                continuation.resume(returning: dataPoints)
            }
            
            healthKitManager.healthStore.execute(query)
        }
    }
    
    private func fetchCorrelationData(for healthKitType: HKCorrelationType) async -> [HealthDataPoint] {
        return await withCheckedContinuation { continuation in
            let calendar = Calendar.current
            let now = Date()
            let startDate = calendar.date(byAdding: .day, value: -timeRange.days, to: now) ?? now
            
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
            
            let query = HKSampleQuery(sampleType: healthKitType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                guard let samples = samples as? [HKCorrelation], error == nil else {
                    continuation.resume(returning: [])
                    return
                }
                
                let dataPoints = samples.compactMap { correlation -> HealthDataPoint? in
                    // For blood pressure, we'll use systolic as the primary value
                    guard let systolicSample = correlation.objects(for: HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!).first as? HKQuantitySample else {
                        return nil
                    }
                    
                    let value = systolicSample.quantity.doubleValue(for: HKUnit.millimeterOfMercury())
                    return HealthDataPoint(
                        date: correlation.endDate,
                        value: value,
                        unit: self.selectedMetric.unit
                    )
                }
                
                continuation.resume(returning: dataPoints)
            }
            
            healthKitManager.healthStore.execute(query)
        }
    }
    

    
    private func convertHealthKitValue(_ quantity: HKQuantity, for metric: HealthMetric) -> Double {
        switch metric {
        case .heartRate:
            return quantity.doubleValue(for: HKUnit(from: "count/min"))
        case .bloodPressure:
            return quantity.doubleValue(for: HKUnit.millimeterOfMercury())
        case .oxygenSaturation:
            let rawValue = quantity.doubleValue(for: HKUnit.percent())
            let convertedValue = rawValue * 100
            print("Oxygen Saturation conversion: raw=\(rawValue), converted=\(convertedValue)")
            // Convert from decimal (0.0-1.0) to percentage (0-100)
            return convertedValue
        case .bodyTemperature:
            return quantity.doubleValue(for: HKUnit.degreeFahrenheit())
        case .respiratoryRate:
            return quantity.doubleValue(for: HKUnit(from: "count/min"))
        case .heartRateVariability:
            return quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
        }
    }
}

// MARK: - Supporting Views

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
        .buttonStyle(PlainButtonStyle())
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
        .buttonStyle(PlainButtonStyle())
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
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("To view your health trends, please allow access to your health data in the Health app. This enables us to display your vital signs and create meaningful health insights.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
            }
            
            Button("Grant Access") {
                onAuthorize()
            }
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
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
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
    let data: [HealthDataPoint]
    let metric: HealthTrendsView.HealthMetric
    @State private var selectedPoint: HealthDataPoint?
    @State private var gestureDebounceTimer: Timer?
    
    var body: some View {
        VStack(spacing: 16) {
            // Chart Header with metric info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(metric.rawValue)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("\(data.count) data points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Current value display
                if let latest = data.last {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f", latest.value))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(metric.color)
                        Text(metric.unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // Enhanced Chart with optimized gesture handling
            Chart(data) { point in
                // Area fill for better visual impact
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            metric.color.opacity(0.3),
                            metric.color.opacity(0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                // Main line with enhanced styling
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(metric.color)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
                
                // Enhanced point markers
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(metric.color)
                .symbolSize(selectedPoint?.id == point.id ? 12 : 8)
                .symbol(.circle)
                .opacity(selectedPoint?.id == point.id ? 1.0 : 0.7)
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxis {
                AxisMarks(values: .stride(by: getTimeStride())) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                        .foregroundStyle(Color(.systemGray4))
                    
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(formatDate(date))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color(.systemGray4))
                    
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(formatYAxisValue(doubleValue))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 10) // Increased minimum distance to reduce conflicts
                            .onChanged { value in
                                // Debounce gesture updates to prevent main thread blocking
                                gestureDebounceTimer?.invalidate()
                                gestureDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { _ in
                                    Task { @MainActor in
                                        let location = value.location
                                        if let date = proxy.value(atX: location.x, as: Date.self),
                                           let dataPoint = findClosestDataPoint(to: date) {
                                            selectedPoint = dataPoint
                                        }
                                    }
                                }
                            }
                            .onEnded { _ in
                                // Clear timer and animate selection reset
                                gestureDebounceTimer?.invalidate()
                                withAnimation(.easeOut(duration: 0.2)) {
                                    selectedPoint = nil
                                }
                            }
                    )
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded { _ in
                                // Allow taps to clear selection
                                withAnimation(.easeOut(duration: 0.2)) {
                                    selectedPoint = nil
                                }
                            }
                    )
            }
            .frame(height: 250)
            .padding(.horizontal, 20)
            
            // Interactive Tooltip with optimized rendering
            if let selected = selectedPoint {
                VStack(spacing: 8) {
                    HStack {
                        Text(formatDate(selected.date))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("\(String(format: "%.1f", selected.value)) \(metric.unit)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(metric.color)
                    }
                    
                    // Trend indicator
                    if data.count >= 2 {
                        let trend = calculateTrendForPoint(selected)
                        HStack {
                            Image(systemName: trend.icon)
                                .foregroundColor(trend.color)
                            Text(trend.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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
        .onDisappear {
            // Clean up timer when view disappears
            gestureDebounceTimer?.invalidate()
        }
    }
    
    // MARK: - Helper Functions
    
    private func getTimeStride() -> Calendar.Component {
        let days = Calendar.current.dateComponents([.day], from: data.first?.date ?? Date(), to: data.last?.date ?? Date()).day ?? 0
        
        if days <= 7 {
            return .day
        } else if days <= 30 {
            return .weekOfYear
        } else if days <= 90 {
            return .month
        } else {
            return .month
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        if getTimeStride() == .day {
            formatter.dateFormat = "MMM d"
        } else if getTimeStride() == .weekOfYear {
            formatter.dateFormat = "MMM d"
        } else {
            formatter.dateFormat = "MMM"
        }
        
        return formatter.string(from: date)
    }
    
    private func formatYAxisValue(_ value: Double) -> String {
        if metric == .heartRate {
            return "\(Int(value))"
        } else if metric == .bloodPressure {
            return "\(Int(value))"
        } else if metric == .oxygenSaturation {
            return "\(Int(value))%"
        } else if metric == .bodyTemperature {
            return String(format: "%.1f°", value)
        } else if metric == .respiratoryRate {
            return "\(Int(value))"
        } else if metric == .heartRateVariability {
            return String(format: "%.1f", value)
        }
        return String(format: "%.1f", value)
    }
    
    private func findClosestDataPoint(to date: Date) -> HealthDataPoint? {
        return data.min { point1, point2 in
            abs(point1.date.timeIntervalSince(date)) < abs(point2.date.timeIntervalSince(date))
        }
    }
    
    private func calculateTrendForPoint(_ point: HealthDataPoint) -> (icon: String, color: Color, description: String) {
        guard let index = data.firstIndex(where: { $0.id == point.id }),
              index > 0 else {
            return ("arrow.right", .blue, "No trend data")
        }
        
        let current = point.value
        let previous = data[index - 1].value
        let change = current - previous
        let percentChange = (change / previous) * 100
        
        if abs(percentChange) < 2 {
            return ("arrow.right", .blue, "Stable")
        } else if change > 0 {
            return ("arrow.up", .green, "Up \(String(format: "%.1f", percentChange))%")
        } else {
            return ("arrow.down", .red, "Down \(String(format: "%.1f", abs(percentChange)))%")
        }
    }
}

struct HealthStatisticsView: View {
    let data: [HealthDataPoint]
    let metric: HealthTrendsView.HealthMetric
    
    private var statistics: HealthStatistics {
        let values = data.map { $0.value }
        let sortedValues = values.sorted()
        
        return HealthStatistics(
            count: values.count,
            average: values.reduce(0, +) / Double(values.count),
            min: sortedValues.first ?? 0,
            max: sortedValues.last ?? 0,
            trend: calculateTrend(values: values)
        )
    }
    
    private func calculateTrend(values: [Double]) -> String {
        guard values.count >= 2 else { return "Insufficient data" }
        
        let first = values.first ?? 0
        let last = values.last ?? 0
        let change = last - first
        let percentChange = (change / first) * 100
        
        if change > 0 {
            return "↗️ Trending up by \(String(format: "%.1f", percentChange))%"
        } else if change < 0 {
            return "↘️ Trending down by \(String(format: "%.1f", abs(percentChange)))%"
        } else {
            return "→ Stable trend"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Statistics")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(title: "Data Points", value: "\(statistics.count)")
                StatCard(title: "Average", value: String(format: "%.1f", statistics.average))
                StatCard(title: "Range", value: String(format: "%.1f - %.1f", statistics.min, statistics.max))
            }
            
            // Trend Analysis
            VStack(spacing: 8) {
                Text("Trend Analysis")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(statistics.trend)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
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

// MARK: - Health Metric Explanation View

struct HealthMetricExplanationView: View {
    let metric: HealthTrendsView.HealthMetric
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("About \(metric.rawValue)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text(metricDescription)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                if let normalRange = metricNormalRange {
                    HStack {
                        Text("Normal Range:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text(normalRange)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let healthTips = metricHealthTips {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Health Tips:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text(healthTips)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
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
    
    private var metricDescription: String {
        switch metric {
        case .heartRate:
            return "Heart rate measures how many times your heart beats per minute. It's a key indicator of cardiovascular health and fitness level. Your heart rate varies throughout the day based on activity, stress, and other factors."
        case .bloodPressure:
            return "Blood pressure measures the force of blood against your artery walls. It consists of two numbers: systolic (pressure when heart beats) and diastolic (pressure when heart rests). High blood pressure can indicate cardiovascular stress."
        case .oxygenSaturation:
            return "Oxygen saturation (SpO2) measures how much oxygen your blood is carrying. It's crucial for cellular function and energy production. Low levels can indicate breathing problems or cardiovascular issues."
        case .bodyTemperature:
            return "Body temperature indicates your body's ability to regulate heat. Normal temperature varies slightly throughout the day. Elevated temperature can signal infection, while low temperature may indicate metabolic issues."
        case .respiratoryRate:
            return "Respiratory rate measures how many breaths you take per minute. It's essential for oxygen delivery and carbon dioxide removal. Changes can indicate stress, illness, or respiratory conditions."
        case .heartRateVariability:
            return "Heart rate variability measures the variation in time between heartbeats. Higher HRV generally indicates better cardiovascular fitness and stress resilience. It's a key marker of autonomic nervous system health."
        }
    }
    
    private var metricNormalRange: String? {
        switch metric {
        case .heartRate:
            return "60-100 BPM (resting), 120-180 BPM (during exercise)"
        case .bloodPressure:
            return "Systolic: <120 mmHg, Diastolic: <80 mmHg"
        case .oxygenSaturation:
            return "95-100% (at sea level)"
        case .bodyTemperature:
            return "97.8-99.0°F (36.5-37.2°C)"
        case .respiratoryRate:
            return "12-20 breaths per minute (resting)"
        case .heartRateVariability:
            return "20-100 ms (varies by age and fitness)"
        }
    }
    
    private var metricHealthTips: String? {
        switch metric {
        case .heartRate:
            return "• Exercise regularly to improve heart health\n• Practice stress management techniques\n• Avoid excessive caffeine and alcohol\n• Get adequate sleep and rest"
        case .bloodPressure:
            return "• Reduce salt intake in your diet\n• Exercise regularly and maintain healthy weight\n• Limit alcohol consumption\n• Practice stress reduction techniques"
        case .oxygenSaturation:
            return "• Practice deep breathing exercises\n• Maintain good posture for optimal breathing\n• Exercise regularly to improve lung capacity\n• Avoid smoking and secondhand smoke"
        case .bodyTemperature:
            return "• Stay hydrated throughout the day\n• Dress appropriately for weather conditions\n• Monitor for signs of infection\n• Maintain good hygiene practices"
        case .respiratoryRate:
            return "• Practice diaphragmatic breathing\n• Exercise regularly to strengthen respiratory muscles\n• Maintain good posture\n• Avoid respiratory irritants"
        case .heartRateVariability:
            return "• Practice mindfulness and meditation\n• Get regular exercise and maintain fitness\n• Ensure adequate sleep and recovery\n• Manage stress through healthy coping mechanisms"
        }
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
