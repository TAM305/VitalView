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
        case steps = "Steps"
        case sleepHours = "Sleep Hours"
        
        var icon: String {
            switch self {
            case .heartRate: return "heart.fill"
            case .bloodPressure: return "waveform.path.ecg"
            case .oxygenSaturation: return "lungs.fill"
            case .bodyTemperature: return "thermometer"
            case .respiratoryRate: return "wind"
            case .heartRateVariability: return "heart.text.square"
            case .steps: return "figure.walk"
            case .sleepHours: return "bed.double.fill"
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
            case .steps: return .mint
            case .sleepHours: return .cyan
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
            case .steps: return "steps"
            case .sleepHours: return "hours"
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
            case .steps: return HKObjectType.quantityType(forIdentifier: .stepCount)
            case .sleepHours: return HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
            }
        }
        
        var isCorrelation: Bool {
            return self == .bloodPressure
        }
        
        var isCategory: Bool {
            return self == .sleepHours
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
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Health Trends")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Monitor your health metrics over time")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // Metric Selection
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(HealthMetric.allCases, id: \.self) { metric in
                            MetricButton(
                                metric: metric,
                                isSelected: selectedMetric == metric
                            ) {
                                selectedMetric = metric
                                loadHealthData()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Time Range Selection
                HStack(spacing: 8) {
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
                .padding(.horizontal)
                
                // Main Content
                if !isAuthorized {
                    HealthKitAuthorizationView {
                        requestHealthKitAuthorization()
                    }
                } else if isLoading {
                    ProgressView("Loading health data...")
                        .frame(height: 200)
                } else if healthData.isEmpty {
                    EmptyHealthDataView(metric: selectedMetric)
                } else {
                    // Health Chart
                    HealthChartView(data: healthData, metric: selectedMetric)
                        .frame(height: 300)
                        .padding(.horizontal)
                    
                    // Health Statistics
                    HealthStatisticsView(data: healthData, metric: selectedMetric)
                        .padding(.horizontal)
                    
                    // Health Metric Explanation
                    HealthMetricExplanationView(metric: selectedMetric)
                        .padding(.horizontal)
                }
                
                // Bottom spacing for better scrolling
                Spacer(minLength: 100)
            }
        }
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
        } else if let categoryType = healthKitType as? HKCategoryType {
            isAuthorized = healthKitManager.getAuthorizationStatus(for: categoryType) == .sharingAuthorized
        }
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
        } else if let categoryType = healthKitType as? HKCategoryType {
            typesToRequest.insert(categoryType)
        }
        
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
        
        isLoading = true
        
        Task {
            let data: [HealthDataPoint]
            
            if selectedMetric.isCorrelation {
                data = await fetchCorrelationData(for: healthKitType as! HKCorrelationType)
            } else if selectedMetric.isCategory {
                data = await fetchCategoryData(for: healthKitType as! HKCategoryType)
            } else {
                data = await fetchQuantityData(for: healthKitType as! HKQuantityType)
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
                    let value = self.convertHealthKitValue(sample.quantity, for: self.selectedMetric)
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
    
    private func fetchCategoryData(for healthKitType: HKCategoryType) async -> [HealthDataPoint] {
        return await withCheckedContinuation { continuation in
            let calendar = Calendar.current
            let now = Date()
            let startDate = calendar.date(byAdding: .day, value: -timeRange.days, to: now) ?? now
            
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
            
            let query = HKSampleQuery(sampleType: healthKitType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                guard let samples = samples as? [HKCategorySample], error == nil else {
                    continuation.resume(returning: [])
                    return
                }
                
                // For sleep, we'll calculate total hours per day
                var dailySleepHours: [Date: Double] = [:]
                
                for sample in samples {
                    let day = calendar.startOfDay(for: sample.startDate)
                    let duration = sample.endDate.timeIntervalSince(sample.startDate) / 3600 // Convert to hours
                    
                    if dailySleepHours[day] != nil {
                        dailySleepHours[day]! += duration
                    } else {
                        dailySleepHours[day] = duration
                    }
                }
                
                let dataPoints = dailySleepHours.map { day, hours in
                    HealthDataPoint(
                        date: day,
                        value: hours,
                        unit: self.selectedMetric.unit
                    )
                }.sorted { $0.date < $1.date }
                
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
            return quantity.doubleValue(for: HKUnit.percent())
        case .bodyTemperature:
            return quantity.doubleValue(for: HKUnit.degreeFahrenheit())
        case .respiratoryRate:
            return quantity.doubleValue(for: HKUnit(from: "count/min"))
        case .heartRateVariability:
            return quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
        case .steps:
            return quantity.doubleValue(for: HKUnit.count())
        case .sleepHours:
            return quantity.doubleValue(for: HKUnit.hour())
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
            VStack(spacing: 8) {
                Image(systemName: metric.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(isSelected ? .white : metric.color)
                
                Text(metric.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 80, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? metric.color : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? metric.color : Color.clear, lineWidth: 2)
            )
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
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? .blue : Color(.systemGray6))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct HealthKitAuthorizationView: View {
    let onAuthorize: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("HealthKit Access Required")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("To view your health trends, please allow access to your health data in the Health app.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Grant Access") {
                onAuthorize()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct EmptyHealthDataView: View {
    let metric: HealthTrendsView.HealthMetric
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: metric.icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No \(metric.rawValue) Data")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Add \(metric.rawValue.lowercased()) data in the Health app to see trends here.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct HealthChartView: View {
    let data: [HealthDataPoint]
    let metric: HealthTrendsView.HealthMetric
    
    var body: some View {
        Chart(data) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Value", point.value)
            )
            .foregroundStyle(metric.color)
            .lineStyle(StrokeStyle(lineWidth: 2))
            
            PointMark(
                x: .value("Date", point.date),
                y: .value("Value", point.value)
            )
            .foregroundStyle(metric.color)
            .symbolSize(8)
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month())
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel()
            }
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
        case .steps:
            return "Daily step count is a measure of physical activity and mobility. Regular walking improves cardiovascular health, strengthens muscles, and supports mental well-being. Aim for 10,000+ steps daily for optimal health."
        case .sleepHours:
            return "Sleep duration is crucial for physical recovery, mental health, and immune function. Quality sleep helps regulate hormones, repair tissues, and consolidate memories. Most adults need 7-9 hours per night."
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
        case .steps:
            return "10,000+ steps per day (recommended)"
        case .sleepHours:
            return "7-9 hours per night (adults)"
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
        case .steps:
            return "• Take walking breaks during work\n• Use stairs instead of elevators\n• Park farther from destinations\n• Walk with friends or family for motivation"
        case .sleepHours:
            return "• Maintain consistent sleep schedule\n• Create a relaxing bedtime routine\n• Keep bedroom cool, dark, and quiet\n• Avoid screens 1 hour before bed"
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
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
