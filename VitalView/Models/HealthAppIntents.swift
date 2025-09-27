import Foundation
import SwiftUI

#if canImport(AppIntents)
import AppIntents
#endif

/// App Intents for VitalView health insights and Siri integration
///
/// This file defines the App Intents that allow Apple Intelligence and Siri
/// to interact with VitalView's health analysis capabilities.
///
/// ## Available Intents
/// - `GetHealthInsightsIntent`: Get current health insights
/// - `AnalyzeBloodTestIntent`: Analyze specific blood test results
/// - `GetHealthSummaryIntent`: Get overall health summary
///
/// ## Usage
/// These intents are automatically available to Siri and Apple Intelligence
/// when the app is installed and the user grants permission.

#if canImport(AppIntents)

// MARK: - Health Insights Intent

@available(iOS 18.1, *)
struct GetHealthInsightsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Health Insights"
    static var description = IntentDescription("Get AI-powered health insights from your blood test data and vital signs.")
    
    @Parameter(title: "Category", description: "Filter insights by category")
    var category: HealthInsightCategory?
    
    @Parameter(title: "Priority", description: "Filter insights by priority level")
    var priority: HealthInsightPriority?
    
    func perform() async throws -> some IntentResult & ReturnsValue<[HealthInsightResult]> {
        // This would integrate with your HealthInsightsManager
        // For now, return sample data
        let sampleInsights = [
            HealthInsightResult(
                title: "Heart Rate Analysis",
                message: "Your heart rate is in the normal range.",
                recommendation: "Continue monitoring regularly.",
                priority: .low,
                category: .vitalSigns
            )
        ]
        
        return .result(value: sampleInsights)
    }
}

// MARK: - Blood Test Analysis Intent

@available(iOS 18.1, *)
struct AnalyzeBloodTestIntent: AppIntent {
    static var title: LocalizedStringResource = "Analyze Blood Test"
    static var description = IntentDescription("Analyze specific blood test results for health insights.")
    
    @Parameter(title: "Test Type", description: "Type of blood test to analyze")
    var testType: String
    
    @Parameter(title: "Date", description: "Date of the blood test")
    var testDate: Date?
    
    func perform() async throws -> some IntentResult & ReturnsValue<[HealthInsightResult]> {
        // This would integrate with your HealthInsightsManager
        // For now, return sample data
        let sampleInsights = [
            HealthInsightResult(
                title: "\(testType) Analysis",
                message: "Analysis of your \(testType) results shows normal values.",
                recommendation: "Continue regular monitoring.",
                priority: .low,
                category: .bloodTests
            )
        ]
        
        return .result(value: sampleInsights)
    }
}

// MARK: - Health Summary Intent

@available(iOS 18.1, *)
struct GetHealthSummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Health Summary"
    static var description = IntentDescription("Get an overall summary of your health status and recommendations.")
    
    func perform() async throws -> some IntentResult & ReturnsValue<HealthSummaryResult> {
        // This would integrate with your HealthInsightsManager
        // For now, return sample data
        let summary = HealthSummaryResult(
            overallScore: 85,
            keyFindings: ["Heart rate normal", "Blood pressure stable"],
            recommendations: ["Continue regular exercise", "Maintain current diet"],
            lastUpdated: Date()
        )
        
        return .result(value: summary)
    }
}

// MARK: - Result Types

@available(iOS 18.1, *)
struct HealthInsightResult: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Health Insight"
    static var defaultQuery = HealthInsightQuery()
    
    let id = UUID()
    let title: String
    let message: String
    let recommendation: String
    let priority: HealthInsightPriority
    let category: HealthInsightCategory
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(message)"
        )
    }
}

@available(iOS 18.1, *)
struct HealthSummaryResult: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Health Summary"
    static var defaultQuery = HealthSummaryQuery()
    
    let id = UUID()
    let overallScore: Int
    let keyFindings: [String]
    let recommendations: [String]
    let lastUpdated: Date
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "Health Score: \(overallScore)/100",
            subtitle: "Last updated: \(lastUpdated.formatted(date: .abbreviated, time: .omitted))"
        )
    }
}

// MARK: - Enums for App Intents

@available(iOS 18.1, *)
enum HealthInsightCategory: String, AppEntity, CaseIterable {
    case vitalSigns = "Vital Signs"
    case bloodTests = "Blood Tests"
    case overall = "Overall Health"
    case lifestyle = "Lifestyle"
    case monitoring = "Monitoring"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Health Insight Category"
    static var defaultQuery = HealthInsightCategoryQuery()
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(rawValue)")
    }
}

@available(iOS 18.1, *)
enum HealthInsightPriority: String, AppEntity, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Health Insight Priority"
    static var defaultQuery = HealthInsightPriorityQuery()
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(rawValue)")
    }
}

// MARK: - Query Types

@available(iOS 18.1, *)
struct HealthSummaryQuery: EntityQuery {
    func entities(for identifiers: [HealthSummaryResult.ID]) async throws -> [HealthSummaryResult] {
        // Return health summaries for the given identifiers
        return []
    }
    
    func entities(matching string: String) async throws -> [HealthSummaryResult] {
        // Search for health summaries matching the string
        return []
    }
    
    func suggestedEntities() async throws -> [HealthSummaryResult] {
        // Return suggested health summaries
        return []
    }
}

@available(iOS 18.1, *)
struct HealthInsightQuery: EntityQuery {
    func entities(for identifiers: [HealthInsightResult.ID]) async throws -> [HealthInsightResult] {
        // Return insights for the given identifiers
        return []
    }
    
    func entities(matching string: String) async throws -> [HealthInsightResult] {
        // Search for insights matching the string
        return []
    }
    
    func suggestedEntities() async throws -> [HealthInsightResult] {
        // Return suggested insights
        return []
    }
}

@available(iOS 18.1, *)
struct HealthInsightCategoryQuery: EntityQuery {
    func entities(for identifiers: [HealthInsightCategory.ID]) async throws -> [HealthInsightCategory] {
        return HealthInsightCategory.allCases
    }
    
    func entities(matching string: String) async throws -> [HealthInsightCategory] {
        return HealthInsightCategory.allCases.filter { $0.rawValue.localizedCaseInsensitiveContains(string) }
    }
    
    func suggestedEntities() async throws -> [HealthInsightCategory] {
        return HealthInsightCategory.allCases
    }
}

@available(iOS 18.1, *)
struct HealthInsightPriorityQuery: EntityQuery {
    func entities(for identifiers: [HealthInsightPriority.ID]) async throws -> [HealthInsightPriority] {
        return HealthInsightPriority.allCases
    }
    
    func entities(matching string: String) async throws -> [HealthInsightPriority] {
        return HealthInsightPriority.allCases.filter { $0.rawValue.localizedCaseInsensitiveContains(string) }
    }
    
    func suggestedEntities() async throws -> [HealthInsightPriority] {
        return HealthInsightPriority.allCases
    }
}

#endif // canImport(AppIntents)
