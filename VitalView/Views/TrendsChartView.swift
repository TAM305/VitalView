import SwiftUI
import Charts

struct TrendsChartView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMetric = "Heart Rate"
    @State private var timeRange: TimeRange = .week
    @State private var chartData: [HealthDataPoint] = []
    @State private var isLoading = false
    
    let healthStore = HKHealthStore()
    
    enum TimeRange: String, CaseIterable {
        case day = "24 Hours"
        case week = "7 Days"
        case month = "30 Days"
        case threeMonths = "3 Months"
        
        var days: Int {
            switch self {
            case .day: return 1
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with metric selector and time range
                VStack(spacing: 16) {
                    // Metric selector
                    Picker("Metric", selection: $selectedMetric) {
                        Text("Heart Rate").tag("Heart Rate")
                        Text("Blood Pressure").tag("Blood Pressure")
                        Text("Oxygen Saturation").tag("Oxygen Saturation")
                        Text("Temperature").tag("Temperature")
                        Text("Respiratory Rate").tag("Respiratory Rate")
                        Text("Heart Rate Variability").tag("Heart Rate Variability")
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Time range selector
                    Picker("Time Range", selection: $timeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }
                .padding(.top)
                .background(Color(.systemBackground))
                
                // Chart area
                if isLoading {
                    VStack {
                        ProgressView("Loading data...")
                            .padding()
                        Spacer()
                    }
                } else if chartData.isEmpty {
                    VStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                            .padding()
                        
                        Text("No data available")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Try selecting a different time range or metric")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Main chart
                            ChartView(data: chartData, metric: selectedMetric)
                                .frame(height: 300)
                                .padding()
                            
                            // Statistics
                            StatisticsView(data: chartData, metric: selectedMetric)
                                .padding(.horizontal)
                            
                            // Trend analysis
                            TrendAnalysisView(data: chartData, metric: selectedMetric)
                                .padding(.horizontal)
                        }
                        .padding(.bottom)
                    }
                }
            }
            .navigationTitle("Health Trends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadChartData()
        }
        .onChange(of: selectedMetric) { _ in
            loadChartData()
        }
        .onChange(of: timeRange) { _ in
            loadChartData()
        }
    }
    
    private func loadChartData() {
        isLoading = true
        chartData = []
        
        // Simulate data loading for demo
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            chartData = generateSampleData()
            isLoading = false
        }
    }
    
    private func generateSampleData() -> [HealthDataPoint] {
        let calendar = Calendar.current
        let now = Date()
        var data: [HealthDataPoint] = []
        
        for i in 0..<timeRange.days {
            let date = calendar.date(byAdding: .day, value: -i, to: now) ?? now
            
            switch selectedMetric {
            case "Heart Rate":
                let value = Double.random(in: 60...100)
                data.append(HealthDataPoint(date: date, value: value, unit: "BPM"))
            case "Blood Pressure":
                let systolic = Double.random(in: 110...140)
                let diastolic = Double.random(in: 70...90)
                data.append(HealthDataPoint(date: date, systolic: systolic, diastolic: diastolic, unit: "mmHg"))
            case "Oxygen Saturation":
                let value = Double.random(in: 95...100)
                data.append(HealthDataPoint(date: date, value: value, unit: "%"))
            case "Temperature":
                let value = Double.random(in: 97.0...99.5)
                data.append(HealthDataPoint(date: date, value: value, unit: "°F"))
            case "Respiratory Rate":
                let value = Double.random(in: 12...20)
                data.append(HealthDataPoint(date: date, value: value, unit: "breaths/min"))
            case "Heart Rate Variability":
                let value = Double.random(in: 15...50)
                data.append(HealthDataPoint(date: date, value: value, unit: "ms"))
            default:
                break
            }
        }
        
        return data.reversed()
    }
}

struct ChartView: View {
    let data: [HealthDataPoint]
    let metric: String
    
    var body: some View {
        Chart(data) { point in
            if metric == "Blood Pressure" {
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Systolic", point.systolic ?? 0)
                )
                .foregroundStyle(.red)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Diastolic", point.diastolic ?? 0)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
            } else {
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value ?? 0)
                )
                .foregroundStyle(metricColor)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value ?? 0)
                )
                .foregroundStyle(metricColor.opacity(0.1))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month())
            }
        }
    }
    
    private var metricColor: Color {
        switch metric {
        case "Heart Rate": return .red
        case "Oxygen Saturation": return .green
        case "Temperature": return .orange
        case "Respiratory Rate": return .purple
        case "Heart Rate Variability": return .blue
        default: return .blue
        }
    }
}

