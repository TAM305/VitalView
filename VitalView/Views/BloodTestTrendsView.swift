import SwiftUI
import Charts

struct BloodTestTrendsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: BloodTestViewModel
    @State private var selectedTest = "Glucose"
    @State private var timeRange: TimeRange = .threeMonths
    @State private var showingTestSelector = false
    
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
        VStack(spacing: 0) {
            // Header with test selector and time range
            VStack(spacing: 16) {
                // Test selector
                Menu {
                    let tests = getAvailableTests()
                    if tests.isEmpty {
                        Text("No tests available")
                    } else {
                        ForEach(tests, id: \.self) { test in
                            Button(test) { selectedTest = test }
                        }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Selected Test")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(selectedTest)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Time range selector
                HStack(spacing: 8) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        BloodTimeRangeButton(
                            range: range,
                            isSelected: timeRange == range
                        ) {
                            timeRange = range
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top)
            .background(Color(.systemBackground))
            
            // Chart and analysis
            if let trendData = getTrendData() {
                ScrollView {
                    VStack(spacing: 20) {
                        // Main chart
                        BloodTestChartView(data: trendData, testName: selectedTest)
                            .frame(height: 300)
                            .padding()
                        
                        // Statistics
                        BloodTestStatisticsView(data: trendData, testName: selectedTest)
                            .padding(.horizontal)
                        
                        // Trend analysis
                        BloodTestTrendAnalysisView(data: trendData, testName: selectedTest)
                            .padding(.horizontal)
                        
                        // Health insights
                        BloodTestHealthInsightsView(data: trendData, testName: selectedTest)
                            .padding(.horizontal)
                    }
                    .padding(.bottom)
                }
            } else {
                VStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                        .padding()
                    
                    Text("No trend data available")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Add more blood tests to see trends over time")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                }
            }
        }
        .frame(maxWidth: 900)
        .padding(.horizontal)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            let tests = getAvailableTests()
            if let first = tests.first, !tests.contains(selectedTest) {
                selectedTest = first
            }
        }
    }
    
    private func getTrendData() -> [BloodTestDataPoint]? {
        let filteredTests = viewModel.bloodTests.filter { test in
            let daysSince = Calendar.current.dateComponents([.day], from: test.date, to: Date()).day ?? 0
            return daysSince <= timeRange.days
        }
        
        let dataPoints = filteredTests.compactMap { test -> BloodTestDataPoint? in
            guard let result = test.results.first(where: { $0.name == selectedTest }) else { return nil }
            return BloodTestDataPoint(
                date: test.date,
                value: result.value,
                unit: result.unit,
                status: result.status,
                referenceRange: result.referenceRange
            )
        }
        
        return dataPoints.isEmpty ? nil : dataPoints.sorted { $0.date < $1.date }
    }
    
    private func getAvailableTests() -> [String] {
        let allTests = Set(viewModel.bloodTests.flatMap { test in
            test.results.map { $0.name }
        })
        return Array(allTests).sorted()
    }
}

struct BloodTestChartView: View {
    let data: [BloodTestDataPoint]
    let testName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(testName) Over Time")
                .font(.headline)
                .padding(.horizontal)
            
            Chart(data) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(testColor)
                .lineStyle(StrokeStyle(lineWidth: 3))
                
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(point.status == .normal ? .green : 
                               point.status == .high ? .red : .orange)
                .symbolSize(100)
                
