import SwiftUI

struct MetricInfoView: View {
    let metric: Metric
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section(header: Text("Overview")) {
                Text(overview)
            }
            
            if let detail = detailText, !detail.isEmpty {
                Section(header: Text("Details")) {
                    Text(detail)
                }
            }
            
            if let date = metric.date {
                Section(header: Text("Last Updated")) {
                    Text(date, style: .date)
                    Text(date, style: .time)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(metric.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
    
    private var overview: String {
        switch metric.title {
        case "Heart Rate":
            return "Heart rate is the number of times your heart beats per minute."
        case "Blood Pressure":
            return "Blood pressure measures the force of blood pushing against the artery walls."
        case "Oxygen":
            return "Oxygen saturation indicates the percentage of oxygen-carrying hemoglobin in the blood."
        case "Temperature":
            return "Body temperature reflects your body's ability to generate and get rid of heat."
        case "Respiratory Rate":
            return "Respiratory rate is the number of breaths you take per minute."
        case "Heart Rate Variability":
            return "HRV reflects the variation in time between heartbeats and is linked to stress and fitness levels."
        case "Latest ECG":
            return "ECG measures the electrical activity of your heart over time."
        default:
            return "This metric provides important insights into your health."
        }
    }
    
    private var detailText: String? {
        switch metric.title {
        case "Heart Rate":
            return "Normal resting heart rate for adults ranges from 60 to 100 BPM."
        case "Blood Pressure":
            return "A normal blood pressure is typically around 120/80 mmHg."
        case "Oxygen":
            return "Normal SpO₂ levels are generally between 95% and 100%."
        case "Temperature":
            return "Normal body temperature is around 98.6°F (37°C), but can vary."
        case "Respiratory Rate":
            return "Normal adult respiratory rate is 12 to 20 breaths per minute."
        case "Heart Rate Variability":
            return "Higher HRV is often associated with better cardiovascular fitness and resilience."
        case "Latest ECG":
            return "ECG values are shown in millivolts (mV). Abnormal readings may indicate arrhythmias or other heart conditions."
        default:
            return nil
        }
    }
}


