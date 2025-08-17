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
        switch testName {
        // Complete Blood Count (CBC) Tests
        case "WBC", "WHITE BLOOD CELLS", "WHITE BLOOD CELL COUNT", "NEUTROPHILS", "NEUTROPHILS %", "NEUTROPHILS #", "LYMPHS", "LYMPHS %", "LYMPHS #", "LYMPHOCYTES", "LYMPHOCYTES %", "LYMPHOCYTES #", "MONOS", "MONOS %", "MONOS #", "MONOCYTES", "MONOCYTES %", "MONOCYTES #", "EOS", "EOS %", "EOS #", "EOSINOPHILS", "EOSINOPHILS %", "EOSINOPHILS #", "BASOS", "BASOS %", "BASOPHILS", "BASOPHILS %", "HGB", "HEMOGLOBIN", "MCV", "MCH", "MCHC", "RDW", "PLATELET COUNT", "PLATELETS", "MPV":
            return "Complete Blood Count (CBC)"
        
        // Comprehensive Metabolic Panel (CMP) Tests
        case "GLUCOSE", "BLOOD SUGAR", "UREA NITROGEN", "BUN", "CREATININE", "SODIUM", "NA", "POTASSIUM", "K", "CHLORIDE", "CL", "ECO2", "CO2", "BICARBONATE", "ANION GAP", "CALCIUM", "CA", "TOTAL PROTEIN", "ALBUMIN", "AST", "SGOT", "ALKALINE PHOSPHATASE", "ALP", "BILIRUBIN TOTAL", "BILIRUBIN", "ALT", "SGPT":
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
        case "WBC", "WHITE BLOOD CELLS", "WHITE BLOOD CELL COUNT":
            return "Complete Blood Count (CBC)"
        case "NEUTROPHILS", "NEUTROPHILS %":
            return "Complete Blood Count (CBC)"
        case "NEUTROPHILS #":
            return "Complete Blood Count (CBC)"
        case "LYMPHS", "LYMPHS %", "LYMPHOCYTES", "LYMPHOCYTES %":
            return "Complete Blood Count (CBC)"
        case "LYMPHS #", "LYMPHOCYTES #":
            return "Complete Blood Count (CBC)"
        case "MONOS", "MONOS %", "MONOCYTES", "MONOCYTES %":
            return "Complete Blood Count (CBC)"
        case "MONOS #", "MONOCYTES #":
            return "Complete Blood Count (CBC)"
        case "EOS", "EOS %", "EOSINOPHILS", "EOSINOPHILS %":
            return "Complete Blood Count (CBC)"
        case "EOS #", "EOSINOPHILS #":
            return "Complete Blood Count (CBC)"
        case "BASOS", "BASOS %", "BASOPHILS", "BASOPHILS %":
            return "Complete Blood Count (CBC)"
        case "HGB", "HEMOGLOBIN":
            return "Complete Blood Count (CBC)"
        case "MCV":
            return "Complete Blood Count (CBC)"
        case "MCH":
            return "Complete Blood Count (CBC)"
        case "MCHC":
            return "Complete Blood Count (CBC)"
        case "RDW":
            return "Complete Blood Count (CBC)"
        case "PLATELET COUNT", "PLATELETS":
            return "Complete Blood Count (CBC)"
        case "MPV":
            return "Complete Blood Count (CBC)"
        
        // Comprehensive Metabolic Panel (CMP) Tests
        case "GLUCOSE", "BLOOD SUGAR":
            return "Comprehensive Metabolic Panel (CMP)"
        case "UREA NITROGEN", "BUN":
            return "Comprehensive Metabolic Panel (CMP)"
        case "CREATININE":
            return "Comprehensive Metabolic Panel (CMP)"
        case "SODIUM", "NA":
            return "Comprehensive Metabolic Panel (CMP)"
        case "POTASSIUM", "K":
            return "Comprehensive Metabolic Panel (CMP)"
        case "CHLORIDE", "CL":
            return "Comprehensive Metabolic Panel (CMP)"
        case "ECO2", "CO2", "BICARBONATE":
            return "Comprehensive Metabolic Panel (CMP)"
        case "ANION GAP":
            return "Comprehensive Metabolic Panel (CMP)"
        case "CALCIUM", "CA":
            return "Comprehensive Metabolic Panel (CMP)"
        case "TOTAL PROTEIN":
            return "Comprehensive Metabolic Panel (CMP)"
        case "ALBUMIN":
            return "Comprehensive Metabolic Panel (CMP)"
        case "AST", "SGOT":
            return "Comprehensive Metabolic Panel (CMP)"
        case "ALT", "SGPT":
            return "Comprehensive Metabolic Panel (CMP)"
        case "ALKALINE PHOSPHATASE", "ALP":
            return "Comprehensive Metabolic Panel (CMP)"
        case "BILIRUBIN TOTAL", "BILIRUBIN":
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
        case "WBC", "WHITE BLOOD CELLS", "WHITE BLOOD CELL COUNT":
            return "White blood cell count that measures infection-fighting cells in your bloodstream."
        case "NEUTROPHILS", "NEUTROPHILS %":
            return "Main white blood cells responsible for fighting bacterial infections. These are your body's first line of defense against bacterial invaders."
        case "NEUTROPHILS #":
            return "Absolute number of neutrophils in your blood, providing a precise count of these infection-fighting cells."
        case "LYMPHS", "LYMPHS %", "LYMPHOCYTES", "LYMPHOCYTES %":
            return "Lymphocytes percentage; these cells are crucial for viral infections and immune system responses."
        case "LYMPHS #", "LYMPHOCYTES #":
            return "Absolute lymphocyte count; the exact number of these important immune cells in your blood."
        case "MONOS", "MONOS %", "MONOCYTES", "MONOCYTES %":
            return "Monocytes percentage; these cells help fight infection and clear cellular debris from your body."
        case "MONOS #", "MONOCYTES #":
            return "Absolute monocyte count; the precise number of these infection-fighting and cleanup cells."
        case "EOS", "EOS %", "EOSINOPHILS", "EOSINOPHILS %":
            return "Eosinophils percentage; these cells often increase with allergies or parasitic infections."
        case "EOS #", "EOSINOPHILS #":
            return "Absolute eosinophil count; the exact number of these allergy and parasite-fighting cells."
        case "BASOS", "BASOS %", "BASOPHILS", "BASOPHILS %":
            return "Basophils percentage; the least common white blood cell type, involved in allergies and inflammation responses."
        case "HGB", "HEMOGLOBIN":
            return "Hemoglobin; the protein in red blood cells that carries oxygen throughout your body."
        case "MCV":
            return "Mean corpuscular volume; the average size of your red blood cells, helping classify the type of anemia if present."
        case "MCH":
            return "Mean corpuscular hemoglobin; the average amount of hemoglobin per red blood cell."
        case "MCHC":
            return "Mean corpuscular hemoglobin concentration; the average concentration of hemoglobin inside your red blood cells."
        case "RDW":
            return "Red cell distribution width; a measure of variation in red blood cell size, indicating how uniform your red cells are."
        case "PLATELET COUNT", "PLATELETS":
            return "Number of platelets in your blood; these are essential for blood clotting and wound healing."
        case "MPV":
            return "Mean platelet volume; the average size of your platelets, helping evaluate platelet production and function."
        
        // Comprehensive Metabolic Panel (CMP) Tests
        case "GLUCOSE", "BLOOD SUGAR":
            return "Blood sugar level; used to diagnose and monitor diabetes, as well as assess overall metabolic health."
        case "UREA NITROGEN", "BUN":
            return "Waste product from protein metabolism; high levels can suggest kidney issues or dehydration."
        case "CREATININE":
            return "Waste product from muscle metabolism; used to assess kidney function and overall renal health."
        case "SODIUM", "NA":
            return "Main electrolyte controlling fluid balance and nerve/muscle function throughout your body."
        case "POTASSIUM", "K":
            return "Key electrolyte essential for heart rhythm, muscle function, and nerve signal transmission."
        case "CHLORIDE", "CL":
            return "An electrolyte that helps maintain acid-base balance in your body."
        case "ECO2", "CO2", "BICARBONATE":
            return "Reflects acid-base balance; low levels can indicate acidosis and metabolic imbalances."
        case "ANION GAP":
            return "A calculation from electrolytes (sodium, chloride, bicarbonate) that helps detect metabolic imbalances like acidosis."
        case "CALCIUM", "CA":
            return "Important mineral for bones, muscles, nerves, and blood clotting processes."
        case "TOTAL PROTEIN":
            return "Combined albumin and globulins; reflects overall nutrition status and liver/kidney function."
        case "ALBUMIN":
            return "Major blood protein that maintains fluid balance and transports nutrients throughout your body."
        case "AST", "SGOT":
            return "Liver and heart enzyme; levels rise in liver or muscle injury, helping assess organ damage."
        case "ALT", "SGPT":
            return "Liver enzyme; primarily found in the liver, elevated levels indicate liver damage or disease."
        case "ALKALINE PHOSPHATASE", "ALP":
            return "Enzyme from liver and bone; elevated levels may indicate liver disease or bone disorders."
        case "BILIRUBIN TOTAL", "BILIRUBIN":
            return "Red blood cell breakdown product; serves as a marker for liver function and bile duct health."
        
        // Default case
        default:
            return "This blood test measures important health markers in your body. Results help healthcare providers assess your overall health and detect potential health issues."
        }
    }
    
    private var testNormalRange: String? {
        switch testName {
        // Complete Blood Count (CBC) Ranges
        case "WBC", "WHITE BLOOD CELLS", "WHITE BLOOD CELL COUNT":
            return "4,000–11,000 /µL"
        case "NEUTROPHILS", "NEUTROPHILS %":
            return "40–70%"
        case "NEUTROPHILS #":
            return "1.5–8.0 ×10³/µL"
        case "LYMPHS", "LYMPHS %", "LYMPHOCYTES", "LYMPHOCYTES %":
            return "20–40%"
        case "LYMPHS #", "LYMPHOCYTES #":
            return "1.0–3.0 ×10³/µL"
        case "MONOS", "MONOS %", "MONOCYTES", "MONOCYTES %":
            return "2–8%"
        case "MONOS #", "MONOCYTES #":
            return "0.2–0.8 ×10³/µL"
        case "EOS", "EOS %", "EOSINOPHILS", "EOSINOPHILS %":
            return "1–4%"
        case "EOS #", "EOSINOPHILS #":
            return "0.0–0.5 ×10³/µL"
        case "BASOS", "BASOS %", "BASOPHILS", "BASOPHILS %":
            return "0–1%"
        case "HGB", "HEMOGLOBIN":
            return "Men: 13.5–17.5 g/dL, Women: 12.0–15.5 g/dL"
        case "MCV":
            return "80–100 fL"
        case "MCH":
            return "27–33 pg"
        case "MCHC":
            return "32–36 g/dL"
        case "RDW":
            return "11.5–14.5%"
        case "PLATELET COUNT", "PLATELETS":
            return "150,000–450,000 /µL"
        case "MPV":
            return "7.5–11.5 fL"
        
        // Comprehensive Metabolic Panel (CMP) Ranges
        case "GLUCOSE", "BLOOD SUGAR":
            return "70–99 mg/dL (fasting)"
        case "UREA NITROGEN", "BUN":
            return "7–20 mg/dL"
        case "CREATININE":
            return "0.6–1.3 mg/dL"
        case "SODIUM", "NA":
            return "135–145 mEq/L"
        case "POTASSIUM", "K":
            return "3.5–5.0 mEq/L"
        case "CHLORIDE", "CL":
            return "98–106 mEq/L"
        case "ECO2", "CO2", "BICARBONATE":
            return "22–29 mEq/L"
        case "ANION GAP":
            return "8–16 mEq/L"
        case "CALCIUM", "CA":
            return "8.5–10.5 mg/dL"
        case "TOTAL PROTEIN":
            return "6.0–8.3 g/dL"
        case "ALBUMIN":
            return "3.5–5.0 g/dL"
        case "AST", "SGOT":
            return "10–40 IU/L"
        case "ALT", "SGPT":
            return "7–56 IU/L"
        case "ALKALINE PHOSPHATASE", "ALP":
            return "44–147 IU/L"
        case "BILIRUBIN TOTAL", "BILIRUBIN":
            return "0.1–1.2 mg/dL"
        
        // Default case
        default:
            return nil
        }
    }
    
    private var testHealthSignificance: String? {
        switch testName {
        // CBC Tests - Health Significance
        case "WBC", "WHITE BLOOD CELLS", "WHITE BLOOD CELL COUNT":
            return "High WBC may indicate infection, inflammation, or blood disorders. Low WBC may suggest immune suppression, bone marrow problems, or certain medications. Normal WBC levels are essential for fighting infections and maintaining immune health."
        case "NEUTROPHILS", "NEUTROPHILS %":
            return "High neutrophils often indicate bacterial infections or inflammation. Low neutrophils (neutropenia) increase infection risk and may indicate bone marrow problems, chemotherapy effects, or autoimmune disorders."
        case "NEUTROPHILS #":
            return "Absolute neutrophil count provides precise information about your body's ability to fight bacterial infections. Low counts significantly increase infection risk and require medical attention."
        case "LYMPHS", "LYMPHS %", "LYMPHOCYTES", "LYMPHOCYTES %":
            return "Lymphocytes are crucial for viral infections and immune memory. High levels may indicate viral infections, while low levels can suggest immune deficiencies or certain medications."
        case "LYMPHS #", "LYMPHOCYTES #":
            return "Absolute lymphocyte count helps assess immune function. Low counts may indicate immune suppression, while high counts can suggest viral infections or blood disorders."
        case "MONOS", "MONOS %", "MONOCYTES", "MONOCYTES %":
            return "Monocytes help fight infection and clear cellular debris. Elevated levels may indicate chronic inflammation, while low levels can suggest bone marrow problems."
        case "MONOS #", "MONOCYTES #":
            return "Absolute monocyte count helps evaluate immune function and inflammation status. Changes can indicate various inflammatory conditions or immune disorders."
        case "EOS", "EOS %", "EOSINOPHILS", "EOSINOPHILS %":
            return "Eosinophils increase with allergies, parasitic infections, or certain skin conditions. Very high levels may indicate blood disorders or severe allergic reactions."
        case "EOS #", "EOSINOPHILS #":
            return "Absolute eosinophil count helps diagnose allergic conditions, parasitic infections, and certain blood disorders. Persistent elevation requires medical evaluation."
        case "BASOS", "BASOS %", "BASOPHILS", "BASOPHILS %":
            return "Basophils are involved in allergic and inflammatory responses. Elevated levels may indicate allergies, inflammation, or certain blood disorders."
        case "HGB", "HEMOGLOBIN":
            return "Low hemoglobin indicates anemia, which can cause fatigue, weakness, and shortness of breath. High levels may suggest dehydration, blood disorders, or lung disease. Normal levels are essential for oxygen delivery."
        case "MCV":
            return "MCV helps classify anemia types. Low MCV suggests iron deficiency, while high MCV may indicate vitamin B12/folate deficiency or alcohol use. Normal MCV indicates healthy red blood cell size."
        case "MCH":
            return "MCH measures hemoglobin content per red cell. Low MCH suggests iron deficiency, while high MCH may indicate vitamin B12/folate deficiency. Normal MCH ensures adequate oxygen-carrying capacity."
        case "MCHC":
            return "MCHC indicates hemoglobin concentration in red cells. Low MCHC suggests iron deficiency anemia, while normal levels ensure efficient oxygen transport."
        case "RDW":
            return "RDW measures red blood cell size variation. High RDW suggests mixed cell populations, often indicating iron deficiency or other anemias. Normal RDW indicates uniform cell sizes."
        case "PLATELET COUNT", "PLATELETS":
            return "Low platelets increase bleeding risk and may indicate bone marrow problems, immune disorders, or certain medications. High platelets may indicate inflammation, blood disorders, or increased clotting risk."
        case "MPV":
            return "MPV helps evaluate platelet production and function. High MPV may indicate active platelet production, while low MPV can suggest bone marrow problems or certain medications."
        
        // CMP Tests - Health Significance
        case "GLUCOSE", "BLOOD SUGAR":
            return "High glucose may indicate diabetes or prediabetes, requiring lifestyle changes or medication. Low glucose can cause dizziness, confusion, and in severe cases, unconsciousness. Normal levels are essential for energy and brain function."
        case "UREA NITROGEN", "BUN":
            return "High urea nitrogen suggests kidney function problems, dehydration, or high protein intake. Low levels may indicate malnutrition or liver disease. Normal levels indicate healthy kidney function."
        case "CREATININE":
            return "High creatinine suggests kidney function problems and requires medical evaluation. Low levels may indicate reduced muscle mass, certain medications, or pregnancy. Normal levels indicate healthy kidney function."
        case "SODIUM", "NA":
            return "High sodium may indicate dehydration or kidney problems. Low sodium can cause confusion, seizures, and in severe cases, coma. Normal levels are essential for fluid balance and nerve function."
        case "POTASSIUM", "K":
            return "High potassium can cause dangerous heart rhythm problems and requires immediate medical attention. Low potassium may cause muscle weakness, heart rhythm issues, and fatigue."
        case "CHLORIDE", "CL":
            return "Chloride helps maintain acid-base balance. High levels may indicate dehydration or kidney problems, while low levels can suggest acid-base disorders or certain medications."
        case "ECO2", "CO2", "BICARBONATE":
            return "Low ECO2 (bicarbonate) can indicate acidosis, kidney problems, or respiratory disorders. High levels may suggest alkalosis or certain medications. Normal levels maintain proper acid-base balance."
        case "ANION GAP":
            return "High anion gap suggests metabolic acidosis, which can indicate diabetes, kidney failure, or poisoning. Normal anion gap helps maintain proper acid-base balance and electrolyte function."
        case "CALCIUM", "CA":
            return "High calcium may indicate parathyroid problems, cancer, or certain medications. Low calcium can cause muscle cramps, bone problems, and nerve issues. Normal levels are essential for bone health and muscle function."
        case "TOTAL PROTEIN":
            return "Low total protein may indicate malnutrition, liver disease, or kidney problems. High levels may suggest dehydration or certain blood disorders. Normal levels ensure proper nutrition and organ function."
        case "ALBUMIN":
            return "Low albumin may indicate malnutrition, liver disease, or kidney problems. It's crucial for maintaining fluid balance and transporting nutrients. Normal levels ensure proper nutrition and organ function."
        case "AST", "SGOT":
            return "High AST may indicate liver damage, heart problems, or muscle injury. Levels help monitor liver disease progression and assess organ damage. Normal levels indicate healthy liver and muscle function."
        case "ALT", "SGPT":
            return "High ALT specifically indicates liver damage or disease. ALT is more liver-specific than AST and helps diagnose liver problems. Normal levels indicate healthy liver function."
        case "ALKALINE PHOSPHATASE", "ALP":
            return "High alkaline phosphatase may indicate liver disease, bone disorders, or certain medications. Normal levels ensure proper liver and bone function."
        case "BILIRUBIN TOTAL", "BILIRUBIN":
            return "High bilirubin may indicate liver disease, bile duct problems, or blood disorders. Normal levels indicate healthy liver function and red blood cell breakdown."
        
        // Default case
        default:
            return "Abnormal results may indicate underlying health conditions. Always discuss results with your healthcare provider for proper interpretation and follow-up. Regular monitoring helps track changes and assess treatment effectiveness."
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