                // Reference range area
                if let range = parseReferenceRange(point.referenceRange) {
                    RectangleMark(
                        x: .value("Date", point.date),
                        yStart: .value("Lower", range.lower),
                        yEnd: .value("Upper", range.upper)
                    )
                    .foregroundStyle(.green.opacity(0.1))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month())
                }
            }
            .chartLegend(position: .bottom) {
                HStack {
                    Circle()
                        .fill(.green)
                        .frame(width: 10, height: 10)
                    Text("Normal")
                    
                    Circle()
                        .fill(.red)
                        .frame(width: 10, height: 10)
                    Text("High")
                    
                    Circle()
                        .fill(.orange)
                        .frame(width: 10, height: 10)
                    Text("Low")
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var testColor: Color {
        switch testName {
        case "Glucose": return .blue
        case "LDL": return .red
        case "HDL": return .green
        case "Creatinine": return .purple
        case "WBC": return .orange
        case "HGB": return .pink
        default: return .blue
        }
    }
    
    private func parseReferenceRange(_ range: String) -> (lower: Double, upper: Double)? {
        let components = range.split(separator: "-")
        guard components.count == 2,
              let lower = Double(components[0]),
              let upper = Double(components[1]) else { return nil }
        return (lower, upper)
    }
}

struct BloodTestStatisticsView: View {
    let data: [BloodTestDataPoint]
    let testName: String
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Statistics")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                BloodTestStatCard(title: "Average", value: averageValue, unit: data.first?.unit ?? "")
                BloodTestStatCard(title: "Highest", value: maxValue, unit: data.first?.unit ?? "")
                BloodTestStatCard(title: "Lowest", value: minValue, unit: data.first?.unit ?? "")
                BloodTestStatCard(title: "Tests", value: "\(data.count)", unit: "")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var averageValue: String {
        let avg = data.reduce(0) { $0 + $1.value } / Double(data.count)
        return String(format: "%.1f", avg)
    }
    
    private var maxValue: String {
        let max = data.map { $0.value }.max() ?? 0
        return String(format: "%.1f", max)
    }
    
    private var minValue: String {
        let min = data.map { $0.value }.min() ?? 0
        return String(format: "%.1f", min)
    }
}

struct BloodTestStatCard: View {
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

struct BloodTestTrendAnalysisView: View {
    let data: [BloodTestDataPoint]
    let testName: String
    
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
        guard data.count >= 2 else { return "arrow.right" }
        let first = data.first?.value ?? 0
        let last = data.last?.value ?? 0
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
        guard data.count >= 2 else { return .blue }
        let first = data.first?.value ?? 0
        let last = data.last?.value ?? 0
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
        guard data.count >= 2 else { return "Insufficient data for trend analysis" }
        let first = data.first?.value ?? 0
        let last = data.last?.value ?? 0
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
        switch testName {
        case "Glucose":
            return "Monitor your blood sugar regularly. Consider dietary changes and exercise to maintain healthy levels."
        case "LDL":
            return "Focus on heart-healthy diet and exercise. Consider reducing saturated fats and increasing fiber."
        case "HDL":
            return "Your HDL levels are good. Continue with regular exercise and healthy fats in your diet."
        case "Creatinine":
            return "Monitor kidney function. Stay hydrated and maintain a balanced diet low in processed foods."
        case "WBC":
            return "Your white blood cell count is normal. Continue with good hygiene and immune-boosting practices."
        case "HGB":
            return "Your hemoglobin levels are healthy. Continue with iron-rich foods and regular exercise."
        default:
            return "Continue monitoring this test regularly and consult with healthcare providers as needed."
        }
    }
}

struct BloodTestHealthInsightsView: View {
    let data: [BloodTestDataPoint]
    let testName: String
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Health Insights")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                ForEach(getInsights()) { insight in
                    HStack {
                        Image(systemName: insight.icon)
                            .foregroundColor(insight.color)
                        Text(insight.text)
                            .font(.subheadline)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private func getInsights() -> [HealthInsight] {
        var insights: [HealthInsight] = []
        
        // Frequency insight
        let frequency = data.count
        if frequency >= 3 {
            insights.append(HealthInsight(
                icon: "chart.bar.fill",
                color: .blue,
                text: "Good monitoring frequency (\(frequency) tests)"
            ))
        } else {
            insights.append(HealthInsight(
                icon: "exclamationmark.triangle.fill",
                color: .orange,
                text: "Consider more frequent testing for better tracking"
            ))
        }
        
        // Status insight
        let normalCount = data.filter { $0.status == .normal }.count
        let percentage = Double(normalCount) / Double(data.count) * 100
        
        if percentage >= 80 {
            insights.append(HealthInsight(
                icon: "checkmark.circle.fill",
                color: .green,
                text: "\(String(format: "%.0f", percentage))% of tests in normal range"
            ))
        } else {
            insights.append(HealthInsight(
                icon: "exclamationmark.circle.fill",
                color: .red,
                text: "Only \(String(format: "%.0f", percentage))% of tests in normal range"
            ))
        }
        
        // Trend insight
        if data.count >= 2 {
            let first = data.first?.value ?? 0
            let last = data.last?.value ?? 0
            let change = last - first
            
            if abs(change) > 0 {
                insights.append(HealthInsight(
                    icon: change > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                    color: change > 0 ? .red : .green,
                    text: "Value \(change > 0 ? "increased" : "decreased") by \(String(format: "%.1f", abs(change))) \(data.first?.unit ?? "")"
                ))
            }
        }
        
        return insights
    }
}

struct HealthInsight: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let text: String
}

struct BloodTestDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let unit: String
    let status: TestStatus
    let referenceRange: String
}

struct TestSelectorView: View {
    @Binding var selectedTest: String
    let availableTests: [String]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(availableTests, id: \.self) { test in
                Button(action: {
                    selectedTest = test
                    dismiss()
                }) {
                    HStack {
                        Text(test)
                        Spacer()
                        if selectedTest == test {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Select Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct BloodTimeRangeButton: View {
    let range: BloodTestTrendsView.TimeRange
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(range.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
        }
    }
}

#Preview {
    BloodTestTrendsView(viewModel: BloodTestViewModel(context: PersistenceController.shared.container.viewContext))
}
