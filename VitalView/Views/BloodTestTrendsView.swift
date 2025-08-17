import SwiftUI
import Charts

struct BloodTestTrendsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: BloodTestViewModel
    @State private var selectedTest = "Glucose"
    @State private var timeRange: TimeRange = .threeMonths
    @State private var showingTestSelector = false
    @State private var showingTestPanels = false
    
    // MARK: - Performance Optimization
    @State private var cachedTrendData: [String: [BloodTest]] = [:]
    @State private var isLoadingData = false
    @State private var lastFetchTime: Date?
    
    var onClose: (() -> Void)? = nil
    
    enum TimeRange: String, CaseIterable {
        case month = "1 Month"
        case threeMonths = "3 Months"
        case sixMonths = "6 Months"
        case year = "1 Year"
        case fiveYears = "5 Years"
        case tenYears = "10 Years"
        
        var days: Int {
            switch self {
            case .month: return 30
            case .threeMonths: return 90
            case .sixMonths: return 180
            case .year: return 365
            case .fiveYears: return 365 * 5
            case .tenYears: return 365 * 10
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with test selector and time range
                VStack(spacing: 16) {
                    HStack {
                        Spacer()
                        if let onClose {
                            Button("Done") { onClose() }
                                .buttonStyle(.bordered)
                        } else {
                            Button("Done") { dismiss() }
                                .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Test selector with educational content
                    VStack(spacing: 12) {
                        Menu {
                            let tests = getAvailableTests()
                            if tests.isEmpty {
                                Text("No tests available")
                            } else {
                                ForEach(tests, id: \.self) { test in
                                    Button(test) { 
                                        selectedTest = test
                                        // Clear cache when test changes
                                        cachedTrendData.removeValue(forKey: test)
                                    }
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
                        
                        // Blood Test Explanation
                        BloodTestExplanationView(testName: selectedTest)
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
                                // Clear cache when time range changes
                                cachedTrendData.removeValue(forKey: selectedTest)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Add button to show test panels
                    Button(action: { showingTestPanels = true }) {
                        HStack {
                            Image(systemName: "list.bullet")
                            Text("View Test Panels")
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
                .background(Color(.systemBackground))
                
                // Chart and analysis
                if let trendData = getTrendData() {
                    VStack(spacing: 20) {
                        // Data sufficiency indicator for longer time ranges
                        if timeRange == .fiveYears || timeRange == .tenYears {
                            HStack {
                                Image(systemName: hasEnoughDataForTimeRange() ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(hasEnoughDataForTimeRange() ? .green : .orange)
                                Text(hasEnoughDataForTimeRange() ? 
                                     "Sufficient data for \(timeRange.rawValue) trend analysis" : 
                                     "Limited data for \(timeRange.rawValue) analysis - consider shorter time ranges")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        
                        // Main chart
                        BloodTestChartView(data: trendData, testName: selectedTest, timeRange: timeRange)
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
                        
                        Spacer(minLength: 100)
                    }
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
            
            // Auto-select appropriate time range based on available data
            autoSelectTimeRange()
        }
        .sheet(isPresented: $showingTestPanels) {
            NavigationView {
                BloodTestListView(viewModel: viewModel)
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
    
    private func autoSelectTimeRange() {
        let latestDate = viewModel.bloodTests.map(\.date).max() ?? Date()
        
        let daysSinceLatest = Calendar.current.dateComponents([.day], from: latestDate, to: Date()).day ?? 0
        
        if daysSinceLatest < 30 {
            timeRange = .month
        } else if daysSinceLatest < 90 {
            timeRange = .threeMonths
        } else if daysSinceLatest < 180 {
            timeRange = .sixMonths
        } else if daysSinceLatest < 365 {
            timeRange = .year
        } else if daysSinceLatest < 365 * 5 {
            timeRange = .fiveYears
        } else {
            timeRange = .tenYears
        }
    }
    
    private func hasEnoughDataForTimeRange() -> Bool {
        let filteredTests = viewModel.bloodTests.filter { test in
            let daysSince = Calendar.current.dateComponents([.day], from: test.date, to: Date()).day ?? 0
            return daysSince <= timeRange.days
        }
        
        // For longer time ranges, we want at least 3 data points to show meaningful trends
        let minDataPoints = timeRange == .fiveYears || timeRange == .tenYears ? 3 : 2
        return filteredTests.count >= minDataPoints
    }
}

struct BloodTestChartView: View {
    let data: [BloodTestDataPoint]
    let testName: String
    let timeRange: BloodTestTrendsView.TimeRange
    
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
            .overlay {
                // Add trend line for longer time periods with sufficient data
                if (timeRange == .fiveYears || timeRange == .tenYears) && data.count >= 3 {
                    Chart(data) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Trend", calculateTrendValue(for: point.date, in: data))
                        )
                        .foregroundStyle(.blue.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: getChartStride())) { value in
                    AxisGridLine()
                    AxisValueLabel(format: getChartDateFormat())
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
                    
                    // Add trend line legend for longer time periods
                    if (timeRange == .fiveYears || timeRange == .tenYears) && data.count >= 3 {
                        Rectangle()
                            .fill(.blue.opacity(0.6))
                            .frame(width: 20, height: 2)
                            .overlay(
                                Rectangle()
                                    .stroke(.blue.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                            )
                        Text("Trend")
                            .foregroundColor(.blue)
                    }
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
    
    private func getChartStride() -> Calendar.Component {
        switch timeRange {
        case .month, .threeMonths:
            return .day
        case .sixMonths, .year:
            return .month
        case .fiveYears, .tenYears:
            return .year
        }
    }
    
    private func getChartDateFormat() -> Date.FormatStyle {
        switch timeRange {
        case .month, .threeMonths:
            return .dateTime.month().day()
        case .sixMonths, .year:
            return .dateTime.month()
        case .fiveYears, .tenYears:
            return .dateTime.year()
        }
    }
    
    private func calculateTrendValue(for date: Date, in data: [BloodTestDataPoint]) -> Double {
        guard data.count >= 3 else { return 0 }
        
        // Convert dates to days since first data point for linear regression
        let firstDate = data.first?.date ?? date
        let daysSinceFirst = Calendar.current.dateComponents([.day], from: firstDate, to: date).day ?? 0
        
        // Simple linear regression calculation
        let n = Double(data.count)
        let sumX = data.enumerated().reduce(0) { sum, element in
            let days = Calendar.current.dateComponents([.day], from: firstDate, to: element.element.date).day ?? 0
            return sum + Double(days)
        }
        let sumY = data.reduce(0) { $0 + $1.value }
        let sumXY = data.enumerated().reduce(0) { sum, element in
            let days = Calendar.current.dateComponents([.day], from: firstDate, to: element.element.date).day ?? 0
            return sum + Double(days) * element.element.value
        }
        let sumX2 = data.enumerated().reduce(0) { sum, element in
            let days = Calendar.current.dateComponents([.day], from: firstDate, to: element.element.date).day ?? 0
            return sum + Double(days * days)
        }
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        let intercept = (sumY - slope * sumX) / n
        
        return slope * Double(daysSinceFirst) + intercept
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
                
                // Additional stats for longer time periods
                if data.count >= 3 {
                    BloodTestStatCard(title: "Trend Slope", value: trendSlope, unit: "per year")
                    BloodTestStatCard(title: "Data Span", value: dataSpan, unit: "days")
                }
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
    
    private var trendSlope: String {
        guard data.count >= 3 else { return "N/A" }
        
        let sortedData = data.sorted { $0.date < $1.date }
        let firstDate = sortedData.first?.date ?? Date()
        let lastDate = sortedData.last?.date ?? Date()
        
        let daysSpan = Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 1
        let yearsSpan = Double(daysSpan) / 365.0
        
        let firstValue = sortedData.first?.value ?? 0
        let lastValue = sortedData.last?.value ?? 0
        let valueChange = lastValue - firstValue
        
        let slopePerYear = valueChange / yearsSpan
        return String(format: "%.2f", slopePerYear)
    }
    
    private var dataSpan: String {
        guard data.count >= 2 else { return "N/A" }
        
        let sortedData = data.sorted { $0.date < $1.date }
        let firstDate = sortedData.first?.date ?? Date()
        let lastDate = sortedData.last?.date ?? Date()
        
        let daysSpan = Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0
        return "\(daysSpan)"
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

// MARK: - Blood Test Explanation View

struct BloodTestExplanationView: View {
    let testName: String
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text("About \(testName)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(testDescription)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                if let normalRange = testNormalRange {
                    HStack {
                        Text("Normal Range:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text(normalRange)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let healthSignificance = testHealthSignificance {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Health Significance:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text(healthSignificance)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private var testDescription: String {
        switch testName {
        case "Glucose":
            return "Glucose is the primary sugar in your blood and the main source of energy for your body's cells. It's regulated by insulin and other hormones."
        case "Hemoglobin A1c":
            return "Hemoglobin A1c measures your average blood sugar levels over the past 2-3 months. It's a key indicator of long-term glucose control."
        case "Cholesterol (Total)":
            return "Total cholesterol measures the overall amount of cholesterol in your blood, including both 'good' (HDL) and 'bad' (LDL) cholesterol."
        case "HDL Cholesterol":
            return "HDL (High-Density Lipoprotein) is known as 'good' cholesterol. It helps remove excess cholesterol from your bloodstream."
        case "LDL Cholesterol":
            return "LDL (Low-Density Lipoprotein) is known as 'bad' cholesterol. High levels can lead to plaque buildup in arteries."
        case "Triglycerides":
            return "Triglycerides are a type of fat found in your blood. High levels can increase your risk of heart disease and stroke."
        case "Creatinine":
            return "Creatinine is a waste product filtered by your kidneys. Levels help assess kidney function and muscle mass."
        case "BUN (Blood Urea Nitrogen)":
            return "BUN measures the amount of nitrogen in your blood from urea, a waste product filtered by your kidneys."
        case "Sodium":
            return "Sodium is an electrolyte that helps regulate fluid balance, blood pressure, and nerve function in your body."
        case "Potassium":
            return "Potassium is an electrolyte crucial for heart function, muscle contractions, and maintaining fluid balance."
        case "Chloride":
            return "Chloride is an electrolyte that works with sodium and potassium to maintain fluid balance and acid-base balance."
        case "CO2 (Bicarbonate)":
            return "CO2/Bicarbonate helps maintain your body's acid-base balance and is important for respiratory function."
        case "Calcium":
            return "Calcium is essential for strong bones, muscle function, nerve transmission, and blood clotting."
        case "Phosphorus":
            return "Phosphorus works with calcium to build strong bones and teeth, and is involved in energy production."
        case "Magnesium":
            return "Magnesium is involved in over 300 biochemical reactions, including muscle and nerve function, blood sugar control, and blood pressure regulation."
        case "Iron":
            return "Iron is essential for making hemoglobin, which carries oxygen in your blood. It's crucial for energy production and immune function."
        case "Ferritin":
            return "Ferritin stores iron in your body. Low levels can indicate iron deficiency, while high levels may indicate inflammation or iron overload."
        case "Vitamin D":
            return "Vitamin D helps your body absorb calcium, supports immune function, and is important for bone health and muscle function."
        case "Vitamin B12":
            return "Vitamin B12 is essential for nerve function, red blood cell formation, and DNA synthesis. It's particularly important for energy and brain health."
        case "Folate (Vitamin B9)":
            return "Folate is crucial for cell division, DNA synthesis, and red blood cell formation. It's especially important during pregnancy."
        case "TSH (Thyroid Stimulating Hormone)":
            return "TSH regulates thyroid hormone production. It's the primary test for thyroid function and can detect both overactive and underactive thyroid."
        case "T4 (Thyroxine)":
            return "T4 is the main thyroid hormone that regulates metabolism, energy production, and many body functions."
        case "T3 (Triiodothyronine)":
            return "T3 is the active form of thyroid hormone that affects metabolism, heart rate, and body temperature."
        case "PSA (Prostate Specific Antigen)":
            return "PSA is a protein produced by the prostate gland. Elevated levels may indicate prostate conditions, though not necessarily cancer."
        case "CRP (C-Reactive Protein)":
            return "CRP is a marker of inflammation in your body. High levels may indicate infection, injury, or chronic inflammatory conditions."
        case "ESR (Erythrocyte Sedimentation Rate)":
            return "ESR measures how quickly red blood cells settle in a test tube. It's a non-specific marker of inflammation or infection."
        case "WBC (White Blood Cell Count)":
            return "White blood cells are part of your immune system. The count helps identify infection, inflammation, or immune system disorders."
        case "RBC (Red Blood Cell Count)":
            return "Red blood cells carry oxygen throughout your body. The count helps diagnose anemia and other blood disorders."
        case "Hemoglobin":
            return "Hemoglobin carries oxygen in your red blood cells. It's crucial for energy production and overall health."
        case "Hematocrit":
            return "Hematocrit measures the percentage of your blood that consists of red blood cells. It helps diagnose anemia and other conditions."
        case "Platelets":
            return "Platelets help your blood clot and stop bleeding. Abnormal levels can affect your body's ability to form blood clots."
        default:
            return "This blood test measures important markers of your health. Regular monitoring helps track changes over time and identify potential health issues early."
        }
    }
    
    private var testNormalRange: String? {
        switch testName {
        case "Glucose":
            return "70-100 mg/dL (fasting), <140 mg/dL (2 hours after eating)"
        case "Hemoglobin A1c":
            return "<5.7% (normal), 5.7-6.4% (prediabetes), ≥6.5% (diabetes)"
        case "Cholesterol (Total)":
            return "<200 mg/dL (desirable), 200-239 mg/dL (borderline), ≥240 mg/dL (high)"
        case "HDL Cholesterol":
            return "≥60 mg/dL (protective), 40-59 mg/dL (normal), <40 mg/dL (low)"
        case "LDL Cholesterol":
            return "<100 mg/dL (optimal), 100-129 mg/dL (near optimal), 130-159 mg/dL (borderline high)"
        case "Triglycerides":
            return "<150 mg/dL (normal), 150-199 mg/dL (borderline high), ≥200 mg/dL (high)"
        case "Creatinine":
            return "0.7-1.3 mg/dL (men), 0.6-1.1 mg/dL (women)"
        case "BUN (Blood Urea Nitrogen)":
            return "7-20 mg/L"
        case "Sodium":
            return "135-145 mEq/L"
        case "Potassium":
            return "3.5-5.0 mEq/L"
        case "Chloride":
            return "96-106 mEq/L"
        case "CO2 (Bicarbonate)":
            return "22-28 mEq/L"
        case "Calcium":
            return "8.5-10.5 mg/dL"
        case "Phosphorus":
            return "2.5-4.5 mg/dL"
        case "Magnesium":
            return "1.5-2.5 mg/dL"
        case "Iron":
            return "60-170 mcg/dL (men), 50-170 mcg/dL (women)"
        case "Ferritin":
            return "20-250 ng/mL (men), 10-120 ng/mL (women)"
        case "Vitamin D":
            return "30-100 ng/mL (sufficient), 20-29 ng/mL (insufficient), <20 ng/mL (deficient)"
        case "Vitamin B12":
            return "200-900 pg/mL"
        case "Folate (Vitamin B9)":
            return "2-20 ng/mL"
        case "TSH (Thyroid Stimulating Hormone)":
            return "0.4-4.0 mIU/L"
        case "T4 (Thyroxine)":
            return "0.8-1.8 ng/dL"
        case "T3 (Triiodothyronine)":
            return "80-200 ng/dL"
        case "PSA (Prostate Specific Antigen)":
            return "<4.0 ng/mL (normal), 4.0-10.0 ng/mL (borderline), >10.0 ng/mL (elevated)"
        case "CRP (C-Reactive Protein)":
            return "<3.0 mg/L (normal), 3.0-10.0 mg/L (moderate), >10.0 mg/L (high)"
        case "ESR (Erythrocyte Sedimentation Rate)":
            return "0-15 mm/hr (men), 0-20 mm/hr (women)"
        case "WBC (White Blood Cell Count)":
            return "4,500-11,000 cells/μL"
        case "RBC (Red Blood Cell Count)":
            return "4.5-5.9 million cells/μL (men), 4.1-5.1 million cells/μL (women)"
        case "Hemoglobin":
            return "13.5-17.5 g/dL (men), 12.0-15.5 g/dL (women)"
        case "Hematocrit":
            return "41-50% (men), 36-46% (women)"
        case "Platelets":
            return "150,000-450,000 cells/μL"
        default:
            return nil
        }
    }
    
    private var testHealthSignificance: String? {
        switch testName {
        case "Glucose":
            return "High levels may indicate diabetes or prediabetes. Low levels can cause dizziness, confusion, and fainting. Regular monitoring is crucial for diabetes management."
        case "Hemoglobin A1c":
            return "This test provides a long-term view of blood sugar control. Higher levels increase risk of diabetes complications affecting eyes, kidneys, and nerves."
        case "Cholesterol (Total)":
            return "High cholesterol increases risk of heart disease and stroke. Lifestyle changes and medication can help manage levels and reduce cardiovascular risk."
        case "HDL Cholesterol":
            return "Higher HDL levels are protective against heart disease. Exercise, healthy fats, and avoiding smoking can help increase HDL levels."
        case "LDL Cholesterol":
            return "High LDL levels contribute to artery plaque buildup. Diet, exercise, and medication can help lower LDL and reduce heart disease risk."
        case "Triglycerides":
            return "High levels increase heart disease risk. Reducing sugar, refined carbs, and alcohol while increasing exercise can help lower triglycerides."
        case "Creatinine":
            return "High levels may indicate kidney problems. Regular monitoring helps track kidney function and detect issues early."
        case "BUN (Blood Urea Nitrogen)":
            return "High levels may indicate kidney dysfunction, dehydration, or high protein intake. Low levels may indicate liver disease or malnutrition."
        case "Sodium":
            return "Imbalances can affect fluid balance, blood pressure, and nerve function. Dehydration and certain medications can affect sodium levels."
        case "Potassium":
            return "Critical for heart rhythm and muscle function. High or low levels can cause serious heart problems and require immediate attention."
        case "Chloride":
            return "Works with sodium to maintain fluid balance. Changes often parallel sodium changes and help assess acid-base balance."
        case "CO2 (Bicarbonate)":
            return "Helps maintain body's acid-base balance. Low levels may indicate metabolic acidosis, high levels may indicate metabolic alkalosis."
        case "Calcium":
            return "Essential for bone health, muscle function, and nerve transmission. High or low levels can affect bone density and cause muscle problems."
        case "Phosphorus":
            return "Works with calcium for bone health. Kidney disease can cause high levels, while malnutrition can cause low levels."
        case "Magnesium":
            return "Involved in hundreds of biochemical reactions. Low levels can cause muscle cramps, irregular heartbeat, and other symptoms."
        case "Iron":
            return "Essential for oxygen transport and energy production. Low levels cause anemia, high levels can damage organs."
        case "Ferritin":
            return "Indicates iron stores. Low levels suggest iron deficiency, high levels may indicate inflammation or iron overload."
        case "Vitamin D":
            return "Crucial for bone health and immune function. Deficiency is common and linked to bone problems, immune issues, and chronic diseases."
        case "Vitamin B12":
            return "Essential for nerve function and red blood cell formation. Deficiency can cause anemia, nerve damage, and cognitive problems."
        case "Folate (Vitamin B9)":
            return "Critical for cell division and DNA synthesis. Deficiency during pregnancy can cause birth defects."
        case "TSH (Thyroid Stimulating Hormone)":
            return "Primary thyroid function test. High TSH suggests underactive thyroid, low TSH suggests overactive thyroid."
        case "T4 (Thyroxine)":
            return "Main thyroid hormone. Low levels cause hypothyroidism symptoms, high levels cause hyperthyroidism symptoms."
        case "T3 (Triiodothyronine)":
            return "Active thyroid hormone. Changes can indicate thyroid problems and affect metabolism and energy levels."
        case "PSA (Prostate Specific Antigen)":
            return "Prostate health marker. Elevated levels may indicate prostate enlargement, inflammation, or cancer. Regular monitoring is important for men."
        case "CRP (C-Reactive Protein)":
            return "Inflammation marker. High levels may indicate infection, injury, or chronic inflammatory conditions like heart disease."
        case "ESR (Erythrocyte Sedimentation Rate)":
            return "Non-specific inflammation marker. High levels may indicate infection, inflammation, or certain cancers."
        case "WBC (White Blood Cell Count)":
            return "Immune system indicator. High levels suggest infection or inflammation, low levels may indicate immune system problems."
        case "RBC (Red Blood Cell Count)":
            return "Oxygen transport indicator. Low levels cause anemia, high levels may indicate dehydration or blood disorders."
        case "Hemoglobin":
            return "Oxygen-carrying protein. Low levels cause fatigue and shortness of breath, high levels may indicate dehydration or blood disorders."
        case "Hematocrit":
            return "Blood cell percentage. Low levels suggest anemia, high levels may indicate dehydration or blood disorders."
        case "Platelets":
            return "Blood clotting cells. Low levels increase bleeding risk, high levels increase clotting risk."
        default:
            return "Regular blood test monitoring helps track your health over time, identify potential issues early, and guide preventive healthcare decisions."
        }
    }
}

#Preview {
    BloodTestTrendsView(viewModel: BloodTestViewModel(context: PersistenceController.shared.container.viewContext))
}

// MARK: - Blood Test List View

struct BloodTestListView: View {
    @ObservedObject var viewModel: BloodTestViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Blood Test Panels")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.systemBackground))
            
            if viewModel.bloodTests.isEmpty {
                VStack {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                        .padding()
                    
                    Text("No blood tests available")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Import lab data or add tests manually to see your blood test panels")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.bloodTests.sorted(by: { $0.date > $1.date })) { test in
                            BloodTestPanelCard(test: test)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    }
}

struct BloodTestPanelCard: View {
    let test: BloodTest
    @State private var isExpanded = false
    @State private var showingTestInfo = false
    @State private var selectedTestName = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(test.testType)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(test.date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("\(test.results.count) test results")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    // Info button for test panel education
                    Button(action: {
                        // Extract panel type from test type for info lookup
                        let panelType = extractPanelType(from: test.testType)
                        selectedTestName = panelType
                        showingTestInfo = true
                    }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded content
            if isExpanded {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(test.results) { result in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text("\(result.value, specifier: "%.1f") \(result.unit)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(result.referenceRange)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Text(result.status.rawValue.capitalized)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(getStatusColor(result.status))
                            }
                            
                            // Info button for test education
                            Button(action: {
                                selectedTestName = result.name
                                showingTestInfo = true
                            }) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 4)
                        
                        if result.id != test.results.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showingTestInfo) {
            NavigationView {
                if isPanelType(selectedTestName) {
                    TestInfoView(testType: selectedTestName)
                } else {
                    IndividualTestInfo(testName: selectedTestName)
                }
            }
        }
    }
    
    private func getStatusColor(_ status: TestStatus) -> Color {
        switch status {
        case .normal:
            return .green
        case .high:
            return .red
        case .low:
            return .orange
        }
    }
    
    private func extractPanelType(from testType: String) -> String {
        if testType.contains("CBC") || testType.contains("Complete Blood Count") {
            return "CBC"
        } else if testType.contains("CMP") || testType.contains("Comprehensive Metabolic Panel") {
            return "CMP"
        } else if testType.contains("Cholesterol") {
            return "Cholesterol"
        } else {
            return testType
        }
    }
    
    private func isPanelType(_ testName: String) -> Bool {
        let panelTypes = ["CBC", "CMP", "Cholesterol"]
        return panelTypes.contains(testName)
    }
}
