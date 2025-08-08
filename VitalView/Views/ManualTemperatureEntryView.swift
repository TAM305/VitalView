import SwiftUI

struct ManualTemperatureEntryView: View {
    @Binding var isPresented: Bool
    let onSave: (Double) -> Void
    
    @State private var temperatureValue = ""
    @State private var isCelsius = true
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "thermometer")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Manual Temperature Entry")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter your current body temperature")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Temperature Input
                VStack(spacing: 16) {
                    HStack {
                        Text("Temperature:")
                            .font(.headline)
                        Spacer()
                    }
                    
                    HStack {
                        TextField("Enter temperature", text: $temperatureValue)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.title2)
                        
                        Text(isCelsius ? "°C" : "°F")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Unit Toggle
                    Picker("Unit", selection: $isCelsius) {
                        Text("Celsius (°C)").tag(true)
                        Text("Fahrenheit (°F)").tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.horizontal, 20)
                
                // Normal Range Info
                VStack(spacing: 8) {
                    Text("Normal Body Temperature Ranges:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 4) {
                        Text("Celsius: 36.1°C - 37.2°C")
                        Text("Fahrenheit: 97.0°F - 99.0°F")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Save Button
                Button(action: saveTemperature) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Save Temperature")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Temperature Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .alert("Invalid Temperature", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func saveTemperature() {
        guard let value = Double(temperatureValue) else {
            alertMessage = "Please enter a valid temperature value."
            showingAlert = true
            return
        }
        
        // Validate temperature range
        let minTemp = isCelsius ? 30.0 : 86.0
        let maxTemp = isCelsius ? 45.0 : 113.0
        
        guard value >= minTemp && value <= maxTemp else {
            alertMessage = "Temperature must be between \(Int(minTemp))\(isCelsius ? "°C" : "°F") and \(Int(maxTemp))\(isCelsius ? "°C" : "°F")."
            showingAlert = true
            return
        }
        
        // Convert to Celsius if needed (store all temperatures in Celsius)
        let temperatureInCelsius = isCelsius ? value : (value - 32) * 5/9
        
        onSave(temperatureInCelsius)
        isPresented = false
    }
}

#Preview {
    ManualTemperatureEntryView(isPresented: .constant(true)) { temperature in
        print("Temperature saved: \(temperature)°C")
    }
}