struct StatisticsView: View {
    let data: [HealthDataPoint]
    let metric: String
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Statistics")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(title: "Average", value: averageValue, unit: data.first?.unit ?? "")
                StatCard(title: "Highest", value: maxValue, unit: data.first?.unit ?? "")
                StatCard(title: "Lowest", value: minValue, unit: data.first?.unit ?? "")
                StatCard(title: "Trend", value: trendDirection, unit: "")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var averageValue: String {
        let values = data.compactMap { $0.value }
        let avg = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        return String(format: "%.1f", avg)
    }
    
    private var maxValue: String {
        let values = data.compactMap { $0.value }
        let max = values.max() ?? 0
        return String(format: "%.1f", max)
    }
    
    private var minValue: String {
        let values = data.compactMap { $0.value }
        let min = values.min() ?? 0
        return String(format: "%.1f", min)
    }
    
    private var trendDirection: String {
        guard data.count >= 2 else { return "Stable" }
        let first = data.first?.value ?? 0
        let last = data.last?.value ?? 0
        let change = last - first
        
        if change > 0 {
            return "↗️ Increasing"
        } else if change < 0 {
            return "↘️ Decreasing"
        } else {
            return "→ Stable"
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            if !unit.isEmpty {
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct TrendAnalysisView: View {
    let data: [HealthDataPoint]
    let metric: String
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Trend Analysis")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: trendIcon)
                        .foregroundColor(trendColor)
                    Text(trendDescription)
                        .font(.subheadline)
                    Spacer()
                }
                
                Text(healthRecommendation)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var trendIcon: String {
        let values = data.compactMap { $0.value }
        guard values.count >= 2 else { return "arrow.right" }
        let first = values.first ?? 0
        let last = values.last ?? 0
        let change = last - first
        
        if change > 0 {
            return "arrow.up"
        } else if change < 0 {
            return "arrow.down"
        } else {
            return "arrow.right"
        }
    }
    
    private var trendColor: Color {
        let values = data.compactMap { $0.value }
        guard values.count >= 2 else { return .blue }
        let first = values.first ?? 0
        let last = values.last ?? 0
        let change = last - first
        
        if change > 0 {
            return .red
        } else if change < 0 {
            return .green
        } else {
            return .blue
        }
    }
    
    private var trendDescription: String {
        let values = data.compactMap { $0.value }
        guard values.count >= 2 else { return "Insufficient data for trend analysis" }
        let first = values.first ?? 0
        let last = values.last ?? 0
        let change = last - first
        let percentChange = (change / first) * 100
        
        if change > 0 {
            return "Trending upward by \(String(format: "%.1f", percentChange))%"
        } else if change < 0 {
            return "Trending downward by \(String(format: "%.1f", abs(percentChange)))%"
        } else {
            return "Stable trend over time"
        }
    }
    
    private var healthRecommendation: String {
        switch metric {
        case "Heart Rate":
            return "Your heart rate is within normal range. Consider regular exercise to maintain cardiovascular health."
        case "Blood Pressure":
            return "Monitor your blood pressure regularly. Consider reducing salt intake and increasing physical activity."
        case "Oxygen Saturation":
            return "Your oxygen levels are healthy. Continue with regular breathing exercises and outdoor activities."
        case "Temperature":
            return "Your body temperature is normal. Stay hydrated and maintain good sleep hygiene."
        case "Respiratory Rate":
            return "Your breathing rate is within normal limits. Practice deep breathing exercises for stress relief."
        case "Heart Rate Variability":
            return "Your HRV indicates good cardiovascular fitness. Continue with regular exercise and stress management."
        default:
            return "Continue monitoring this metric regularly and consult with healthcare providers as needed."
        }
    }
}

struct HealthDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double?
    let systolic: Double?
    let diastolic: Double?
    let unit: String
    
    init(date: Date, value: Double? = nil, systolic: Double? = nil, diastolic: Double? = nil, unit: String) {
        self.date = date
        self.value = value
        self.systolic = systolic
        self.diastolic = diastolic
        self.unit = unit
    }
}

#Preview {
    TrendsChartView()
}
