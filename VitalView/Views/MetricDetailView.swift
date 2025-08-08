import SwiftUI

struct MetricDetailView: View {
    let metric: Metric
    @Environment(\.dismiss) private var dismiss
    
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
            
            // Metric explanation
            VStack(alignment: .leading, spacing: 12) {
                Text("About \(metric.title)")
                    .font(.headline)
                    .padding(.horizontal)
                
                Text(getMetricExplanation())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
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
                dismiss()
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
                    dismiss()
                }
            }
        }
    }
    
    private func getMetricExplanation() -> String {
        switch metric.title {
        case "Heart Rate":
            return "Heart rate measures how many times your heart beats per minute. It's a key indicator of cardiovascular health and can vary based on activity level, stress, and overall fitness."
        case "Blood Pressure":
            return "Blood pressure measures the force of blood against artery walls. Systolic (top number) is pressure when heart beats, diastolic (bottom number) is pressure between beats."
        case "Oxygen":
            return "Oxygen saturation measures how much oxygen your blood is carrying. It's crucial for cellular function and indicates how well your lungs and heart are working together."
        case "Temperature":
            return "Body temperature indicates your body's ability to regulate heat. Normal temperature helps fight infections and maintain optimal cellular function."
        case "Respiratory Rate":
            return "Respiratory rate is how many breaths you take per minute. It's essential for oxygen delivery and can indicate stress, illness, or respiratory conditions."
        case "Heart Rate Variability":
            return "HRV measures the variation in time between heartbeats. Higher HRV indicates better cardiovascular fitness and stress resilience."
        case "Latest ECG":
            return "Electrocardiogram (ECG) records your heart's electrical activity. It helps detect irregular heart rhythms and cardiovascular conditions."
        default:
            return "This metric provides important information about your health status and should be monitored regularly."
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
