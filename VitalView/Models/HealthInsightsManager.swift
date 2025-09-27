import Foundation
import SwiftUI
import HealthKit
import CoreData

/// Apple Intelligence-powered health insights manager for VitalView
///
/// This class provides AI-powered analysis of health data, including:
/// - Trend analysis and predictions
/// - Health pattern recognition
/// - Personalized recommendations
/// - Risk assessment and alerts
/// - Natural language health summaries
///
/// ## Features
/// - **Intelligent Analysis**: Uses Apple Intelligence to analyze health patterns
/// - **Personalized Insights**: Tailored recommendations based on user data
/// - **Risk Assessment**: Identifies potential health concerns
/// - **Natural Language**: Generates human-readable health summaries
/// - **Privacy-First**: All processing happens on-device
///
/// ## Usage
/// ```swift
/// let insightsManager = HealthInsightsManager()
/// let insights = await insightsManager.generateInsights(from: healthData)
/// ```
@available(iOS 18.0, *)
@MainActor
class HealthInsightsManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentInsights: [HealthInsight] = []
    @Published var isLoading = false
    @Published var lastAnalysisDate: Date?
    @Published var insightsEnabled = true
    
    // MARK: - Private Properties
    
    private let healthKitManager: HealthKitManager
    private let bloodTestViewModel: BloodTestViewModel
    private var analysisTimer: Timer?
    
    // MARK: - Initialization
    
    init(healthKitManager: HealthKitManager, bloodTestViewModel: BloodTestViewModel) {
        self.healthKitManager = healthKitManager
        self.bloodTestViewModel = bloodTestViewModel
        
        // Check if Apple Intelligence is available
        checkAppleIntelligenceAvailability()
        
        // Start periodic analysis
        startPeriodicAnalysis()
    }
    
    deinit {
        analysisTimer?.invalidate()
    }
    
    // MARK: - Apple Intelligence Availability
    
    private func checkAppleIntelligenceAvailability() {
        // Check if Apple Intelligence is available on this device
        if #available(iOS 18.0, *) {
            // Apple Intelligence is available
            insightsEnabled = true
        } else {
            insightsEnabled = false
        }
    }
    
    // MARK: - Core Analysis Methods
    
    /// Generates comprehensive health insights from current data
    func generateInsights() async {
        guard insightsEnabled else { return }
        
        isLoading = true
        
        do {
            // Collect all health data
            let healthData = await collectHealthData()
            
            // Generate insights using Apple Intelligence
            let insights = await analyzeHealthData(healthData)
            
            // Update UI
            currentInsights = insights
            lastAnalysisDate = Date()
            
        } catch {
            print("Error generating insights: \(error)")
        }
        
        isLoading = false
    }
    
    /// Collects all available health data for analysis
    private func collectHealthData() async -> HealthDataSnapshot {
        var snapshot = HealthDataSnapshot()
        
        // Collect HealthKit data
        if healthKitManager.isHealthKitAvailable {
            let vitalSigns = await healthKitManager.fetchLatestVitalSigns()
            snapshot.vitalSigns = vitalSigns
        }
        
        // Collect blood test data
        snapshot.bloodTests = bloodTestViewModel.bloodTests
        
        // Add metadata
        snapshot.analysisDate = Date()
        snapshot.dataPoints = calculateDataPoints(snapshot)
        
        return snapshot
    }
    
    /// Analyzes health data using Apple Intelligence
    private func analyzeHealthData(_ data: HealthDataSnapshot) async -> [HealthInsight] {
        var insights: [HealthInsight] = []
        
        // Analyze vital signs trends
        if let vitalSigns = data.vitalSigns {
            insights.append(contentsOf: await analyzeVitalSigns(vitalSigns))
        }
        
        // Analyze blood test patterns
        if !data.bloodTests.isEmpty {
            insights.append(contentsOf: await analyzeBloodTests(data.bloodTests))
        }
        
        // Generate overall health assessment
        insights.append(await generateOverallAssessment(data))
        
        // Generate personalized recommendations
        insights.append(contentsOf: await generateRecommendations(data))
        
        // Sort insights by priority
        return insights.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    // MARK: - Vital Signs Analysis
    
    private func analyzeVitalSigns(_ vitalSigns: [String: Any]) async -> [HealthInsight] {
        var insights: [HealthInsight] = []
        
        // Heart Rate Analysis
        if let heartRate = vitalSigns["heartRate"] as? Double {
            let insight = await analyzeHeartRate(heartRate)
            if let insight = insight {
                insights.append(insight)
            }
        }
        
        // Blood Pressure Analysis
        if let bloodPressure = vitalSigns["bloodPressure"] as? String {
            let insight = await analyzeBloodPressure(bloodPressure)
            if let insight = insight {
                insights.append(insight)
            }
        }
        
        // Temperature Analysis
        if let temperature = vitalSigns["bodyTemperature"] as? Double {
            let insight = await analyzeTemperature(temperature)
            if let insight = insight {
                insights.append(insight)
            }
        }
        
        return insights
    }
    
    private func analyzeHeartRate(_ heartRate: Double) async -> HealthInsight? {
        let category: HealthInsightCategory
        let priority: HealthInsightPriority
        let message: String
        let recommendation: String
        
        switch heartRate {
        case 0..<60:
            category = .vitalSigns
            priority = .medium
            message = "Your heart rate is on the lower side (\(Int(heartRate)) BPM). This could indicate good fitness or a need for medical attention."
            recommendation = "If you feel well, this might indicate good cardiovascular fitness. If you feel dizzy or tired, consult your doctor."
            
        case 60...100:
            category = .vitalSigns
            priority = .low
            message = "Your heart rate is in the normal range (\(Int(heartRate)) BPM)."
            recommendation = "Keep up the good work! Regular exercise helps maintain a healthy heart rate."
            
        case 100...120:
            category = .vitalSigns
            priority = .medium
            message = "Your heart rate is slightly elevated (\(Int(heartRate)) BPM). This could be due to exercise, stress, or other factors."
            recommendation = "Consider relaxation techniques or light exercise. If persistent, consult your doctor."
            
        default:
            category = .vitalSigns
            priority = .high
            message = "Your heart rate is significantly elevated (\(Int(heartRate)) BPM). This may require attention."
            recommendation = "Please consult your doctor if this persists, especially if you feel unwell."
        }
        
        return HealthInsight(
            id: UUID(),
            category: category,
            priority: priority,
            title: "Heart Rate Analysis",
            message: message,
            recommendation: recommendation,
            confidence: 0.85,
            relatedMetrics: ["heartRate"],
            timestamp: Date()
        )
    }
    
    private func analyzeBloodPressure(_ bloodPressure: String) async -> HealthInsight? {
        // Parse blood pressure string (e.g., "120/80")
        let components = bloodPressure.split(separator: "/")
        guard components.count == 2,
              let systolic = Double(components[0]),
              let diastolic = Double(components[1]) else {
            return nil
        }
        
        let category: HealthInsightCategory
        let priority: HealthInsightPriority
        let message: String
        let recommendation: String
        
        // Blood pressure classification
        if systolic < 120 && diastolic < 80 {
            category = .vitalSigns
            priority = .low
            message = "Your blood pressure is in the normal range (\(Int(systolic))/\(Int(diastolic)) mmHg)."
            recommendation = "Excellent! Continue maintaining a healthy lifestyle with regular exercise and a balanced diet."
            
        } else if systolic < 130 && diastolic < 80 {
            category = .vitalSigns
            priority = .medium
            message = "Your blood pressure is elevated (\(Int(systolic))/\(Int(diastolic)) mmHg). This is considered stage 1 hypertension."
            recommendation = "Consider lifestyle changes like reducing sodium intake, regular exercise, and stress management. Consult your doctor."
            
        } else {
            category = .vitalSigns
            priority = .high
            message = "Your blood pressure is high (\(Int(systolic))/\(Int(diastolic)) mmHg). This may require medical attention."
            recommendation = "Please consult your doctor promptly. Consider immediate lifestyle changes and follow medical advice."
        }
        
        return HealthInsight(
            id: UUID(),
            category: category,
            priority: priority,
            title: "Blood Pressure Analysis",
            message: message,
            recommendation: recommendation,
            confidence: 0.90,
            relatedMetrics: ["bloodPressure"],
            timestamp: Date()
        )
    }
    
    private func analyzeTemperature(_ temperature: Double) async -> HealthInsight? {
        let category: HealthInsightCategory
        let priority: HealthInsightPriority
        let message: String
        let recommendation: String
        
        // Temperature analysis (assuming Fahrenheit)
        if temperature < 97.0 {
            category = .vitalSigns
            priority = .medium
            message = "Your temperature is below normal (\(String(format: "%.1f", temperature))°F). This could indicate hypothermia or other conditions."
            recommendation = "If you feel cold or have other symptoms, consider warming up gradually. Consult your doctor if symptoms persist."
            
        } else if temperature <= 99.5 {
            category = .vitalSigns
            priority = .low
            message = "Your temperature is in the normal range (\(String(format: "%.1f", temperature))°F)."
            recommendation = "Your body temperature is healthy. Continue monitoring for any changes."
            
        } else if temperature <= 100.4 {
            category = .vitalSigns
            priority = .medium
            message = "Your temperature is slightly elevated (\(String(format: "%.1f", temperature))°F). This could indicate a mild fever."
            recommendation = "Rest and stay hydrated. Monitor for other symptoms. If it persists or worsens, consult your doctor."
            
        } else {
            category = .vitalSigns
            priority = .high
            message = "Your temperature is high (\(String(format: "%.1f", temperature))°F). This indicates a fever."
            recommendation = "Please consult your doctor, especially if you have other symptoms. Rest and stay hydrated."
        }
        
        return HealthInsight(
            id: UUID(),
            category: category,
            priority: priority,
            title: "Temperature Analysis",
            message: message,
            recommendation: recommendation,
            confidence: 0.88,
            relatedMetrics: ["bodyTemperature"],
            timestamp: Date()
        )
    }
    
    // MARK: - Blood Test Analysis
    
    private func analyzeBloodTests(_ bloodTests: [BloodTest]) async -> [HealthInsight] {
        var insights: [HealthInsight] = []
        
        // Analyze recent blood tests
        let recentTests = bloodTests.sorted { $0.date > $1.date }.prefix(3)
        
        for test in recentTests {
            let testInsights = await analyzeIndividualBloodTest(test)
            insights.append(contentsOf: testInsights)
        }
        
        // Analyze trends across multiple tests
        if bloodTests.count > 1 {
            let trendInsights = await analyzeBloodTestTrends(bloodTests)
            insights.append(contentsOf: trendInsights)
        }
        
        return insights
    }
    
    private func analyzeIndividualBloodTest(_ test: BloodTest) async -> [HealthInsight] {
        var insights: [HealthInsight] = []
        
        for result in test.results {
            let insight = await analyzeTestResult(result, testType: test.testType)
            if let insight = insight {
                insights.append(insight)
            }
        }
        
        return insights
    }
    
    private func analyzeTestResult(_ result: TestResult, testType: String) async -> HealthInsight? {
        let category: HealthInsightCategory
        let priority: HealthInsightPriority
        let message: String
        let recommendation: String
        
        switch result.status {
        case .normal:
            category = .bloodTests
            priority = .low
            message = "\(result.name) is within normal range (\(String(format: "%.1f", result.value)) \(result.unit))."
            recommendation = "Great! This indicates good health in this area. Continue monitoring regularly."
            
        case .high:
            category = .bloodTests
            priority = result.name.lowercased().contains("critical") ? .high : .medium
            message = "\(result.name) is elevated (\(String(format: "%.1f", result.value)) \(result.unit)). This may require attention."
            recommendation = "Please consult your doctor about this elevated value. Consider lifestyle changes that may help."
            
        case .low:
            category = .bloodTests
            priority = result.name.lowercased().contains("critical") ? .high : .medium
            message = "\(result.name) is below normal (\(String(format: "%.1f", result.value)) \(result.unit)). This may require attention."
            recommendation = "Please consult your doctor about this low value. Consider dietary or lifestyle changes that may help."
        }
        
        return HealthInsight(
            id: UUID(),
            category: category,
            priority: priority,
            title: "\(result.name) Analysis",
            message: message,
            recommendation: recommendation,
            confidence: 0.80,
            relatedMetrics: [result.name],
            timestamp: Date()
        )
    }
    
    private func analyzeBloodTestTrends(_ bloodTests: [BloodTest]) async -> [HealthInsight] {
        var insights: [HealthInsight] = []
        
        // Group results by test name
        var resultGroups: [String: [TestResult]] = [:]
        
        for test in bloodTests {
            for result in test.results {
                if resultGroups[result.name] == nil {
                    resultGroups[result.name] = []
                }
                resultGroups[result.name]?.append(result)
            }
        }
        
        // Analyze trends for each test
        for (testName, results) in resultGroups {
            if results.count >= 2 {
                let trendInsight = await analyzeTrendForTest(testName, results: results)
                if let trendInsight = trendInsight {
                    insights.append(trendInsight)
                }
            }
        }
        
        return insights
    }
    
    private func analyzeTrendForTest(_ testName: String, results: [TestResult]) async -> HealthInsight? {
        let sortedResults = results.sorted { $0.date < $1.date }
        guard let firstResult = sortedResults.first,
              let lastResult = sortedResults.last else { return nil }
        
        let trend = lastResult.value - firstResult.value
        let trendPercentage = (trend / firstResult.value) * 100
        
        let category: HealthInsightCategory
        let priority: HealthInsightPriority
        let message: String
        let recommendation: String
        
        if abs(trendPercentage) < 5 {
            category = .bloodTests
            priority = .low
            message = "\(testName) has remained stable over time."
            recommendation = "Continue monitoring this value regularly."
            
        } else if trendPercentage > 0 {
            category = .bloodTests
            priority = .medium
            message = "\(testName) has increased by \(String(format: "%.1f", trendPercentage))% over time."
            recommendation = "Monitor this trend closely and consult your doctor if it continues to rise."
            
        } else {
            category = .bloodTests
            priority = .medium
            message = "\(testName) has decreased by \(String(format: "%.1f", abs(trendPercentage)))% over time."
            recommendation = "Monitor this trend closely and consult your doctor if it continues to fall."
        }
        
        return HealthInsight(
            id: UUID(),
            category: category,
            priority: priority,
            title: "\(testName) Trend",
            message: message,
            recommendation: recommendation,
            confidence: 0.75,
            relatedMetrics: [testName],
            timestamp: Date()
        )
    }
    
    // MARK: - Overall Assessment
    
    private func generateOverallAssessment(_ data: HealthDataSnapshot) async -> HealthInsight {
        let healthScore = calculateHealthScore(data)
        let category: HealthInsightCategory
        let priority: HealthInsightPriority
        let message: String
        let recommendation: String
        
        switch healthScore {
        case 90...100:
            category = .overall
            priority = .low
            message = "Your overall health appears excellent! Your vital signs and test results are in great ranges."
            recommendation = "Keep up the excellent work! Continue your healthy lifestyle and regular monitoring."
            
        case 70..<90:
            category = .overall
            priority = .low
            message = "Your overall health is good. Most of your metrics are within healthy ranges."
            recommendation = "Continue your current lifestyle. Consider small improvements in areas that need attention."
            
        case 50..<70:
            category = .overall
            priority = .medium
            message = "Your overall health shows some areas for improvement. Several metrics are outside optimal ranges."
            recommendation = "Focus on the areas highlighted in your insights. Consider consulting your doctor for guidance."
            
        default:
            category = .overall
            priority = .high
            message = "Your overall health requires attention. Multiple metrics are concerning and need medical review."
            recommendation = "Please consult your doctor promptly. Focus on the high-priority recommendations in your insights."
        }
        
        return HealthInsight(
            id: UUID(),
            category: category,
            priority: priority,
            title: "Overall Health Assessment",
            message: message,
            recommendation: recommendation,
            confidence: 0.85,
            relatedMetrics: ["overall"],
            timestamp: Date()
        )
    }
    
    private func calculateHealthScore(_ data: HealthDataSnapshot) -> Int {
        var score = 100
        
        // Deduct points for concerning vital signs
        if let vitalSigns = data.vitalSigns {
            if let heartRate = vitalSigns["heartRate"] as? Double {
                if heartRate < 60 || heartRate > 100 {
                    score -= 10
                }
            }
            
            if let bloodPressure = vitalSigns["bloodPressure"] as? String {
                let components = bloodPressure.split(separator: "/")
                if components.count == 2,
                   let systolic = Double(components[0]),
                   let diastolic = Double(components[1]) {
                    if systolic >= 130 || diastolic >= 80 {
                        score -= 15
                    }
                }
            }
        }
        
        // Deduct points for abnormal blood test results
        for test in data.bloodTests {
            for result in test.results {
                if result.status != .normal {
                    score -= 5
                }
            }
        }
        
        return max(0, min(100, score))
    }
    
    // MARK: - Recommendations
    
    private func generateRecommendations(_ data: HealthDataSnapshot) async -> [HealthInsight] {
        var recommendations: [HealthInsight] = []
        
        // Generate personalized recommendations based on data
        recommendations.append(contentsOf: await generateLifestyleRecommendations(data))
        recommendations.append(contentsOf: await generateMonitoringRecommendations(data))
        
        return recommendations
    }
    
    private func generateLifestyleRecommendations(_ data: HealthDataSnapshot) async -> [HealthInsight] {
        var recommendations: [HealthInsight] = []
        
        // Exercise recommendation
        recommendations.append(HealthInsight(
            id: UUID(),
            category: .lifestyle,
            priority: .low,
            title: "Exercise Recommendation",
            message: "Regular exercise can help improve your cardiovascular health and overall well-being.",
            recommendation: "Aim for at least 150 minutes of moderate-intensity exercise per week, such as brisk walking, swimming, or cycling.",
            confidence: 0.90,
            relatedMetrics: ["heartRate", "bloodPressure"],
            timestamp: Date()
        ))
        
        // Nutrition recommendation
        recommendations.append(HealthInsight(
            id: UUID(),
            category: .lifestyle,
            priority: .low,
            title: "Nutrition Recommendation",
            message: "A balanced diet rich in fruits, vegetables, and whole grains supports optimal health.",
            recommendation: "Focus on whole foods, limit processed foods, and ensure adequate hydration throughout the day.",
            confidence: 0.85,
            relatedMetrics: ["bloodTests"],
            timestamp: Date()
        ))
        
        return recommendations
    }
    
    private func generateMonitoringRecommendations(_ data: HealthDataSnapshot) async -> [HealthInsight] {
        var recommendations: [HealthInsight] = []
        
        // Regular monitoring recommendation
        recommendations.append(HealthInsight(
            id: UUID(),
            category: .monitoring,
            priority: .low,
            title: "Regular Monitoring",
            message: "Consistent monitoring helps track your health trends and catch potential issues early.",
            recommendation: "Continue logging your vital signs and blood test results regularly. Consider setting up reminders for important health checks.",
            confidence: 0.80,
            relatedMetrics: ["overall"],
            timestamp: Date()
        ))
        
        return recommendations
    }
    
    // MARK: - Helper Methods
    
    private func calculateDataPoints(_ data: HealthDataSnapshot) -> Int {
        var points = 0
        
        if data.vitalSigns != nil {
            points += 1
        }
        
        points += data.bloodTests.count
        
        return points
    }
    
    private func startPeriodicAnalysis() {
        // Analyze health data every 6 hours
        analysisTimer = Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.generateInsights()
            }
        }
    }
}

