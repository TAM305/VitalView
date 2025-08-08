import SwiftUI

struct MetricDetailView: View {
    let metric: Metric
    
    var body: some View {
        VStack(spacing: 24) {
            // Header with icon and title
            VStack(spacing: 16) {
                Image(systemName: metric.icon)
                    .font(.system(size: 60))
                    .foregroundColor(metric.color)
                
                Text(metric.title)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(metric.value)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(metric.color)
                
                Text(metric.unit)
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            
            // Metric information
            VStack(spacing: 16) {
                if let date = metric.date {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.blue)
                        Text("Last Updated")
                            .font(.headline)
                        Spacer()
                        Text(date, style: .time)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Normal ranges
                VStack(alignment: .leading, spacing: 12) {
                    Text("Normal Ranges")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("Normal")
                                .font(.subheadline)
                                .foregroundColor(.green)
                            Spacer()
                            Text(getNormalRange())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        HStack {
                            Text("Elevated")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                            Spacer()
                            Text(getElevatedRange())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        HStack {
                            Text("High")
                                .font(.subheadline)
                                .foregroundColor(.red)
                            Spacer()
                            Text(getHighRange())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
            
            Spacer()
            
            // Close button
            Button("Close") {
                // This will be handled by the sheet dismissal
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 20)
        .navigationTitle("Metric Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    // This will be handled by the sheet dismissal
                }
            }
        }
    }
    
    private func getNormalRange() -> String {
        switch metric.title {
        case "Heart Rate":
            return "60-100 BPM"
        case "Blood Pressure":
            return "<120/<80 mmHg"
        case "Oxygen":
            return "95-100%"
        case "Temperature":
            return "97.8-99.0°F"
        case "Respiratory Rate":
            return "12-20 breaths/min"
        case "Heart Rate Variability":
            return "20-100 ms"
        case "Latest ECG":
            return "Normal sinus rhythm"
        default:
            return "Varies"
        }
    }
    
    private func getElevatedRange() -> String {
        switch metric.title {
        case "Heart Rate":
            return "100-120 BPM"
        case "Blood Pressure":
            return "120-129/<80 mmHg"
        case "Oxygen":
            return "90-94%"
        case "Temperature":
            return "99.1-100.4°F"
        case "Respiratory Rate":
            return "21-25 breaths/min"
        case "Heart Rate Variability":
            return "10-20 ms"
        case "Latest ECG":
            return "Mild abnormalities"
        default:
            return "Varies"
        }
    }
    
    private func getHighRange() -> String {
        switch metric.title {
        case "Heart Rate":
            return ">120 BPM"
        case "Blood Pressure":
            return "≥130/≥80 mmHg"
        case "Oxygen":
            return "<90%"
        case "Temperature":
            return ">100.4°F"
        case "Respiratory Rate":
            return ">25 breaths/min"
        case "Heart Rate Variability":
            return "<10 ms"
        case "Latest ECG":
            return "Significant abnormalities"
        default:
            return "Varies"
        }
    }
}
