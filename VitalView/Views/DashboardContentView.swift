import SwiftUI

struct DashboardContentView: View {
    let isAuthorized: Bool
    let healthMetrics: [Metric]
    let onRefresh: () -> Void
    let onAuthorize: () -> Void
    
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
                        Text("Please authorize access to your health data to view your metrics.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button("Authorize HealthKit") {
                            onAuthorize()
                        }
                        .buttonStyle(.borderedProminent)
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
                    
                    let gridColumns = [GridItem(.flexible()), GridItem(.flexible())]
                    
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(healthMetrics) { metric in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: metric.icon)
                                        .foregroundColor(metric.color)
                                        .font(.title2)
                                    Spacer()
                                    Text(metric.value)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                }
                                
                                Text(metric.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(metric.unit)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if let date = metric.date {
                                    Text(date, style: .time)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(radius: 2)
                            .frame(height: 110)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(UIColor.systemBackground))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
