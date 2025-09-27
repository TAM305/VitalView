import SwiftUI

/// Main view for displaying Apple Intelligence-powered health insights
@available(iOS 18.0, *)
struct HealthInsightsView: View {
    @StateObject private var insightsManager: HealthInsightsManager
    @State private var selectedCategory: HealthInsightCategory?
    @State private var showingInsightDetail = false
    @State private var selectedInsight: HealthInsight?
    
    init(healthKitManager: HealthKitManager, bloodTestViewModel: BloodTestViewModel) {
        self._insightsManager = StateObject(wrappedValue: HealthInsightsManager(
            healthKitManager: healthKitManager,
            bloodTestViewModel: bloodTestViewModel
        ))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if insightsManager.isLoading {
                    loadingView
                } else if insightsManager.currentInsights.isEmpty {
                    emptyStateView
                } else {
                    insightsContent
                }
            }
            .navigationTitle("Health Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await insightsManager.generateInsights()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .disabled(insightsManager.isLoading)
                }
            }
        }
        .sheet(isPresented: $showingInsightDetail) {
            if let insight = selectedInsight {
                InsightDetailView(insight: insight)
            }
        }
        .onAppear {
            Task {
                await insightsManager.generateInsights()
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Analyzing your health data...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Apple Intelligence is processing your vital signs and blood test results to provide personalized insights.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("No Insights Available")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add some health data to get personalized insights powered by Apple Intelligence.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Generate Insights") {
                Task {
                    await insightsManager.generateInsights()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Insights Content
    
    private var insightsContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Category filter
                categoryFilter
                
                // Insights list
                ForEach(filteredInsights) { insight in
                    InsightCardView(insight: insight) {
                        selectedInsight = insight
                        showingInsightDetail = true
                    }
                }
                
                // Last updated info
                if let lastUpdate = insightsManager.lastAnalysisDate {
                    lastUpdatedView(lastUpdate)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Category Filter
    
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All categories button
                Button(action: { selectedCategory = nil }) {
                    Text("All")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(selectedCategory == nil ? .white : .blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedCategory == nil ? Color.blue : Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
                
                // Category buttons
                ForEach(HealthInsightCategory.allCases, id: \.self) { category in
                    Button(action: { selectedCategory = category }) {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.system(size: 14))
                            Text(category.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(selectedCategory == category ? .white : category.color)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedCategory == category ? category.color : category.color.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Last Updated View
    
    private func lastUpdatedView(_ date: Date) -> some View {
        HStack {
            Image(systemName: "clock")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Last updated \(date, style: .relative)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.top, 8)
    }
    
    // MARK: - Computed Properties
    
    private var filteredInsights: [HealthInsight] {
        if let category = selectedCategory {
            return insightsManager.currentInsights.filter { $0.category == category }
        } else {
            return insightsManager.currentInsights
        }
    }
}

// MARK: - Insight Card View

@available(iOS 18.0, *)
struct InsightCardView: View {
    let insight: HealthInsight
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: insight.category.icon)
                            .font(.system(size: 16))
                            .foregroundColor(insight.category.color)
                        
                        Text(insight.category.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(insight.category.color)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: insight.priority.icon)
                            .font(.system(size: 14))
                            .foregroundColor(insight.priority.color)
                        
                        Text(insight.priority.rawValue == 1 ? "Low" : insight.priority.rawValue == 2 ? "Medium" : "High")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(insight.priority.color)
                    }
                }
                
                // Title
                Text(insight.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                // Message
                Text(insight.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                // Confidence indicator
                HStack {
                    Text("Confidence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            Circle()
                                .fill(index < Int(insight.confidence * 5) ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(insight.priority.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Insight Detail View

@available(iOS 18.0, *)
struct InsightDetailView: View {
    let insight: HealthInsight
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: insight.category.icon)
                                .font(.system(size: 24))
                                .foregroundColor(insight.category.color)
                            
                            VStack(alignment: .leading) {
                                Text(insight.category.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(insight.category.color)
                                
                                Text(insight.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Image(systemName: insight.priority.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(insight.priority.color)
                                
                                Text(insight.priority.rawValue == 1 ? "Low Priority" : insight.priority.rawValue == 2 ? "Medium Priority" : "High Priority")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(insight.priority.color)
                            }
                        }
                        
                        Divider()
                    }
                    
                    // Message
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Analysis")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(insight.message)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Recommendation
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recommendation")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(insight.recommendation)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Confidence
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confidence Level")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack {
                            Text("\(Int(insight.confidence * 100))%")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                ForEach(0..<5) { index in
                                    Circle()
                                        .fill(index < Int(insight.confidence * 5) ? Color.blue : Color.gray.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                }
                            }
                        }
                    }
                    
                    // Related Metrics
                    if !insight.relatedMetrics.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Related Metrics")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                ForEach(insight.relatedMetrics, id: \.self) { metric in
                                    Text(metric)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.gray.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    
                    // Timestamp
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Generated \(insight.timestamp, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
                .padding()
            }
            .navigationTitle("Insight Details")
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

// MARK: - Preview

@available(iOS 18.0, *)
struct HealthInsightsView_Previews: PreviewProvider {
    static var previews: some View {
        HealthInsightsView(
            healthKitManager: HealthKitManager(),
            bloodTestViewModel: BloodTestViewModel(context: PersistenceController.shared.container.viewContext)
        )
    }
}
