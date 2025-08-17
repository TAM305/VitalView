import SwiftUI

struct MetricDetailView: View {
    let metric: Metric
    @Environment(\.dismiss) private var dismiss
    @State private var showingManualEntry = false
    @State private var manualSystolic = ""
    @State private var manualDiastolic = ""
    @State private var manualTemperature = ""
    @State private var manualDate = Date()
    @State private var showingSuccessAlert = false
    
    var body: some View {
        ScrollView {
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
                
                // Manual Entry Button (for Blood Pressure and Temperature)
                if metric.title == "Blood Pressure" || metric.title == "Temperature" {
                    Button(action: { showingManualEntry = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Manual Reading")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(metric.color)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                // Metric explanation with improved layout
                VStack(alignment: .leading, spacing: 16) {
                    Text("About \(metric.title)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    Text(getMetricExplanation())
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                }
                .padding(.vertical, 16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Metric information with improved spacing
                VStack(spacing: 20) {
                    if let date = metric.date {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                            Text("Last Updated")
                                .font(.headline)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(date, style: .date)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(date, style: .time)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Normal ranges with improved layout
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Normal Ranges")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 10, height: 10)
                                Text("Normal")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                                Spacer()
                                Text(getNormalRange())
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            
                            HStack {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 10, height: 10)
                                Text("Elevated")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                                Spacer()
                                Text(getElevatedRange())
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            
                            HStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 10, height: 10)
                                Text("High")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                                Spacer()
                                Text(getHighRange())
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                // Bottom spacing for better scrolling
                Spacer(minLength: 100)
            }
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
        .sheet(isPresented: $showingManualEntry) {
            ManualMetricEntryView(
                metricTitle: metric.title,
                systolic: $manualSystolic,
                diastolic: $manualDiastolic,
                temperature: $manualTemperature,
                date: $manualDate,
                onSave: saveManualReading
            )
        }
        .alert("Reading Saved", isPresented: $showingSuccessAlert) {
            Button("OK") { }
        } message: {
            Text("Your manual reading has been saved successfully.")
        }
    }
    
    private func getMetricExplanation() -> String {
        switch metric.title {
        case "Heart Rate":
            return "Heart rate measures how many times your heart beats per minute. It's a key indicator of cardiovascular health and can vary based on activity level, stress, and overall fitness. A normal resting heart rate is typically between 60-100 beats per minute, but this can vary based on age, fitness level, and other factors."
        case "Blood Pressure":
            return "Blood pressure measures the force of blood against artery walls. Systolic pressure (top number) is the pressure when your heart beats, while diastolic pressure (bottom number) is the pressure between beats. Normal blood pressure is below 120/80 mmHg. High blood pressure can increase your risk of heart disease and stroke."
        case "Oxygen":
            return "Oxygen saturation (SpO2) measures how much oxygen your blood is carrying. It's crucial for cellular function and indicates how well your lungs and heart are working together. Normal oxygen saturation is 95-100%. Low levels can indicate breathing problems, heart conditions, or other health issues."
        case "Temperature":
            return "Body temperature indicates your body's ability to regulate heat. Normal temperature helps fight infections and maintain optimal cellular function. The average normal body temperature is around 98.6°F (37°C), but it can vary throughout the day and between individuals. Elevated temperature often indicates infection or illness."
        case "Respiratory Rate":
            return "Respiratory rate is how many breaths you take per minute. It's essential for oxygen delivery and carbon dioxide removal. Normal respiratory rate is 12-20 breaths per minute at rest. Changes can indicate stress, illness, respiratory conditions, or other health issues that affect breathing."
        case "Heart Rate Variability":
            return "Heart Rate Variability (HRV) measures the variation in time between heartbeats. Higher HRV generally indicates better cardiovascular fitness and stress resilience. It's a key marker of autonomic nervous system health and can be affected by stress, sleep, exercise, and overall health status."
        case "Latest ECG":
            return "Electrocardiogram (ECG) records your heart's electrical activity. It helps detect irregular heart rhythms, heart attacks, and other cardiovascular conditions. The ECG provides valuable information about heart health and can help identify potential issues before they become serious."
        default:
            return "This metric provides important information about your health status and should be monitored regularly. Understanding your health metrics helps you make informed decisions about your lifestyle and healthcare needs."
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
    
    private func saveManualReading() {
        // Save to HealthKit
        Task {
            await saveToHealthKit()
        }
        
        // Show success message
        showingSuccessAlert = true
        
        // Reset form
        manualSystolic = ""
        manualDiastolic = ""
        manualTemperature = ""
        manualDate = Date()
    }
    
    private func saveToHealthKit() async {
        if metric.title == "Blood Pressure" {
            guard let systolicValue = Double(manualSystolic),
                  let diastolicValue = Double(manualDiastolic) else { return }
            
            // Save blood pressure to HealthKit
            await saveBloodPressureToHealthKit(systolic: systolicValue, diastolic: diastolicValue, date: manualDate)
            
        } else if metric.title == "Temperature" {
            guard let tempValue = Double(manualTemperature) else { return }
            
            // Save temperature to HealthKit
            await saveTemperatureToHealthKit(temperature: tempValue, date: manualDate)
        }
    }
    
    private func saveBloodPressureToHealthKit(systolic: Double, diastolic: Double, date: Date) async {
        // This would integrate with your HealthKitManager
        // For now, we'll just print the values
        print("Saving Blood Pressure to HealthKit: \(systolic)/\(diastolic) mmHg at \(date)")
        
        // TODO: Integrate with HealthKitManager to actually save the data
        // Example:
        // let healthKitManager = HealthKitManager()
        // await healthKitManager.saveBloodPressure(systolic: systolic, diastolic: diastolic, date: date)
    }
    
    private func saveTemperatureToHealthKit(temperature: Double, date: Date) async {
        // This would integrate with your HealthKitManager
        // For now, we'll just print the values
        print("Saving Temperature to HealthKit: \(temperature)°F at \(date)")
        
        // TODO: Integrate with HealthKitManager to actually save the data
        // Example:
        // let healthKitManager = HealthKitManager()
        // await healthKitManager.saveBodyTemperature(temperature: temperature, date: date)
    }
}

// MARK: - Manual Metric Entry View

struct ManualMetricEntryView: View {
    let metricTitle: String
    @Binding var systolic: String
    @Binding var diastolic: String
    @Binding var temperature: String
    @Binding var date: Date
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Reading Details")) {
                    if metricTitle == "Blood Pressure" {
                        HStack {
                            Text("Systolic")
                            Spacer()
                            TextField("120", text: $systolic)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                            Text("mmHg")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Diastolic")
                            Spacer()
                            TextField("80", text: $diastolic)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                            Text("mmHg")
                                .foregroundColor(.secondary)
                        }
                    } else if metricTitle == "Temperature" {
                        HStack {
                            Text("Temperature")
                            Spacer()
                            TextField("98.6", text: $temperature)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text("°F")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section(header: Text("Reference Ranges")) {
                    if metricTitle == "Blood Pressure" {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text("Normal: <120/<80 mmHg")
                                    .font(.caption)
                            }
                            HStack {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 8, height: 8)
                                Text("Elevated: 120-129/<80 mmHg")
                                    .font(.caption)
                            }
                            HStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                Text("High: ≥130/≥80 mmHg")
                                    .font(.caption)
                            }
                        }
                    } else if metricTitle == "Temperature" {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text("Normal: 97.8-99.0°F")
                                    .font(.caption)
                            }
                            HStack {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 8, height: 8)
                                Text("Elevated: 99.1-100.4°F")
                                    .font(.caption)
                            }
                            HStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                Text("High: >100.4°F")
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                Section {
                    Button("Save Reading") {
                        if validateInput() {
                            onSave()
                            dismiss()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding()
                    .background(metricTitle == "Blood Pressure" ? .blue : .orange)
                    .cornerRadius(8)
                    .disabled(!canSave)
                }
            }
            .navigationTitle("Add \(metricTitle) Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Invalid Input", isPresented: $showingValidationAlert) {
            Button("OK") { }
        } message: {
            Text(validationMessage)
        }
    }
    
    private var canSave: Bool {
        if metricTitle == "Blood Pressure" {
            return !systolic.isEmpty && !diastolic.isEmpty
        } else if metricTitle == "Temperature" {
            return !temperature.isEmpty
        }
        return false
    }
    
    private func validateInput() -> Bool {
        if metricTitle == "Blood Pressure" {
            guard let systolicValue = Double(systolic), let diastolicValue = Double(diastolic) else {
                validationMessage = "Please enter valid numbers for blood pressure."
                showingValidationAlert = true
                return false
            }
            
            if systolicValue < 50 || systolicValue > 300 {
                validationMessage = "Systolic pressure should be between 50-300 mmHg."
                showingValidationAlert = true
                return false
            }
            
            if diastolicValue < 30 || diastolicValue > 200 {
                validationMessage = "Diastolic pressure should be between 30-200 mmHg."
                showingValidationAlert = true
                return false
            }
            
            if systolicValue < diastolicValue {
                validationMessage = "Systolic pressure should be higher than diastolic pressure."
                showingValidationAlert = true
                return false
            }
            
        } else if metricTitle == "Temperature" {
            guard let tempValue = Double(temperature) else {
                validationMessage = "Please enter a valid temperature."
                showingValidationAlert = true
                return false
            }
            
            if tempValue < 90 || tempValue > 110 {
                validationMessage = "Temperature should be between 90-110°F."
                showingValidationAlert = true
                return false
            }
        }
        
        return true
    }
}

#Preview {
    MetricDetailView(
        metric: Metric(
            title: "Blood Pressure",
            value: "120/80",
            unit: "mmHg",
            icon: "waveform.path.ecg",
            color: .blue,
            date: Date()
        )
    )
}
