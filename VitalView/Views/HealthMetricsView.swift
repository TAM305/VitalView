import SwiftUI
import HealthKit
import UIKit
import CoreData
import Charts

struct HealthMetricsView: View {
    @StateObject private var viewModel = HealthMetricsViewModel()
    @State private var isAuthorized = false
    @State private var showingAddTest = false
    @State private var showingTrends = false
    @State private var selectedMetric = "Heart Rate"
    @State private var isLoadingTrends = false
    @State private var trendData: [String: [HealthReading]] = [:]
    @State private var trendAnalysis: [String: TrendAnalysis] = [:]
    
    // Add test form states
    @State private var currentStep = 1
    @State private var selectedTestType = ""
    @State private var testValues: [String: String] = [:]
    @State private var testDate = Date()
    @State private var showTrends = false
    @State private var testResults: [BloodTest] = []
    
    private let healthStore = HKHealthStore()
    
    // Health data states
    @State private var heartRate = HealthData()
    @State private var bloodPressure = BloodPressureData()
    @State private var oxygenSaturation = HealthData()
    @State private var temperature = HealthData()
    @State private var respiratoryRate = HealthData()
    @State private var heartRateVariability = HealthData()
    @State private var ecgData: [ECGReading] = []
    
    var body: some View {
        ZStack {
            DashboardContentView(
                isAuthorized: isAuthorized,
                healthMetrics: healthMetrics,
                onRefresh: {
                    print("\n=== Manual Refresh Triggered ===")
                    fetchLatestVitalSigns()
                },
                onAuthorize: {
                    requestHealthKitAuthorization()
                }
            )
            bottomButtonsView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingAddTest) {
            AddTestSheetView(isPresented: $showingAddTest)
        }
        .sheet(isPresented: $showingTrends) {
            NavigationView {
                VStack(spacing: 20) {
                    Text("Health Trends")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.top, 20)
                    
                    Text("This feature is coming soon!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    Button("Close") {
                        showingTrends = false
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 20)
                }
                .navigationTitle("Health Trends")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingTrends = false
                        }
                    }
                }
            }
        }

        .onAppear {
            requestHealthKitAuthorization()
        }
    }
    
    private var bottomButtonsView: some View {
        VStack {
            Spacer()
            HStack {
                Button(action: { showingTrends = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.blue)
                        Text("Trend")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                }
                Spacer()
                Button(action: { showingAddTest = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.red)
                        Text("Add Blood Test")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 12)
            .padding(.bottom, 24)
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    // Computed property for metrics to avoid complex expressions in body
    private var healthMetrics: [Metric] {
        let heartRateMetric = Metric(
            title: "Heart Rate",
            value: heartRate.value.map { "\(Int($0))" } ?? "--",
            unit: "BPM",
            icon: "heart.fill",
            color: .red,
            date: heartRate.date
        )
        
        let bloodPressureValue: String
        if let systolic = bloodPressure.systolic, let diastolic = bloodPressure.diastolic {
            bloodPressureValue = "\(Int(systolic))/\(Int(diastolic))"
        } else {
            bloodPressureValue = "--/--"
        }
        let bloodPressureMetric = Metric(
            title: "Blood Pressure",
            value: bloodPressureValue,
            unit: "mmHg",
            icon: "waveform.path.ecg",
            color: .blue,
            date: bloodPressure.date
        )
        
        let oxygenMetric = Metric(
            title: "Oxygen",
            value: oxygenSaturation.value.map { "\(Int($0))" } ?? "--",
            unit: "%",
            icon: "lungs.fill",
            color: .green,
            date: oxygenSaturation.date
        )
        
        let temperatureMetric = Metric(
            title: "Temperature",
            value: temperature.value.map { String(format: "%.1f", $0) } ?? "--",
            unit: "°F",
            icon: "thermometer",
            color: .orange,
            date: temperature.date
        )
        
        let respiratoryRateMetric = Metric(
            title: "Respiratory Rate",
            value: respiratoryRate.value.map { String(format: "%.1f", $0) } ?? "--",
            unit: "breaths/min",
            icon: "lungs",
            color: .purple,
            date: respiratoryRate.date
        )
        
        let hrvMetric = Metric(
            title: "Heart Rate Variability",
            value: heartRateVariability.value.map { String(format: "%.1f", $0) } ?? "--",
            unit: "ms",
            icon: "waveform.path.ecg.rectangle",
            color: .purple,
            date: heartRateVariability.date
        )
        
        let ecgValue: String
        if !ecgData.isEmpty, let firstECG = ecgData.first {
            ecgValue = String(format: "%.1f", firstECG.value)
        } else {
            ecgValue = "--"
        }
        let ecgMetric = Metric(
            title: "Latest ECG",
            value: ecgValue,
            unit: "mV",
            icon: "waveform.path.ecg",
            color: .red,
            date: ecgData.first?.date
        )
        
        return [
            heartRateMetric,
            bloodPressureMetric,
            oxygenMetric,
            temperatureMetric,
            respiratoryRateMetric,
            hrvMetric,
            ecgMetric
        ]
    }
    
    private func requestHealthKitAuthorization() {
        print("=== HealthKit Authorization Debug ===")
        print("HealthKit available: \(HKHealthStore.isHealthDataAvailable())")
        
        // Check if HealthKit is available
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            // Allow user to continue with manual data entry even without HealthKit
            isAuthorized = true
            return
        }
        
        // Define the types we want to read from HealthKit
        var typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .bodyTemperature)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.electrocardiogramType()
        ]
        
        // Add basal body temperature if available
        if let basalTemperatureType = HKObjectType.quantityType(forIdentifier: .basalBodyTemperature) {
            typesToRead.insert(basalTemperatureType)
        }
        
        print("Requesting authorization for \(typesToRead.count) health data types")
        
        // Request authorization
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                print("Authorization result: success=\(success), error=\(error?.localizedDescription ?? "none")")
                if success {
                    print("HealthKit authorization successful!")
                    isAuthorized = true
                    fetchLatestVitalSigns()
                } else {
                    print("HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")")
                    if let error = error {
                        print("Error details: \(error)")
                    }
                }
            }
        }
    }
    
    private func fetchLatestVitalSigns() {
        guard isAuthorized else { return }
        
        // Use a background queue for data fetching
        DispatchQueue.global(qos: .userInitiated).async {
            // Fetch heart rate
            self.fetchHeartRate()
            
            // Fetch blood pressure
            self.fetchBloodPressure()
            
            // Fetch oxygen saturation
            self.fetchOxygenSaturation()
            
            // Fetch body temperature
            self.fetchBodyTemperature()
            
            // Fetch respiratory rate
            self.fetchRespiratoryRate()
            
            // Fetch heart rate variability
            self.fetchHeartRateVariability()
            
            // Fetch ECG data
            self.fetchECGData()
        }
    }
    
    private func fetchHeartRate() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-24*60*60), end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                DispatchQueue.main.async {
                if let sample = samples?.first as? HKQuantitySample {
                    let value = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    self.heartRate = HealthData(value: value, date: sample.endDate)
                }
            }
        }
        healthStore.execute(query)
    }

    private func fetchBloodPressure() {
        guard let systolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-24*60*60), end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        // Create a correlation query to get both systolic and diastolic readings together
        let correlationQuery = HKCorrelationQuery(type: HKCorrelationType(.bloodPressure), predicate: predicate, sortDescriptors: [sortDescriptor]) { _, correlations, error in
            DispatchQueue.main.async {
                if let correlation = correlations?.first {
                    let systolicSamples = correlation.objects(for: systolicType)
                    let diastolicSamples = correlation.objects(for: diastolicType)
                    
                    if let systolicSample = systolicSamples.first as? HKQuantitySample,
                       let diastolicSample = diastolicSamples.first as? HKQuantitySample {
                        let systolic = systolicSample.quantity.doubleValue(for: HKUnit.millimeterOfMercury())
                        let diastolic = diastolicSample.quantity.doubleValue(for: HKUnit.millimeterOfMercury())
                        
                        self.bloodPressure = BloodPressureData(
                            systolic: systolic,
                            diastolic: diastolic,
                            date: correlation.endDate
                        )
                    }
                } else if let error = error {
                    print("Error fetching blood pressure: \(error.localizedDescription)")
                }
            }
        }
        
        healthStore.execute(correlationQuery)
    }
    
    private func fetchOxygenSaturation() {
        guard let oxygenType = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-24*60*60), end: Date(), options: .strictEndDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: oxygenType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                    DispatchQueue.main.async {
                if let sample = samples?.first as? HKQuantitySample {
                    let value = sample.quantity.doubleValue(for: HKUnit.percent())
                    self.oxygenSaturation = HealthData(value: value * 100, date: sample.endDate)
                }
                }
            }
            healthStore.execute(query)
    }
    
    private func fetchBodyTemperature() {
        // Try both body temperature and basal body temperature
        let bodyTempType = HKObjectType.quantityType(forIdentifier: .bodyTemperature)
        let basalTempType = HKObjectType.quantityType(forIdentifier: .basalBodyTemperature)
        
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-24*60*60), end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        // Function to handle temperature data
        let processTemperature = { (samples: [HKSample]?, error: Error?) in
            DispatchQueue.main.async {
                if let sample = samples?.first as? HKQuantitySample {
                    let value = sample.quantity.doubleValue(for: HKUnit.degreeFahrenheit())
                    self.temperature = HealthData(value: value, date: sample.endDate)
                } else if let error = error {
                    print("Error fetching temperature: \(error.localizedDescription)")
                }
            }
        }
        
        // Try body temperature first
        if let tempType = bodyTempType {
            let query = HKSampleQuery(sampleType: tempType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if samples?.isEmpty ?? true, let basalType = basalTempType {
                    // If no body temperature, try basal temperature
                    let basalQuery = HKSampleQuery(sampleType: basalType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, basalSamples, basalError in
                        processTemperature(basalSamples, basalError)
                    }
                    self.healthStore.execute(basalQuery)
                } else {
                    processTemperature(samples, error)
                }
            }
            healthStore.execute(query)
        } else if let basalType = basalTempType {
            // If no body temperature type, try basal temperature directly
            let query = HKSampleQuery(sampleType: basalType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                processTemperature(samples, error)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchRespiratoryRate() {
        guard let respiratoryType = HKObjectType.quantityType(forIdentifier: .respiratoryRate) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-24*60*60), end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: respiratoryType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                    DispatchQueue.main.async {
                if let sample = samples?.first as? HKQuantitySample {
                    let value = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    self.respiratoryRate = HealthData(value: value, date: sample.endDate)
                }
                }
            }
            healthStore.execute(query)
    }
    
    private func fetchHeartRateVariability() {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-24*60*60), end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                DispatchQueue.main.async {
                if let sample = samples?.first as? HKQuantitySample {
                    let value = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                    self.heartRateVariability = HealthData(value: value, date: sample.endDate)
                }
                }
            }
            healthStore.execute(query)
    }
    
    private func fetchECGData() {
        let ecgType = HKObjectType.electrocardiogramType()
        
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-24*60*60), end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: ecgType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            guard let ecg = samples?.first as? HKElectrocardiogram else { return }
            
            // Get the voltage measurements
            let voltageQuery = HKElectrocardiogramQuery(ecg) { query, result in
                switch result {
                case let .measurement(measurement):
                    if let voltageValue = measurement.quantity.doubleValue(for: .voltUnit(with: .milli)) {
                        DispatchQueue.main.async {
                            self.ecgData = [ECGReading(value: voltageValue, date: measurement.timeSinceSampleStart)]
                        }
                    }
                case .done:
                    query.stop()
                case let .error(error):
                    print("Error fetching ECG data: \(error.localizedDescription)")
                @unknown default:
                    break
                }
            }
            
            self.healthStore.execute(voltageQuery)
        }
        healthStore.execute(query)
    }
}

