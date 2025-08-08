import SwiftUI
import HealthKit

struct DashboardContentView: View {
    let isAuthorized: Bool
    let healthMetrics: [Metric]
    let onRefresh: () -> Void
    let onAuthorize: () -> Void
    let onSelectMetric: (Metric) -> Void
    
    @State private var selectedMetricIndex = 0
    
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
                    
                    // Interactive Tab Navigation
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(Array(healthMetrics.enumerated()), id: \.element.id) { index, metric in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        selectedMetricIndex = index
                                    }
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: metric.icon)
                                            .font(.title2)
                                            .foregroundColor(selectedMetricIndex == index ? metric.color : .gray)
                                            .scaleEffect(selectedMetricIndex == index ? 1.2 : 1.0)
                                            .animation(.easeInOut(duration: 0.2), value: selectedMetricIndex)
                                        
                                        Text(metric.title)
                                            .font(.caption)
                                            .fontWeight(selectedMetricIndex == index ? .semibold : .regular)
                                            .foregroundColor(selectedMetricIndex == index ? metric.color : .gray)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedMetricIndex == index ? metric.color.opacity(0.1) : Color.clear)
                                    )
                                    .animation(.easeInOut(duration: 0.2), value: selectedMetricIndex)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 8)
                    
                    // Selected Metric Detail View
                    if !healthMetrics.isEmpty {
                        let selectedMetric = healthMetrics[selectedMetricIndex]
                        
                        VStack(spacing: 16) {
                            // Large Metric Display
                            VStack(spacing: 12) {
                                Image(systemName: selectedMetric.icon)
                                    .font(.system(size: 48))
                                    .foregroundColor(selectedMetric.color)
                                    .scaleEffect(1.0)
                                    .animation(.easeInOut(duration: 0.3), value: selectedMetricIndex)
                                
                                Text(selectedMetric.value)
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text(selectedMetric.unit)
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                                
                                Text(selectedMetric.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            .padding(24)
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(radius: 4)
                            .padding(.horizontal, 16)
                            
                            // Additional Info
                            if let date = selectedMetric.date {
                                VStack(spacing: 8) {
                                    Text("Last Updated")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text(date, style: .relative)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    
                                    Text(date, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .padding(.horizontal, 16)
                            }
                            
                            // Action Button
                            Button {
                                onSelectMetric(selectedMetric)
                            } label: {
                                HStack {
                                    Image(systemName: "info.circle")
                                    Text("Learn More")
                                }
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(selectedMetric.color)
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .animation(.easeInOut(duration: 0.3), value: selectedMetricIndex)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(UIColor.systemBackground))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
