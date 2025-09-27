import SwiftUI

/// Compact widget for displaying key health insights on the dashboard
@available(iOS 18.0, *)
struct InsightsWidgetView: View {
    @StateObject private var insightsManager: HealthInsightsManager
    @State private var showingFullInsights = false
    
    init(healthKitManager: HealthKitManager, bloodTestViewModel: BloodTestViewModel) {
        self._insightsManager = StateObject(wrappedValue: HealthInsightsManager(
            healthKitManager: healthKitManager,
            bloodTestViewModel: bloodTestViewModel
        ))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                    
                    Text("AI Insights")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                Button(action: {
                    showingFullInsights = true
                }) {
                    Text("View All")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
            
            if insightsManager.isLoading {
                loadingState
            } else if insightsManager.currentInsights.isEmpty {
                emptyState
            } else {
                insightsContent
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .sheet(isPresented: $showingFullInsights) {
            HealthInsightsView(
                healthKitManager: HealthKitManager(),
                bloodTestViewModel: BloodTestViewModel(context: PersistenceController.shared.container.viewContext)
            )
        }
        .onAppear {
            Task {
                await insightsManager.generateInsights()
            }
        }
    }
    
    // MARK: - Loading State
    
    private var loadingState: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            
            Text("Analyzing your health data...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No insights available")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Add health data to get personalized AI insights")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Insights Content
    
    private var insightsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Show top 3 insights
            ForEach(Array(insightsManager.currentInsights.prefix(3))) { insight in
                InsightRowView(insight: insight)
            }
            
            if insightsManager.currentInsights.count > 3 {
                Text("+ \(insightsManager.currentInsights.count - 3) more insights")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - Insight Row View

@available(iOS 18.0, *)
struct InsightRowView: View {
    let insight: AIHealthInsight
    
    var body: some View {
        HStack(spacing: 12) {
            // Priority indicator
            Circle()
                .fill(insight.priority.color)
                .frame(width: 8, height: 8)
            
            // Category icon
            Image(systemName: insight.category.icon)
                .font(.system(size: 14))
                .foregroundColor(insight.category.color)
                .frame(width: 20)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(insight.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Confidence indicator
            HStack(spacing: 2) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(index < Int(insight.confidence * 3) ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 4, height: 4)
                }
            }
        }
    }
}

// MARK: - Quick Insight Card

@available(iOS 18.0, *)
struct QuickInsightCard: View {
    let insight: AIHealthInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: insight.category.icon)
                    .font(.system(size: 16))
                    .foregroundColor(insight.category.color)
                
                Text(insight.category.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(insight.category.color)
                
                Spacer()
                
                Image(systemName: insight.priority.icon)
                    .font(.system(size: 14))
                    .foregroundColor(insight.priority.color)
            }
            
            Text(insight.title)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)
            
            Text(insight.message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding()
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(insight.priority.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

@available(iOS 18.0, *)
struct InsightsWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            InsightsWidgetView(
                healthKitManager: HealthKitManager(),
                bloodTestViewModel: BloodTestViewModel(context: PersistenceController.shared.container.viewContext)
            )
            
            QuickInsightCard(
                insight: AIHealthInsight(
                    id: UUID(),
                    category: .vitalSigns,
                    priority: .medium,
                    title: "Heart Rate Analysis",
                    message: "Your heart rate is in the normal range (72 BPM).",
                    recommendation: "Keep up the good work! Regular exercise helps maintain a healthy heart rate.",
                    confidence: 0.85,
                    relatedMetrics: ["heartRate"],
                    timestamp: Date()
                )
            )
        }
        .padding()
    }
}
