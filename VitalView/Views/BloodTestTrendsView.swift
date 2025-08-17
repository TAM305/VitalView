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
    
    private var testCategory: String {
        switch selectedTest {
        // Complete Blood Count (CBC) Tests
        case "WBC", "NEUTROPHILS", "NEUTROPHILS %", "NEUTROPHILS #", "LYMPHS %", "LYMPHS #", "MONOS", "MONOS %", "MONOS #", "EOS", "EOS %", "EOS #", "BASOS %", "HGB", "MCV", "MCH", "MCHC", "RDW", "PLATELET COUNT", "MPV":
            return "Complete Blood Count (CBC)"
        
        // Comprehensive Metabolic Panel (CMP) Tests
        case "GLUCOSE", "UREA NITROGEN", "CREATININE", "SODIUM", "POTASSIUM", "CHLORIDE", "ECO2", "ANION GAP", "CALCIUM", "TOTAL PROTEIN", "ALBUMIN", "AST", "ALKALINE PHOSPHATASE", "BILIRUBIN TOTAL":
            return "Comprehensive Metabolic Panel (CMP)"
        
        // Default case
        default:
            return "General Lab Test"
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
                    HStack(spacing: 12) {
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
                        
                        Button(action: { refreshData() }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh")
                            }
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
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
            
            // Refresh data from view model
            refreshData()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Refresh data when app comes to foreground
            refreshData()
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
        let sortedTests = Array(allTests).sorted()
        
        print("=== Blood Trends Debug ===")
        print("Total blood tests in view model: \(viewModel.bloodTests.count)")
        print("Available test names: \(sortedTests)")
        if !viewModel.bloodTests.isEmpty {
            print("Sample test: \(viewModel.bloodTests.first?.testType ?? "unknown") with \(viewModel.bloodTests.first?.results.count ?? 0) results")
        }
        
        return sortedTests
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
    
    private func refreshData() {
        // Refresh data from the view model to ensure newly imported data is visible
        viewModel.loadTests()
        print("Refreshed data from view model. Total tests: \(viewModel.bloodTests.count)")
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
    
    private var testCategory: String {
        switch testName {
        // Complete Blood Count (CBC) Tests
        case "WBC", "NEUTROPHILS", "NEUTROPHILS %", "NEUTROPHILS #", "LYMPHS %", "LYMPHS #", "MONOS", "MONOS %", "MONOS #", "EOS", "EOS %", "EOS #", "BASOS %", "HGB", "MCV", "MCH", "MCHC", "RDW", "PLATELET COUNT", "MPV":
            return "Complete Blood Count (CBC)"
        
        // Comprehensive Metabolic Panel (CMP) Tests
        case "GLUCOSE", "UREA NITROGEN", "CREATININE", "SODIUM", "POTASSIUM", "CHLORIDE", "ECO2", "ANION GAP", "CALCIUM", "TOTAL PROTEIN", "ALBUMIN", "AST", "ALKALINE PHOSPHATASE", "BILIRUBIN TOTAL":
            return "Comprehensive Metabolic Panel (CMP)"
        
        // Default case
        default:
            return "General Lab Test"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("About \(testName)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(testCategory)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 16) {
                // Test Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("What it measures:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(testDescription)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)
                }
                
                // Normal Range
                if let normalRange = testNormalRange {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Normal Range:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(normalRange)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                
                // Health Significance
                if let healthSignificance = testHealthSignificance {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Health Significance:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(healthSignificance)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(4)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                
                // Interpretation Tip
                VStack(alignment: .leading, spacing: 8) {
                    Text("💡 Interpretation Tip:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Compare your result to the normal range above. Results outside the normal range may indicate health conditions that require medical attention. Always discuss abnormal results with your healthcare provider for proper interpretation and follow-up.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var testDescription: String {
        switch testName {
        // Complete Blood Count (CBC) Tests
        case "WBC":
            return "White blood cells; infection defense"
        case "NEUTROPHILS", "NEUTROPHILS %":
            return "Bacterial defense WBC percentage"
        case "NEUTROPHILS #":
            return "Absolute neutrophil count"
        case "LYMPHS", "LYMPHS %":
            return "Lymphocytes %; viral/immune response"
        case "LYMPHS #":
            return "Absolute lymphocyte count"
        case "MONOS", "MONOS %":
            return "Monocytes %; infection cleanup"
        case "MONOS #":
            return "Absolute monocyte count"
        case "EOS", "EOS %":
            return "Eosinophils %; allergies/parasites"
        case "EOS #":
            return "Absolute eosinophil count"
        case "BASOS", "BASOS %":
            return "Basophils %; allergy/inflammation"
        case "HGB":
            return "Oxygen-carrying protein in RBCs"
        case "MCV":
            return "Average red blood cell size"
        case "MCH":
            return "Hemoglobin amount per red cell"
        case "MCHC":
            return "Hemoglobin concentration in red cells"
        case "RDW":
            return "Variation in RBC size"
        case "PLATELET COUNT":
            return "Platelets; clotting function"
        case "MPV":
            return "Average platelet size"
        
        // Comprehensive Metabolic Panel (CMP) Tests
        case "GLUCOSE":
            return "Blood sugar; diabetes screen"
        case "UREA NITROGEN":
            return "Protein waste; kidney function"
        case "CREATININE":
            return "Muscle waste; kidney function marker"
        case "SODIUM":
            return "Main electrolyte; fluid balance, nerve/muscle"
        case "POTASSIUM":
            return "Electrolyte; heart, nerve, muscle function"
        case "CHLORIDE":
            return "Electrolyte; acid-base balance"
        case "ECO2":
            return "Reflects acid-base balance"
        case "ANION GAP":
            return "Electrolyte balance; detects acid-base disorders"
        case "CALCIUM":
            return "Bone, nerve, muscle function; clotting"
        case "TOTAL PROTEIN":
            return "Albumin + globulins; reflects nutrition, liver/kidneys"
        case "ALBUMIN":
            return "Major blood protein; maintains fluid balance, transport"
        case "AST":
            return "Liver/heart enzyme; rises in liver/muscle injury"
        case "ALKALINE PHOSPHATASE":
            return "Enzyme from liver/bone; high in liver or bone disease"
        case "BILIRUBIN TOTAL":
            return "Red cell breakdown product; liver/bile duct marker"
        
        // Default case
        default:
            return "This blood test measures important health markers in your body. Results help healthcare providers assess your overall health and detect potential health issues."
        }
    }
    
    private var testNormalRange: String? {
        switch testName {
        // Complete Blood Count (CBC) Ranges
        case "WBC":
            return "4,000–11,000 /µL"
        case "NEUTROPHILS", "NEUTROPHILS %":
            return "40–70%"
        case "NEUTROPHILS #":
            return "1.5–8.0 ×10³/µL"
        case "LYMPHS", "LYMPHS %":
            return "20–40%"
        case "LYMPHS #":
            return "1.0–3.0 ×10³/µL"
        case "MONOS", "MONOS %":
            return "2–8%"
        case "MONOS #":
            return "0.2–0.8 ×10³/µL"
        case "EOS", "EOS %":
            return "1–4%"
        case "EOS #":
            return "0.0–0.5 ×10³/µL"
        case "BASOS", "BASOS %":
            return "0–1%"
        case "HGB":
            return "Men: 13.5–17.5 g/dL, Women: 12.0–15.5 g/dL"
        case "MCV":
            return "80–100 fL"
        case "MCH":
            return "27–33 pg"
        case "MCHC":
            return "32–36 g/dL"
        case "RDW":
            return "11.5–14.5%"
        case "PLATELET COUNT":
            return "150,000–450,000 /µL"
        case "MPV":
            return "7.5–11.5 fL"
        
        // Comprehensive Metabolic Panel (CMP) Ranges
        case "GLUCOSE":
            return "70–99 mg/dL (fasting)"
        case "UREA NITROGEN":
            return "7–20 mg/dL"
        case "CREATININE":
            return "0.6–1.3 mg/dL"
        case "SODIUM":
            return "135–145 mEq/L"
        case "POTASSIUM":
            return "3.5–5.0 mEq/L"
        case "CHLORIDE":
            return "98–106 mEq/L"
        case "ECO2":
            return "22–29 mEq/L"
        case "ANION GAP":
            return "8–16 mEq/L"
        case "CALCIUM":
            return "8.5–10.5 mg/dL"
        case "TOTAL PROTEIN":
            return "6.0–8.3 g/dL"
        case "ALBUMIN":
            return "3.5–5.0 g/dL"
        case "AST":
            return "10–40 IU/L"
        case "ALKALINE PHOSPHATASE":
            return "44–147 IU/L"
        case "BILIRUBIN TOTAL":
            return "0.1–1.2 mg/dL"
        
        // Default case
        default:
            return nil
        }
    }
    
    private var testHealthSignificance: String? {
        switch testName {
        // CBC Tests - Health Significance
        case "WBC":
            return "High WBC may indicate infection, inflammation, or blood disorders. Low WBC may suggest immune suppression, bone marrow problems, or certain medications."
        case "NEUTROPHILS", "NEUTROPHILS %":
            return "High neutrophils often indicate bacterial infections or inflammation. Low neutrophils (neutropenia) increase infection risk and may indicate bone marrow problems."
        case "HGB":
            return "Low hemoglobin indicates anemia, which can cause fatigue, weakness, and shortness of breath. High levels may suggest dehydration or blood disorders."
        case "PLATELET COUNT":
            return "Low platelets increase bleeding risk. High platelets may indicate inflammation, blood disorders, or increased clotting risk."
        
        // CMP Tests - Health Significance
        case "GLUCOSE":
            return "High glucose may indicate diabetes or prediabetes. Low glucose can cause dizziness, confusion, and in severe cases, unconsciousness."
        case "CREATININE":
            return "High creatinine suggests kidney function problems. Low levels may indicate reduced muscle mass or certain medications."
        case "SODIUM":
            return "High sodium may indicate dehydration. Low sodium can cause confusion, seizures, and in severe cases, coma."
        case "POTASSIUM":
            return "High potassium can cause dangerous heart rhythm problems. Low potassium may cause muscle weakness and heart rhythm issues."
        case "AST":
            return "High AST may indicate liver damage, heart problems, or muscle injury. Levels help monitor liver disease progression."
        case "ALBUMIN":
            return "Low albumin may indicate malnutrition, liver disease, or kidney problems. It's crucial for maintaining fluid balance and transporting nutrients."
        
        // Default case
        default:
            return "Abnormal results may indicate underlying health conditions. Always discuss results with your healthcare provider for proper interpretation and follow-up."
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