// Data structures
struct HealthData {
    let value: Double?
    let date: Date?
    
    init(value: Double? = nil, date: Date? = nil) {
        self.value = value
        self.date = date
    }
}

struct BloodPressureData {
    var systolic: Double?
    var diastolic: Double?
    var date: Date?
}

struct ECGReading {
    let value: Double
    let date: Date
}

struct Metric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    let date: Date?
}

struct HealthReading {
    let value: Double
    let date: Date
}

struct TrendAnalysis {
    let direction: TrendDirection
    let confidence: Double
    let healthStatus: HealthStatus
    let rateOfChange: Double
    let recommendation: String
}

enum TrendDirection {
    case increasing, decreasing, stable
    
    var icon: String {
        switch self {
        case .increasing: return "arrow.up"
        case .decreasing: return "arrow.down"
        case .stable: return "arrow.right"
        }
    }
    
    var color: Color {
        switch self {
        case .increasing: return .red
        case .decreasing: return .green
        case .stable: return .blue
        }
    }
    
    var description: String {
        switch self {
        case .increasing: return "Increasing"
        case .decreasing: return "Decreasing"
        case .stable: return "Stable"
        }
    }
}

enum HealthStatus {
    case excellent, good, fair, poor
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }
    
    var description: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        }
    }
}



class HealthMetricsViewModel: ObservableObject {
    @Published var isAuthorized = false
    @Published var showingAddTest = false
    @Published var showingTrends = false
    @Published var showingSettings = false
}

