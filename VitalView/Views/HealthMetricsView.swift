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
    @State private var showManualTemperatureEntry = false
    @State private var authorizationAttempted = false
    
    private let healthStore = HKHealthStore()
    
    // Health data states
    @State private var heartRate = HealthData()
    @State private var bloodPressure = BloodPressureData()
    @State private var oxygenSaturation = HealthData()
    @State private var temperature = HealthData()
    @State private var temperatureIsDelta = false
    @State private var respiratoryRate = HealthData()
    @State private var heartRateVariability = HealthData()
    @State private var ecgData: [ECGReading] = []
    @State private var ecgAverageHeartRateBPM: Double?
    @State private var selectedMetricInfo: Metric?
    
    var body: some View {
        ZStack {
            DashboardContentView(
                isAuthorized: isAuthorized,
                healthMetrics: healthMetrics,
                authorizationAttempted: authorizationAttempted,
                onRefresh: {
                    print("\n=== Manual Refresh Triggered ===")
                    print("Current authorization status: \(isAuthorized)")
                    print("HealthKit available: \(HKHealthStore.isHealthDataAvailable())")
                    fetchLatestVitalSigns()
                },
                onAuthorize: {
                    requestHealthKitAuthorization()
                },
                onSelectMetric: { metric in
                    selectedMetricInfo = metric
                },
                onManualTemperatureEntry: {
                    showManualTemperatureEntry = true
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

        .sheet(item: $selectedMetricInfo) { metric in
            NavigationView {
                MetricInfoView(metric: metric)
            }
        }
        .sheet(isPresented: $showManualTemperatureEntry) {
            ManualTemperatureEntryView(isPresented: $showManualTemperatureEntry) { temperature in
                // Save manual temperature entry
                self.temperature = HealthData(value: temperature, date: Date())
                self.temperatureIsDelta = false
            }
        }

        .onAppear {
            // Delay authorization request to ensure UI is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                requestHealthKitAuthorization()
            }
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
        // Debug all health data values
        print("=== Health Metrics Debug ===")
        print("Heart Rate: \(heartRate.value?.description ?? "nil")")
        print("Blood Pressure: systolic=\(bloodPressure.systolic?.description ?? "nil"), diastolic=\(bloodPressure.diastolic?.description ?? "nil")")
        print("Oxygen Saturation: \(oxygenSaturation.value?.description ?? "nil")")
        print("Respiratory Rate: \(respiratoryRate.value?.description ?? "nil")")
        print("Heart Rate Variability: \(heartRateVariability.value?.description ?? "nil")")
        print("Temperature: \(temperature.value?.description ?? "nil")")
        
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
        
        // Debug temperature data
        print("Temperature debug - value: \(temperature.value?.description ?? "nil"), date: \(temperature.date?.description ?? "nil"), isDelta: \(temperatureIsDelta)")
        
        let temperatureValue: String
        let temperatureUnit: String
        let temperatureColor: Color
        
        if let tempValue = temperature.value {
            temperatureValue = String(format: "%.1f", tempValue)
            temperatureUnit = temperatureIsDelta ? "Δ \(temperatureUnitSymbol)" : temperatureUnitSymbol
            temperatureColor = .orange
            print("Temperature data found: \(temperatureValue) \(temperatureUnit)")
        } else {
            // Check if we're on simulator or if HealthKit is available
            if !HKHealthStore.isHealthDataAvailable() {
                temperatureValue = "N/A"
                temperatureUnit = "Simulator"
                temperatureColor = .gray
                print("Temperature not available on simulator")
            } else {
                temperatureValue = "Tap to add"
                temperatureUnit = "Manual entry"
                temperatureColor = .blue
                print("No temperature data available on device - showing manual entry option")
            }
        }
        
        let temperatureMetric = Metric(
            title: "Temperature",
            value: temperatureValue,
            unit: temperatureUnit,
            icon: "thermometer",
            color: temperatureColor,
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
        print("ECG data count: \(ecgData.count)")
        if let firstECG = ecgData.first {
            // Use µV if very small, else mV; also show one decimal for mV, no decimals for µV
            if firstECG.value < 1.0 {
                ecgValue = String(format: "%.0f", firstECG.value * 1000.0) // µV
            } else {
                ecgValue = String(format: "%.1f", firstECG.value) // mV
            }
            print("ECG value displayed: \(ecgValue) \(firstECG.value < 1.0 ? "µV" : "mV")")
        } else {
            // Check if we're on a simulator or device without ECG capability
            if !HKHealthStore.isHealthDataAvailable() {
                ecgValue = "N/A"
                print("ECG not available on simulator")
            } else {
                ecgValue = "--"
                print("No ECG data available (requires Apple Watch Series 4+)")
            }
        }
        // Determine base unit for amplitude
        let baseECGUnit = ecgData.first.map { $0.value < 1.0 ? "µV" : "mV" } ?? "mV"
        // Append average BPM if available
        let ecgUnitWithBPM: String
        if let bpm = ecgAverageHeartRateBPM {
            ecgUnitWithBPM = "\(baseECGUnit) • \(Int(bpm)) BPM"
        } else {
            ecgUnitWithBPM = baseECGUnit
        }
        let ecgMetric = Metric(
            title: "Latest ECG",
            value: ecgValue,
            unit: ecgUnitWithBPM,
            icon: "waveform.path.ecg",
            color: .red,
            date: ecgData.first?.date
        )
        
        let metrics = [
            heartRateMetric,
            bloodPressureMetric,
            oxygenMetric,
            temperatureMetric,
            respiratoryRateMetric,
            hrvMetric,
            ecgMetric
        ]
        
        // Debug final metric values
        print("=== Final Metric Values ===")
        for metric in metrics {
            print("\(metric.title): \(metric.value) \(metric.unit)")
        }
        
        return metrics
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
        
        // Check current authorization status for all types
        let allTypes: [HKObjectType] = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .bodyTemperature)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        ]
        
        print("Current authorization status:")
        for type in allTypes {
            let status = healthStore.authorizationStatus(for: type)
            print("  \(type.identifier): \(status.rawValue)")
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
        // Add Apple Sleeping Wrist Temperature (delta) if available
        if let wristDelta = HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
            typesToRead.insert(wristDelta)
        }
        
        // Ensure body temperature is always requested
        if let bodyTemperatureType = HKObjectType.quantityType(forIdentifier: .bodyTemperature) {
            typesToRead.insert(bodyTemperatureType)
        }
        
        print("Requesting authorization for temperature types:")
        for type in typesToRead {
            if type.identifier.contains("temperature") || type.identifier.contains("Temperature") {
                print("  - \(type.identifier)")
            }
        }
        
        // Check current authorization status for temperature types
        let temperatureTypes = [
            HKObjectType.quantityType(forIdentifier: .bodyTemperature),
            HKObjectType.quantityType(forIdentifier: .basalBodyTemperature),
            HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)
        ].compactMap { $0 }
        
        for type in temperatureTypes {
            let status = healthStore.authorizationStatus(for: type)
            print("Current authorization status for \(type.identifier): \(status.rawValue)")
        }
        
        print("Requesting authorization for \(typesToRead.count) health data types")
        print("Authorization dialog should appear now...")
        
        // Request authorization
        print("Requesting HealthKit authorization...")
        authorizationAttempted = true
        
        // Force authorization with explicit types - try both read and write permissions
        let explicitTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .bodyTemperature)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        ]
        
        print("Requesting authorization for explicit types: \(explicitTypes.count)")
        
        // Use the working version - only request read permissions
        healthStore.requestAuthorization(toShare: nil, read: explicitTypes) { success, error in
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
                    // Even if authorization fails, allow the app to continue
                    print("Continuing without HealthKit authorization")
                    isAuthorized = true
                    fetchLatestVitalSigns()
                }
            }
        }
    }
    
    private func fetchLatestVitalSigns() {
        print("=== fetchLatestVitalSigns() called ===")
        print("isAuthorized: \(isAuthorized)")
        
        guard isAuthorized else { 
            print("Not authorized, returning early")
            return 
        }
        
        print("Starting to fetch latest vital signs...")
        
        // Use a background queue for data fetching
        DispatchQueue.global(qos: .userInitiated).async {
            print("Fetching heart rate...")
            self.fetchHeartRate()
            
            print("Fetching blood pressure...")
            self.fetchBloodPressure()
            
            print("Fetching oxygen saturation...")
            self.fetchOxygenSaturation()
            
            print("Fetching body temperature...")
            self.fetchBodyTemperature()
            
            print("Fetching respiratory rate...")
            self.fetchRespiratoryRate()
            
            print("Fetching heart rate variability...")
            self.fetchHeartRateVariability()
            
            print("Fetching ECG data...")
            self.fetchECGData()
            
            print("All fetch operations initiated")
        }
    }
    
    private func fetchHeartRate() {
        print("fetchHeartRate() called")
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { 
            print("Heart rate type not available")
            return 
        }
        
        // Fetch the most recent available sample (no 24h restriction)
        let predicate: NSPredicate? = nil
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            DispatchQueue.main.async {
                if let sample = samples?.first as? HKQuantitySample {
                    let value = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    print("Heart rate fetched: \(value) BPM")
                    self.heartRate = HealthData(value: value, date: sample.endDate)
                } else {
                    print("No heart rate data found or error: \(error?.localizedDescription ?? "none")")
                }
            }
        }
        healthStore.execute(query)
    }

    private func fetchBloodPressure() {
        print("=== fetchBloodPressure() called ===")
        
        guard let bloodPressureType = HKObjectType.correlationType(forIdentifier: .bloodPressure),
              let systolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic) else { 
            print("Blood pressure types not available")
            return 
        }
        
        print("Blood pressure types available:")
        print("  - Blood pressure correlation: \(bloodPressureType)")
        print("  - Systolic type: \(systolicType)")
        print("  - Diastolic type: \(diastolicType)")
        
        // Use nil predicate to get most recent data regardless of time
        let predicate: NSPredicate? = nil
        
        print("Querying blood pressure samples...")
        let query = HKCorrelationQuery(
            type: bloodPressureType,
            predicate: predicate,
            samplePredicates: nil
        ) { [self] _, correlations, error in
            print("Blood pressure query completed - correlations count: \(correlations?.count ?? 0)")
            
            DispatchQueue.main.async {
                if let correlation = correlations?.first {
                    let systolicSamples = correlation.objects(for: systolicType)
                    let diastolicSamples = correlation.objects(for: diastolicType)
                    
                    print("Systolic samples: \(systolicSamples.count), Diastolic samples: \(diastolicSamples.count)")
                    
                    if let systolicSample = systolicSamples.first as? HKQuantitySample,
                       let diastolicSample = diastolicSamples.first as? HKQuantitySample {
                        let systolic = systolicSample.quantity.doubleValue(for: HKUnit.millimeterOfMercury())
                        let diastolic = diastolicSample.quantity.doubleValue(for: HKUnit.millimeterOfMercury())
                        
                        print("Blood pressure fetched: \(Int(systolic))/\(Int(diastolic)) mmHg")
                        
                        self.bloodPressure = BloodPressureData(
                            systolic: systolic,
                            diastolic: diastolic,
                            date: correlation.endDate
                        )
                    } else {
                        print("Could not extract systolic/diastolic values from correlation")
                    }
                } else if let error = error {
                    print("Error fetching blood pressure: \(error.localizedDescription)")
                } else {
                    print("No blood pressure data found")
                }
            }
        }
        healthStore.execute(query)
    }
    
    private func fetchOxygenSaturation() {
        print("=== fetchOxygenSaturation() called ===")
        
        guard let oxygenType = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) else { 
            print("Oxygen saturation type not available")
            return 
        }
        
        print("Oxygen saturation type available: \(oxygenType)")
        
        // Use nil predicate to get most recent data regardless of time
        let predicate: NSPredicate? = nil
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        print("Querying oxygen saturation samples...")
        let query = HKSampleQuery(sampleType: oxygenType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            print("Oxygen saturation query completed - samples count: \(samples?.count ?? 0)")
            
            DispatchQueue.main.async {
                if let sample = samples?.first as? HKQuantitySample {
                    let value = sample.quantity.doubleValue(for: HKUnit.percent())
                    print("Oxygen saturation fetched: \(Int(value * 100))%")
                    self.oxygenSaturation = HealthData(value: value * 100, date: sample.endDate)
                } else if let error = error {
                    print("Error fetching oxygen saturation: \(error.localizedDescription)")
                } else {
                    print("No oxygen saturation data found")
                }
            }
        }
        healthStore.execute(query)
    }
    
    private func fetchBodyTemperature() {
        print("=== fetchBodyTemperature() called ===")
        // Try both body temperature and basal body temperature
        let bodyTempType = HKObjectType.quantityType(forIdentifier: .bodyTemperature)
        let basalTempType = HKObjectType.quantityType(forIdentifier: .basalBodyTemperature)
        let wristDeltaType = HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)
        
        print("Temperature types available:")
        print("  - Body temperature: \(bodyTempType != nil)")
        print("  - Basal temperature: \(basalTempType != nil)")
        print("  - Wrist temperature: \(wristDeltaType != nil)")
        
        // Use nil predicate to get most recent data regardless of time
        let predicate: NSPredicate? = nil
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        // Function to handle temperature data
        let processTemperature = { (samples: [HKSample]?, error: Error?) in
            DispatchQueue.main.async {
                if let sample = samples?.first as? HKQuantitySample {
                    let value = sample.quantity.doubleValue(for: self.temperatureHKUnit)
                    print("Temperature fetched: \(String(format: "%.2f", value)) \(self.temperatureUnitSymbol)")
                    self.temperature = HealthData(value: value, date: sample.endDate)
                } else if let error = error {
                    print("Error fetching temperature: \(error.localizedDescription)")
                } else {
                    print("No temperature data found")
                }
            }
        }
        
        // Check authorization status for temperature types
        print("Checking temperature authorization...")
        if let bodyTempType = bodyTempType {
            let authStatus = healthStore.authorizationStatus(for: bodyTempType)
            print("Body temperature authorization status: \(authStatus.rawValue)")
        }
        if let basalTempType = basalTempType {
            let authStatus = healthStore.authorizationStatus(for: basalTempType)
            print("Basal temperature authorization status: \(authStatus.rawValue)")
        }
        if let wristDeltaType = wristDeltaType {
            let authStatus = healthStore.authorizationStatus(for: wristDeltaType)
            print("Wrist temperature authorization status: \(authStatus.rawValue)")
        }
        
        // Try body temperature first
        if let tempType = bodyTempType {
            print("Querying body temperature samples...")
            let query = HKSampleQuery(sampleType: tempType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                print("Body temperature query completed - samples count: \(samples?.count ?? 0)")
                if samples?.isEmpty ?? true, let basalType = basalTempType {
                    // If no body temperature, try basal temperature
                    print("No body temperature samples; attempting basal body temperature")
                    let basalQuery = HKSampleQuery(sampleType: basalType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, basalSamples, basalError in
                        print("Basal temperature query completed - samples count: \(basalSamples?.count ?? 0)")
                        // If basal also empty, try wrist delta before giving up
                        if (basalSamples?.isEmpty ?? true), let wristType = wristDeltaType {
                            print("No basal temperature; attempting Apple Sleeping Wrist Temperature (delta)")
                            let wristQuery = HKSampleQuery(sampleType: wristType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, wristSamples, wristError in
                                print("Wrist temperature query completed - samples count: \(wristSamples?.count ?? 0)")
                                DispatchQueue.main.async {
                                    if let sample = wristSamples?.first as? HKQuantitySample {
                                        let value = sample.quantity.doubleValue(for: self.temperatureHKUnit)
                                        print("Wrist temperature delta fetched: \(String(format: "%.2f", value)) \(self.temperatureUnitSymbol)")
                                        self.temperature = HealthData(value: value, date: sample.endDate)
                                        self.temperatureIsDelta = true
                                    } else if let wristError = wristError {
                                        print("Error fetching wrist temperature: \(wristError.localizedDescription)")
                                    } else {
                                        print("No wrist temperature data found")
                                    }
                                }
                            }
                            self.healthStore.execute(wristQuery)
                        } else {
                            processTemperature(basalSamples, basalError)
                        }
                    }
                    self.healthStore.execute(basalQuery)
                } else if samples?.isEmpty ?? true, let wristType = wristDeltaType {
                    // If still no data, try wrist temperature delta (iOS 17+)
                    print("No basal temperature; attempting Apple Sleeping Wrist Temperature (delta)")
                    let wristQuery = HKSampleQuery(sampleType: wristType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, wristSamples, wristError in
                        print("Wrist temperature query completed - samples count: \(wristSamples?.count ?? 0)")
                        DispatchQueue.main.async {
                            if let sample = wristSamples?.first as? HKQuantitySample {
                                let value = sample.quantity.doubleValue(for: self.temperatureHKUnit)
                                print("Wrist temperature delta fetched: \(String(format: "%.2f", value)) \(self.temperatureUnitSymbol)")
                                self.temperature = HealthData(value: value, date: sample.endDate)
                                self.temperatureIsDelta = true
                            } else if let wristError = wristError {
                                print("Error fetching wrist temperature: \(wristError.localizedDescription)")
                            } else {
                                print("No wrist temperature data found")
                            }
                        }
                    }
                    self.healthStore.execute(wristQuery)
                } else {
                    print("Using body temperature samples")
                    processTemperature(samples, error)
                }
            }
            healthStore.execute(query)
        } else if let basalType = basalTempType {
            // If no body temperature type, try basal temperature directly
            print("Body temperature type unavailable; using basal body temperature type")
            print("Querying basal body temperature samples...")
            let query = HKSampleQuery(sampleType: basalType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                print("Basal temperature query completed - samples count: \(samples?.count ?? 0)")
                processTemperature(samples, error)
            }
            healthStore.execute(query)
        } else if let wristType = wristDeltaType {
            // Fallback: wrist temperature delta only
            print("Using Apple Sleeping Wrist Temperature (delta) as fallback")
            print("Querying wrist temperature samples...")
            let query = HKSampleQuery(sampleType: wristType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, wristSamples, wristError in
                print("Wrist temperature query completed - samples count: \(wristSamples?.count ?? 0)")
                DispatchQueue.main.async {
                    if let sample = wristSamples?.first as? HKQuantitySample {
                        let value = sample.quantity.doubleValue(for: self.temperatureHKUnit)
                        print("Wrist temperature delta fetched: \(String(format: "%.2f", value)) \(self.temperatureUnitSymbol)")
                        self.temperature = HealthData(value: value, date: sample.endDate)
                        self.temperatureIsDelta = true
                    } else if let wristError = wristError {
                        print("Error fetching wrist temperature: \(wristError.localizedDescription)")
                    } else {
                        print("No wrist temperature data found")
                    }
                }
            }
            self.healthStore.execute(query)
        }
    }

    // MARK: - Temperature Unit Helpers
    private var temperatureHKUnit: HKUnit {
        (Locale.current.measurementSystem == .metric) ? HKUnit.degreeCelsius() : HKUnit.degreeFahrenheit()
    }
    
    private var temperatureUnitSymbol: String {
        (Locale.current.measurementSystem == .metric) ? "°C" : "°F"
    }
    
    private func fetchRespiratoryRate() {
        print("=== fetchRespiratoryRate() called ===")
        
        guard let respiratoryType = HKObjectType.quantityType(forIdentifier: .respiratoryRate) else { 
            print("Respiratory rate type not available")
            return 
        }
        
        print("Respiratory rate type available: \(respiratoryType)")
        
        // Use nil predicate to get most recent data regardless of time
        let predicate: NSPredicate? = nil
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        print("Querying respiratory rate samples...")
        let query = HKSampleQuery(sampleType: respiratoryType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            print("Respiratory rate query completed - samples count: \(samples?.count ?? 0)")
            
            DispatchQueue.main.async {
                if let sample = samples?.first as? HKQuantitySample {
                    let value = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    print("Respiratory rate fetched: \(String(format: "%.1f", value)) breaths/min")
                    self.respiratoryRate = HealthData(value: value, date: sample.endDate)
                } else if let error = error {
                    print("Error fetching respiratory rate: \(error.localizedDescription)")
                } else {
                    print("No respiratory rate data found")
                }
            }
        }
        healthStore.execute(query)
    }
    
    private func fetchHeartRateVariability() {
        print("=== fetchHeartRateVariability() called ===")
        
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { 
            print("Heart rate variability type not available")
            return 
        }
        
        print("Heart rate variability type available: \(hrvType)")
        
        // Use nil predicate to get most recent data regardless of time
        let predicate: NSPredicate? = nil
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        print("Querying heart rate variability samples...")
        let query = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            print("Heart rate variability query completed - samples count: \(samples?.count ?? 0)")
            
            DispatchQueue.main.async {
                if let sample = samples?.first as? HKQuantitySample {
                    let value = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                    print("Heart rate variability fetched: \(String(format: "%.1f", value)) ms")
                    self.heartRateVariability = HealthData(value: value, date: sample.endDate)
                } else if let error = error {
                    print("Error fetching heart rate variability: \(error.localizedDescription)")
                } else {
                    print("No heart rate variability data found")
                }
            }
        }
            healthStore.execute(query)
    }
    
    private func fetchECGData() {
        print("fetchECGData() called")
        
        // Check if ECG is available on this device
        if !HKHealthStore.isHealthDataAvailable() {
            print("HealthKit not available - cannot fetch ECG")
            return
        }
        
        let ecgType = HKObjectType.electrocardiogramType()
        print("ECG type available: \(ecgType)")
        
        // Use nil predicate to get most recent data regardless of time
        let predicate: NSPredicate? = nil
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: ecgType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            print("ECG query completed - samples count: \(samples?.count ?? 0)")
            if let error = error {
                print("ECG query error: \(error.localizedDescription)")
                return
            }
            
            guard let ecg = samples?.first as? HKElectrocardiogram else { 
                print("No ECG data found")
                DispatchQueue.main.async {
                    self.ecgData = []
                }
                return 
            }
            
            print("ECG found: \(ecg)")
            print("ECG start date: \(ecg.startDate)")
            print("ECG end date: \(ecg.endDate)")
            
            // Aggregate voltage measurements to compute peak absolute amplitude (in mV)
            var peakMillivolts: Double = 0
            var peakTimestamp: Date = ecg.startDate

            let voltageQuery = HKElectrocardiogramQuery(ecg) { (query, result) in
                switch result {
                case .measurement(let measurement):
                    if let quantity = measurement.quantity(for: .appleWatchSimilarToLeadI) {
                        let volts = quantity.doubleValue(for: HKUnit.volt())
                        let millivolts = volts * 1000.0
                        let absMillivolts = abs(millivolts)
                        if absMillivolts > peakMillivolts {
                            peakMillivolts = absMillivolts
                            peakTimestamp = ecg.startDate.addingTimeInterval(measurement.timeSinceSampleStart)
                        }
                    }
                case .done:
                    // Average heart rate is available as a property on HKElectrocardiogram (iOS 14+)
                    let bpmUnit = HKUnit.count().unitDivided(by: .minute())
                    let avg = ecg.averageHeartRate?.doubleValue(for: bpmUnit)
                    print("ECG query completed; peak amplitude: \(peakMillivolts) mV, avg BPM: \(avg?.description ?? "n/a")")
                    DispatchQueue.main.async {
                        self.ecgData = [ECGReading(value: peakMillivolts, date: peakTimestamp)]
                        self.ecgAverageHeartRateBPM = avg
                    }
                    self.healthStore.stop(query)
                case .error(let error):
                    print("Error fetching ECG data: \(error.localizedDescription)")
                @unknown default:
                    break
                }
            }
            
            print("Executing ECG voltage query")
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

