import SwiftUI

struct DashboardContentView: View {
    let isAuthorized: Bool
    let healthMetrics: [HealthMetricsView.Metric]
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
                            let card = MetricCard(
                                title: metric.title,
                                value: metric.value,
                                unit: metric.unit,
                                icon: metric.icon,
                                color: metric.color,
                                date: metric.date
                            )
                            card.frame(height: 110)
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