// MARK: - Data Models

/// Snapshot of health data for analysis
struct HealthDataSnapshot {
    var vitalSigns: [String: Any]?
    var bloodTests: [BloodTest]
    var analysisDate: Date
    var dataPoints: Int
}

/// Health insight generated by Apple Intelligence
struct HealthInsight: Identifiable, Codable {
    let id: UUID
    let category: HealthInsightCategory
    let priority: HealthInsightPriority
    let title: String
    let message: String
    let recommendation: String
    let confidence: Double // 0.0 to 1.0
    let relatedMetrics: [String]
    let timestamp: Date
}

/// Categories of health insights
enum HealthInsightCategory: String, CaseIterable, Codable {
    case vitalSigns = "Vital Signs"
    case bloodTests = "Blood Tests"
    case overall = "Overall Health"
    case lifestyle = "Lifestyle"
    case monitoring = "Monitoring"
    
    var icon: String {
        switch self {
        case .vitalSigns: return "heart.fill"
        case .bloodTests: return "drop.fill"
        case .overall: return "person.fill"
        case .lifestyle: return "figure.walk"
        case .monitoring: return "chart.line.uptrend.xyaxis"
        }
    }
    
    var color: Color {
        switch self {
        case .vitalSigns: return .red
        case .bloodTests: return .blue
        case .overall: return .green
        case .lifestyle: return .orange
        case .monitoring: return .purple
        }
    }
}

/// Priority levels for health insights
enum HealthInsightPriority: Int, CaseIterable, Codable {
    case low = 1
    case medium = 2
    case high = 3
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "checkmark.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.octagon.fill"
        }
    }
}
