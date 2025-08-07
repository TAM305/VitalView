import SwiftUI
import HealthKit

struct DashboardContentView: View {
    let isAuthorized: Bool
    let healthMetrics: [Metric]
    let onRefresh: () -> Void
    let onAuthorize: () -> Void
    @State private var selectedMetric = "Heart Rate"
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Health Metrics Dashboard")
                    .font(.title)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 12)
                    .padding(.top, 16)
                
                HStack {
                    Spacer()
                    Button(action: onRefresh) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 20))
                            Text("Refresh")
                                .font(.subheadline)
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.trailing, 12)
                }
                
                if !isAuthorized {
                    VStack(spacing: 12) {
                        Text("HealthKit Access Required")
                            .font(.headline)
                        
                        if HKHealthStore.isHealthDataAvailable() {
                            Text("Please authorize access to your health data to view your metrics.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Button("Authorize HealthKit") {
                                onAuthorize()
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Text("HealthKit is not available on this device. Please test on a physical iPhone to access health data.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Continue Without HealthKit") {
                                // Allow user to continue with manual data entry
                                onAuthorize() // This will be handled by the parent view
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                } else {
                    Text("This dashboard displays your latest vital signs and health metrics from HealthKit.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                    
                    Spacer().frame(height: 32)
                    
                    // Tab Selection
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(healthMetrics) { metric in
                                Button(action: {
                                    selectedMetric = metric.title
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: metric.icon)
                                            .font(.title2)
                                            .foregroundColor(selectedMetric == metric.title ? metric.color : .secondary)
                                        Text(metric.title)
                                            .font(.caption)
                                            .foregroundColor(selectedMetric == metric.title ? metric.color : .secondary)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedMetric == metric.title ? metric.color.opacity(0.1) : Color.clear)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    
                    Spacer().frame(height: 20)
                    
                    // Selected Metric Detail View
                    if let selectedMetricData = healthMetrics.first(where: { $0.title == selectedMetric }) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: selectedMetricData.icon)
                                    .font(.largeTitle)
                                    .foregroundColor(selectedMetricData.color)
                                VStack(alignment: .leading) {
                                    Text(selectedMetricData.title)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Text(selectedMetricData.value)
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(selectedMetricData.color)
                                    Text(selectedMetricData.unit)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(radius: 2)
                            
                            if let date = selectedMetricData.date {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(.secondary)
                                    Text("Last updated: \(date, style: .time)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(UIColor.systemBackground))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
