import SwiftUI
import HealthKit
import UIKit
import CoreData
import Charts

struct HealthMetricsView: View {
    @StateObject private var viewModel = HealthMetricsViewModel()
    @State private var isAuthorized = false
    // Moved add/trends actions to TabView and floating + in ContentView
    @State private var selectedMetric = "Heart Rate"
    @State private var isLoadingTrends = false
    @State private var trendData: [String: [HealthReading]] = [:]
    @State private var trendAnalysis: [String: TrendAnalysis] = [:]
    
    // Add test form states
    @State private var currentStep = 1
    @State private var selectedTestType = ""
    @State private var testValues: [String: String] = [:]
    @State private var testDate = Date()

    @State private var testResults: [BloodTest] = []
    @State private var showManualTemperatureEntry = false
    @State private var authorizationAttempted = false
    
    // Apple Intelligence integration
    @State private var showInsights = false
    
    // MARK: - Performance Optimization
    @State private var isDataLoaded = false
    @State private var refreshTimer: Timer?
    
    private let healthStore = HKHealthStore()
    
    // MARK: - Initialization
    
    init() {
        // Initialize insights manager with default values
        // This will be properly initialized when the view appears
    }
    
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
                    #if DEBUG
                    print("\n=== Manual Refresh Triggered ===")
                    print("Current authorization status: \(isAuthorized)")
                    print("HealthKit available: \(HKHealthStore.isHealthDataAvailable())")
                    #endif
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showManualTemperatureEntry) {
            ManualTemperatureEntryView(isPresented: $showManualTemperatureEntry) { temperature in
                // Save the manually entered temperature
                self.temperature = HealthData(value: temperature, date: Date())
            }
        }
        .sheet(item: $selectedMetricInfo) { metric in
            NavigationView {
                MetricDetailView(metric: metric, onDidSaveReading: { fetchLatestVitalSigns() })
            }
        }
        .onAppear {
            // Remove automatic authorization - only trigger on user action
            #if DEBUG
            print("=== App Launch - Ready for HealthKit Authorization ===")
            #endif
            // Start background refresh timer for better performance
            startBackgroundRefresh()
        }
        .onDisappear {
            // Clean up timer when view disappears
            stopBackgroundRefresh()
        }
    }
    
    // MARK: - Performance Optimization
    
    /// Starts background refresh timer for health data
    private func startBackgroundRefresh() {
        guard refreshTimer == nil else { return }
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { _ in
            // Refresh health data every 5 minutes in background
            Task {
                await refreshHealthDataInBackground()
            }
        }
    }
    
    /// Stops background refresh timer
    private func stopBackgroundRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    /// Refreshes health data in background for better performance
    private func refreshHealthDataInBackground() async {
        guard isAuthorized else { return }
        
        // Use background task for better performance
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.fetchHeartRateData()
            }
            group.addTask {
                await self.fetchBloodPressureData()
            }
            group.addTask {
                await self.fetchOxygenSaturationData()
            }
            group.addTask {
                await self.fetchTemperatureData()
            }
            group.addTask {
                await self.fetchRespiratoryRateData()
            }
            group.addTask {
                await self.fetchHeartRateVariabilityData()
            }
        }
        
        // Update UI on main thread
        await MainActor.run {
            isDataLoaded = true
        }
    }
    
    // MARK: - Health Data Fetching Methods
    
    /// Fetches heart rate data from HealthKit
    private func fetchHeartRateData() async {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            
            let value = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            DispatchQueue.main.async {
                self.heartRate = HealthData(value: value, date: sample.endDate)
            }
        }
        
        healthStore.execute(query)
    }
    
    /// Fetches blood pressure data from HealthKit
    private func fetchBloodPressureData() async {
        guard let systolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic) else { return }
        
        let systolicQuery = HKSampleQuery(sampleType: systolicType, predicate: nil, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            
            let systolicValue = sample.quantity.doubleValue(for: HKUnit.millimeterOfMercury())
            DispatchQueue.main.async {
                self.bloodPressure.systolic = systolicValue
                self.bloodPressure.date = sample.endDate
            }
        }
        
        let diastolicQuery = HKSampleQuery(sampleType: diastolicType, predicate: nil, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            
            let diastolicValue = sample.quantity.doubleValue(for: HKUnit.millimeterOfMercury())
            DispatchQueue.main.async {
                self.bloodPressure.diastolic = diastolicValue
                self.bloodPressure.date = sample.endDate
            }
        }
        
        healthStore.execute(systolicQuery)
        healthStore.execute(diastolicQuery)
    }
    
    /// Fetches oxygen saturation data from HealthKit
    private func fetchOxygenSaturationData() async {
        guard let oxygenType = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) else { return }
        
        let query = HKSampleQuery(sampleType: oxygenType, predicate: nil, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            
            let value = sample.quantity.doubleValue(for: HKUnit.percent())
            DispatchQueue.main.async {
                // Store as percentage (0-100) instead of decimal (0.0-1.0)
                self.oxygenSaturation = HealthData(value: value * 100, date: sample.endDate)
            }
        }
        
        healthStore.execute(query)
    }
    
    /// Fetches temperature data from HealthKit
    private func fetchTemperatureData() async {
        guard let temperatureType = HKObjectType.quantityType(forIdentifier: .bodyTemperature) else { return }
        
        let query = HKSampleQuery(sampleType: temperatureType, predicate: nil, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            
            let value = sample.quantity.doubleValue(for: HKUnit.degreeFahrenheit())
            DispatchQueue.main.async {
                self.temperature = HealthData(value: value, date: sample.endDate)
            }
        }
        
        healthStore.execute(query)
    }
    
    /// Fetches respiratory rate data from HealthKit
    private func fetchRespiratoryRateData() async {
        guard let respiratoryType = HKObjectType.quantityType(forIdentifier: .respiratoryRate) else { return }
        
        let query = HKSampleQuery(sampleType: respiratoryType, predicate: nil, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            
            let value = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            DispatchQueue.main.async {
                self.respiratoryRate = HealthData(value: value, date: sample.endDate)
            }
        }
        
        healthStore.execute(query)
    }
    
    /// Fetches heart rate variability data from HealthKit
    private func fetchHeartRateVariabilityData() async {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }
        
        let query = HKSampleQuery(sampleType: hrvType, predicate: nil, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            
            let value = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
            DispatchQueue.main.async {
                self.heartRateVariability = HealthData(value: value, date: sample.endDate)
            }
        }
        
        healthStore.execute(query)
    }
    
    // Bottom overlay removed in favor of cleaner HIG-compliant layout
    
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
        
        let temperatureValue: String
        let temperatureUnit: String
        let temperatureColor: Color
        
        if let tempValue = temperature.value {
            temperatureValue = String(format: "%.1f", tempValue)
            temperatureUnit = temperatureIsDelta ? "Δ \(temperatureUnitSymbol)" : temperatureUnitSymbol
            temperatureColor = .orange
        } else {
            if !HKHealthStore.isHealthDataAvailable() {
                temperatureValue = "N/A"
                temperatureUnit = "Simulator"
                temperatureColor = .gray
            } else {
                temperatureValue = "Tap to add"
                temperatureUnit = "Manual entry"
                temperatureColor = .blue
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
        if let firstECG = ecgData.first {
            if firstECG.value < 1.0 {
                ecgValue = String(format: "%.0f", firstECG.value * 1000.0) // µV
            } else {
                ecgValue = String(format: "%.1f", firstECG.value) // mV
            }
        } else {
            if !HKHealthStore.isHealthDataAvailable() {
                ecgValue = "N/A"
            } else {
                ecgValue = "--"
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
        return metrics
    }
    
    private func requestHealthKitAuthorization() {
        #if DEBUG
        print("=== HealthKit Authorization Debug ===")
        print("HealthKit available: \(HKHealthStore.isHealthDataAvailable())")
        #endif
        // Check if HealthKit is available
        guard HKHealthStore.isHealthDataAvailable() else {
            #if DEBUG
            print("HealthKit is not available on this device")
            #endif
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
        
        #if DEBUG
        print("Current authorization status:")
        for type in allTypes {
            let status = healthStore.authorizationStatus(for: type)
            print("  \(type.identifier): \(status.rawValue)")
        }
        #endif
        // Request authorization for all health data types the app needs
        let basicTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .bodyTemperature)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.electrocardiogramType()
        ]
        
        #if DEBUG
        print("Requesting authorization for basic types: \(basicTypes.count)")
        print("Authorization dialog should appear now...")
        print("Requesting HealthKit authorization...")
        #endif
        authorizationAttempted = true
        
        // Try multiple authorization attempts with different timing
        var attemptCount = 0
        let maxAttempts = 3
        
        func attemptAuthorization() {
            attemptCount += 1
            #if DEBUG
            print("Authorization attempt \(attemptCount) of \(maxAttempts)")
            #endif
            healthStore.requestAuthorization(toShare: HealthKitManager.typesToShare, read: basicTypes) { success, error in
                DispatchQueue.main.async {
                    #if DEBUG
                    print("Authorization attempt \(attemptCount) result: success=\(success), error=\(error?.localizedDescription ?? "none")")
                    #endif
                    if success {
                        #if DEBUG
                        print("HealthKit authorization successful!")
                        #endif
                        isAuthorized = true
                        fetchLatestVitalSigns()
                    } else {
                        #if DEBUG
                        print("HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")")
                        if let error = error {
                            print("Error details: \(error)")
                        }
                        #endif
                        // Try again if we haven't reached max attempts
                        if attemptCount < maxAttempts {
                            DispatchQueue.main.asyncAfter(deadline: .now() + Double(attemptCount) * 1.0) {
                                #if DEBUG
                                print("Retrying HealthKit authorization...")
                                #endif
                                attemptAuthorization()
                            }
                        } else {
                            #if DEBUG
                            print("All authorization attempts failed. Continuing without HealthKit.")
                            #endif
                            // Even if authorization fails, allow the app to continue
                            isAuthorized = true
                            fetchLatestVitalSigns()
                        }
                    }
                }
            }
        }
        
        // Start the first authorization attempt
        attemptAuthorization()
    }
    
    private func fetchLatestVitalSigns() {
        #if DEBUG
        print("=== fetchLatestVitalSigns() called ===")
        print("isAuthorized: \(isAuthorized)")
        #endif
        guard isAuthorized else {
            #if DEBUG
            print("Not authorized, returning early")
            #endif
            return
        }
        #if DEBUG
        print("Starting to fetch latest vital signs...")
        #endif
        // Use a background queue for data fetching
        DispatchQueue.global(qos: .userInitiated).async {
            #if DEBUG
            print("Fetching heart rate...")
            #endif
            self.fetchHeartRate()
            #if DEBUG
            print("Fetching blood pressure...")
            #endif
            self.fetchBloodPressure()
            #if DEBUG
            print("Fetching oxygen saturation...")
            #endif
            self.fetchOxygenSaturation()
            #if DEBUG
            print("Fetching body temperature...")
            #endif
            self.fetchBodyTemperature()
            #if DEBUG
            print("Fetching respiratory rate...")
            #endif
            self.fetchRespiratoryRate()
            #if DEBUG
            print("Fetching heart rate variability...")
            #endif
            self.fetchHeartRateVariability()
            #if DEBUG
            print("Fetching ECG data...")
            #endif
            self.fetchECGData()
            #if DEBUG
            print("All fetch operations initiated")
            #endif
        }
    }
    
    private func fetchHeartRate() {
        #if DEBUG
        print("fetchHeartRate() called")
        #endif
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            #if DEBUG
            print("Heart rate type not available")
            #endif
            return
        }
        
        // Fetch the most recent available sample (no 24h restriction)
        let predicate: NSPredicate? = nil
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            DispatchQueue.main.async {
                if let sample = samples?.first as? HKQuantitySample {
                    let value = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    #if DEBUG
                    print("Heart rate fetched: \(value) BPM")
                    #endif
                    self.heartRate = HealthData(value: value, date: sample.endDate)
                } else {
                    #if DEBUG
                    print("No heart rate data found or error: \(error?.localizedDescription ?? "none")")
                    #endif
                }
            }
        }
        healthStore.execute(query)
    }

    private func fetchBloodPressure() {
        #if DEBUG
        print("=== fetchBloodPressure() called ===")
        #endif
        guard let bloodPressureType = HKObjectType.correlationType(forIdentifier: .bloodPressure),
              let systolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic) else {
            #if DEBUG
            print("Blood pressure types not available")
            #endif
            return
        }
        #if DEBUG
        print("Blood pressure types available:")
        print("  - Blood pressure correlation: \(bloodPressureType)")
        print("  - Systolic type: \(systolicType)")
        print("  - Diastolic type: \(diastolicType)")
        print("Querying blood pressure samples...")
        #endif
        // Use nil predicate to get most recent data regardless of time
        let predicate: NSPredicate? = nil
        let query = HKCorrelationQuery(
            type: bloodPressureType,
            predicate: predicate,
            samplePredicates: nil
        ) { [self] _, correlations, error in
            #if DEBUG
            print("Blood pressure query completed - correlations count: \(correlations?.count ?? 0)")
            #endif
            // HKCorrelationQuery returns results in undefined order; use most recent by endDate
            let sorted = (correlations ?? []).sorted { $0.endDate > $1.endDate }
            let correlation = sorted.first
            DispatchQueue.main.async {
                if let correlation = correlation {
                    let systolicSamples = correlation.objects(for: systolicType)
                    let diastolicSamples = correlation.objects(for: diastolicType)
                    #if DEBUG
                    print("Systolic samples: \(systolicSamples.count), Diastolic samples: \(diastolicSamples.count)")
                    #endif
                    if let systolicSample = systolicSamples.first as? HKQuantitySample,
                       let diastolicSample = diastolicSamples.first as? HKQuantitySample {
                        let systolic = systolicSample.quantity.doubleValue(for: HKUnit.millimeterOfMercury())
                        let diastolic = diastolicSample.quantity.doubleValue(for: HKUnit.millimeterOfMercury())
                        #if DEBUG
                        print("Blood pressure fetched: \(Int(systolic))/\(Int(diastolic)) mmHg")
                        #endif
                        
                        self.bloodPressure = BloodPressureData(
                            systolic: systolic,
                            diastolic: diastolic,
                            date: correlation.endDate
                        )
                    } else {
                        #if DEBUG
                        print("Could not extract systolic/diastolic values from correlation")
                        #endif
                    }
                } else if let error = error {
                    #if DEBUG
                    print("Error fetching blood pressure: \(error.localizedDescription)")
                    #endif
                } else {
                    #if DEBUG
                    print("No blood pressure data found")
                    #endif
                }
            }
        }
        healthStore.execute(query)
    }
    
    private func fetchOxygenSaturation() {
        #if DEBUG
        print("=== fetchOxygenSaturation() called ===")
        #endif
        guard let oxygenType = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) else {
            #if DEBUG
            print("Oxygen saturation type not available")
            #endif
            return
        }
        #if DEBUG
        print("Oxygen saturation type available: \(oxygenType)")
        print("Querying oxygen saturation samples...")
        #endif
        // Use nil predicate to get most recent data regardless of time
        let predicate: NSPredicate? = nil
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: oxygenType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            #if DEBUG
            print("Oxygen saturation query completed - samples count: \(samples?.count ?? 0)")
            #endif
            DispatchQueue.main.async {
                if let sample = samples?.first as? HKQuantitySample {
                    let value = sample.quantity.doubleValue(for: HKUnit.percent())
                    #if DEBUG
                    print("Oxygen saturation fetched: \(Int(value * 100))%")
                    #endif
                    self.oxygenSaturation = HealthData(value: value * 100, date: sample.endDate)
                } else if let error = error {
                    #if DEBUG
                    print("Error fetching oxygen saturation: \(error.localizedDescription)")
                    #endif
                } else {
                    #if DEBUG
                    print("No oxygen saturation data found")
                    #endif
                }
            }
        }
        healthStore.execute(query)
    }
    
    private func fetchBodyTemperature() {
        #if DEBUG
        print("=== fetchBodyTemperature() called ===")
        #endif
        // Try both body temperature and basal body temperature
        let bodyTempType = HKObjectType.quantityType(forIdentifier: .bodyTemperature)
        let basalTempType = HKObjectType.quantityType(forIdentifier: .basalBodyTemperature)
        let wristDeltaType = HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)
        #if DEBUG
        print("Temperature types available:")
        print("  - Body temperature: \(bodyTempType != nil)")
        print("  - Basal temperature: \(basalTempType != nil)")
        print("  - Wrist temperature: \(wristDeltaType != nil)")
        #endif
        
        // Use nil predicate to get most recent data regardless of time
        let predicate: NSPredicate? = nil
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        // Function to handle temperature data
        let processTemperature = { (samples: [HKSample]?, error: Error?) in
            DispatchQueue.main.async {
                if let sample = samples?.first as? HKQuantitySample {
                    let value = sample.quantity.doubleValue(for: self.temperatureHKUnit)
                    #if DEBUG
                    print("Temperature fetched: \(String(format: "%.2f", value)) \(self.temperatureUnitSymbol)")
                    #endif
                    self.temperature = HealthData(value: value, date: sample.endDate)
                } else if let error = error {
                    #if DEBUG
                    print("Error fetching temperature: \(error.localizedDescription)")
                    #endif
                } else {
                    #if DEBUG
                    print("No temperature data found")
                    #endif
                }
            }
        }
        #if DEBUG
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
        #endif
        // Try body temperature first
        if let tempType = bodyTempType {
            #if DEBUG
            print("Querying body temperature samples...")
            #endif
            let query = HKSampleQuery(sampleType: tempType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                #if DEBUG
                print("Body temperature query completed - samples count: \(samples?.count ?? 0)")
                #endif
                if samples?.isEmpty ?? true, let basalType = basalTempType {
                    #if DEBUG
                    print("No body temperature samples; attempting basal body temperature")
                    #endif
                    let basalQuery = HKSampleQuery(sampleType: basalType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, basalSamples, basalError in
                        #if DEBUG
                        print("Basal temperature query completed - samples count: \(basalSamples?.count ?? 0)")
                        #endif
                        if (basalSamples?.isEmpty ?? true), let wristType = wristDeltaType {
                            #if DEBUG
                            print("No basal temperature; attempting Apple Sleeping Wrist Temperature (delta)")
                            #endif
                            let wristQuery = HKSampleQuery(sampleType: wristType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, wristSamples, wristError in
                                #if DEBUG
                                print("Wrist temperature query completed - samples count: \(wristSamples?.count ?? 0)")
                                #endif
                                DispatchQueue.main.async {
                                    if let sample = wristSamples?.first as? HKQuantitySample {
                                        let value = sample.quantity.doubleValue(for: self.temperatureHKUnit)
                                        #if DEBUG
                                        print("Wrist temperature delta fetched: \(String(format: "%.2f", value)) \(self.temperatureUnitSymbol)")
                                        #endif
                                        self.temperature = HealthData(value: value, date: sample.endDate)
                                        self.temperatureIsDelta = true
                                    } else if let wristError = wristError, !wristError.localizedDescription.lowercased().contains("not determined") {
                                        #if DEBUG
                                        print("Error fetching wrist temperature: \(wristError.localizedDescription)")
                                        #endif
                                    } else {
                                        #if DEBUG
                                        print("No wrist temperature data found")
                                        #endif
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
                    #if DEBUG
                    print("No basal temperature; attempting Apple Sleeping Wrist Temperature (delta)")
                    #endif
                    let wristQuery = HKSampleQuery(sampleType: wristType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, wristSamples, wristError in
                        #if DEBUG
                        print("Wrist temperature query completed - samples count: \(wristSamples?.count ?? 0)")
                        #endif
                        DispatchQueue.main.async {
                            if let sample = wristSamples?.first as? HKQuantitySample {
                                let value = sample.quantity.doubleValue(for: self.temperatureHKUnit)
                                #if DEBUG
                                print("Wrist temperature delta fetched: \(String(format: "%.2f", value)) \(self.temperatureUnitSymbol)")
                                #endif
                                self.temperature = HealthData(value: value, date: sample.endDate)
                                self.temperatureIsDelta = true
                            } else if let wristError = wristError, !wristError.localizedDescription.lowercased().contains("not determined") {
                                #if DEBUG
                                print("Error fetching wrist temperature: \(wristError.localizedDescription)")
                                #endif
                            } else {
                                #if DEBUG
                                print("No wrist temperature data found")
                                #endif
                            }
                        }
                    }
                    self.healthStore.execute(wristQuery)
                } else {
                    #if DEBUG
                    print("Using body temperature samples")
                    #endif
                    processTemperature(samples, error)
                }
            }
            healthStore.execute(query)
        } else if let basalType = basalTempType {
            #if DEBUG
            print("Body temperature type unavailable; using basal body temperature type")
            print("Querying basal body temperature samples...")
            #endif
            let query = HKSampleQuery(sampleType: basalType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                #if DEBUG
                print("Basal temperature query completed - samples count: \(samples?.count ?? 0)")
                #endif
                processTemperature(samples, error)
            }
            healthStore.execute(query)
        } else if let wristType = wristDeltaType {
            #if DEBUG
            print("Using Apple Sleeping Wrist Temperature (delta) as fallback")
            print("Querying wrist temperature samples...")
            #endif
            let query = HKSampleQuery(sampleType: wristType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, wristSamples, wristError in
                #if DEBUG
                print("Wrist temperature query completed - samples count: \(wristSamples?.count ?? 0)")
                #endif
                DispatchQueue.main.async {
                    if let sample = wristSamples?.first as? HKQuantitySample {
                        let value = sample.quantity.doubleValue(for: self.temperatureHKUnit)
                        #if DEBUG
                        print("Wrist temperature delta fetched: \(String(format: "%.2f", value)) \(self.temperatureUnitSymbol)")
                        #endif
                        self.temperature = HealthData(value: value, date: sample.endDate)
                        self.temperatureIsDelta = true
                    } else if let wristError = wristError, !wristError.localizedDescription.lowercased().contains("not determined") {
                        #if DEBUG
                        print("Error fetching wrist temperature: \(wristError.localizedDescription)")
                        #endif
                    } else {
                        #if DEBUG
                        print("No wrist temperature data found")
                        #endif
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
        #if DEBUG
        print("=== fetchRespiratoryRate() called ===")
        #endif
        guard let respiratoryType = HKObjectType.quantityType(forIdentifier: .respiratoryRate) else {
            #if DEBUG
            print("Respiratory rate type not available")
            #endif
            return
        }
        #if DEBUG
        print("Respiratory rate type available: \(respiratoryType)")
        print("Querying respiratory rate samples...")
        #endif
        let predicate: NSPredicate? = nil
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: respiratoryType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            #if DEBUG
            print("Respiratory rate query completed - samples count: \(samples?.count ?? 0)")
            #endif
            DispatchQueue.main.async {
                if let sample = samples?.first as? HKQuantitySample {
                    let value = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    #if DEBUG
                    print("Respiratory rate fetched: \(String(format: "%.1f", value)) breaths/min")
                    #endif
                    self.respiratoryRate = HealthData(value: value, date: sample.endDate)
                } else if let error = error {
                    #if DEBUG
                    print("Error fetching respiratory rate: \(error.localizedDescription)")
                    #endif
                } else {
                    #if DEBUG
                    print("No respiratory rate data found")
                    #endif
                }
            }
        }
        healthStore.execute(query)
    }
    
    private func fetchHeartRateVariability() {
        #if DEBUG
        print("=== fetchHeartRateVariability() called ===")
        #endif
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            #if DEBUG
            print("Heart rate variability type not available")
            #endif
            return
        }
        #if DEBUG
        print("Heart rate variability type available: \(hrvType)")
        print("Querying heart rate variability samples...")
        #endif
        let predicate: NSPredicate? = nil
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            #if DEBUG
            print("Heart rate variability query completed - samples count: \(samples?.count ?? 0)")
            #endif
            
            DispatchQueue.main.async {
                if let sample = samples?.first as? HKQuantitySample {
                    let value = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                    #if DEBUG
                    print("Heart rate variability fetched: \(String(format: "%.1f", value)) ms")
                    #endif
                    self.heartRateVariability = HealthData(value: value, date: sample.endDate)
                } else if let error = error {
                    #if DEBUG
                    print("Error fetching heart rate variability: \(error.localizedDescription)")
                    #endif
                } else {
                    #if DEBUG
                    print("No heart rate variability data found")
                    #endif
                }
            }
        }
            healthStore.execute(query)
    }
    
    private func fetchECGData() {
        #if DEBUG
        print("fetchECGData() called")
        #endif
        if !HKHealthStore.isHealthDataAvailable() {
            #if DEBUG
            print("HealthKit not available - cannot fetch ECG")
            #endif
            return
        }
        let ecgType = HKObjectType.electrocardiogramType()
        #if DEBUG
        print("ECG type available: \(ecgType)")
        #endif
        let predicate: NSPredicate? = nil
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: ecgType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            #if DEBUG
            print("ECG query completed - samples count: \(samples?.count ?? 0)")
            #endif
            if let error = error {
                #if DEBUG
                print("ECG query error: \(error.localizedDescription)")
                #endif
                return
            }
            guard let ecg = samples?.first as? HKElectrocardiogram else {
                #if DEBUG
                print("No ECG data found")
                #endif
                DispatchQueue.main.async {
                    self.ecgData = []
                }
                return
            }
            #if DEBUG
            print("ECG found: \(ecg)")
            print("ECG start date: \(ecg.startDate)")
            print("ECG end date: \(ecg.endDate)")
            #endif
            
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
                    let bpmUnit = HKUnit.count().unitDivided(by: .minute())
                    let avg = ecg.averageHeartRate?.doubleValue(for: bpmUnit)
                    #if DEBUG
                    print("ECG query completed; peak amplitude: \(peakMillivolts) mV, avg BPM: \(avg?.description ?? "n/a")")
                    #endif
                    DispatchQueue.main.async {
                        self.ecgData = [ECGReading(value: peakMillivolts, date: peakTimestamp)]
                        self.ecgAverageHeartRateBPM = avg
                    }
                    self.healthStore.stop(query)
                case .error(let error):
                    #if DEBUG
                    print("Error fetching ECG data: \(error.localizedDescription)")
                    #endif
                @unknown default:
                    break
                }
            }
            #if DEBUG
            print("Executing ECG voltage query")
            #endif
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
    @Published var showingSettings = false
}

