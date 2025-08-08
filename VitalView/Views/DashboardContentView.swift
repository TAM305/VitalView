import SwiftUI
import HealthKit

struct DashboardContentView: View {
    let isAuthorized: Bool
    let healthMetrics: [Metric]
    let onRefresh: () -> Void
    let onAuthorize: () -> Void
    let onSelectMetric: (Metric) -> Void
    
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
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
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
                    
                    let gridColumns = [GridItem(.flexible()), GridItem(.flexible())]
                    
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(healthMetrics) { metric in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    onSelectMetric(metric)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: metric.icon)
                                            .foregroundColor(metric.color)
                                            .font(.title2)
                                            .scaleEffect(1.0)
                                            .animation(.easeInOut(duration: 0.3), value: metric.id)
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
                            .buttonStyle(PlainButtonStyle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    // Subtle tap feedback
                                }
                            }
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
