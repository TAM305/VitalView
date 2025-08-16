import SwiftUI
import Charts

struct TrendsChartView: View {
    let data: [BloodTest]
    let testType: String
    let timeRange: BloodTestTrendsView.TimeRange
    
    // MARK: - Performance Optimization
    @State private var chartData: [ChartDataPoint] = []
    @State private var isLoadingChart = false
    @State private var cachedChartData: [String: [ChartDataPoint]] = [:]
    
    var body: some View {
        VStack(spacing: 16) {
            if isLoadingChart {
                ProgressView("Loading chart...")
                    .frame(height: 200)
            } else if chartData.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No data available")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Add blood tests to see trends over time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 200)
            } else {
                // Optimized chart with lazy loading
                LazyChartView(data: chartData, testType: testType)
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
            }
            
            // Chart statistics
            if !chartData.isEmpty {
                ChartStatisticsView(data: chartData, testType: testType)
            }
        }
        .onAppear {
            loadChartData()
        }
        .onChange(of: data) { _ in
            loadChartData()
        }
        .onChange(of: timeRange) { _ in
            loadChartData()
        }
    }
    
    // MARK: - Performance Optimization
    
    /// Loads chart data with caching for better performance
    private func loadChartData() {
        let cacheKey = "\(testType)_\(timeRange.rawValue)"
        
        // Check if we have cached data
        if let cached = cachedChartData[cacheKey] {
            chartData = cached
            return
        }
        
        isLoadingChart = true
        
        Task {
            let processedData = await processChartData()
            
            await MainActor.run {
                chartData = processedData
                isLoadingChart = false
                
                // Cache the processed data
                cachedChartData[cacheKey] = processedData
            }
        }
    }
    
    /// Processes chart data in background for better performance
    private func processChartData() async -> [ChartDataPoint] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let processed = self.data
                    .filter { test in
                        let daysSince = Calendar.current.dateComponents([.day], from: test.date, to: Date()).day ?? 0
                        return daysSince <= self.timeRange.days
                    }
                    .sorted { $0.date < $1.date }
                    .compactMap { test -> ChartDataPoint? in
                        guard let result = test.results.first(where: { $0.analyte == self.testType }) else {
                            return nil
                        }
                        
                        return ChartDataPoint(
                            date: test.date,
                            value: result.value,
                            status: result.status
                        )
                    }
                
                continuation.resume(returning: processed)
            }
        }
    }
}

// MARK: - Optimized Chart View
struct LazyChartView: View {
    let data: [ChartDataPoint]
    let testType: String
    
    var body: some View {
        Chart(data) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Value", point.value)
            )
            .foregroundStyle(Color.blue)
            .lineStyle(StrokeStyle(lineWidth: 2))
            
            PointMark(
                x: .value("Date", point.date),
                y: .value("Value", point.value)
            )
            .foregroundStyle(point.statusColor)
            .symbolSize(8)
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXScale(domain: .automatic)
    }
}

// MARK: - Chart Data Point
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let status: TestStatus
    
    var statusColor: Color {
        switch status {
        case .normal:
            return .green
        case .high:
            return .red
        case .low:
            return .orange
        }
    }
}

// MARK: - Chart Statistics View
struct ChartStatisticsView: View {
    let data: [ChartDataPoint]
    let testType: String
    
    private var statistics: ChartStatistics {
        let values = data.map { $0.value }
        let sortedValues = values.sorted()
        
        return ChartStatistics(
            count: values.count,
            average: values.reduce(0, +) / Double(values.count),
            min: sortedValues.first ?? 0,
            max: sortedValues.last ?? 0,
            median: sortedValues.count % 2 == 0 ? 
                (sortedValues[sortedValues.count / 2 - 1] + sortedValues[sortedValues.count / 2]) / 2 :
                sortedValues[sortedValues.count / 2]
        )
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Statistics")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(title: "Count", value: "\(statistics.count)")
                StatCard(title: "Average", value: String(format: "%.1f", statistics.average))
                StatCard(title: "Range", value: String(format: "%.1f - %.1f", statistics.min, statistics.max))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Chart Statistics
struct ChartStatistics {
    let count: Int
    let average: Double
    let min: Double
    let max: Double
    let median: Double
}

// MARK: - Stat Card
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
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}
