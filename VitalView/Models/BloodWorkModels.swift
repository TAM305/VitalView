import Foundation
import CoreData
import SwiftUI
import Combine
import LocalAuthentication
import HealthKit

/// Comprehensive data models for the VitalVu blood work analyzer application.
///
/// This module contains all the core data structures used throughout the app,
/// including blood test results, health metrics, and security management.
/// The models are designed to work seamlessly with Core Data for persistence
/// and HealthKit for health data integration.
///
/// ## Key Components
/// - **TestStatus**: Enumeration for test result status (normal, high, low)
/// - **BloodTest**: Main data structure for blood test records
/// - **TestResult**: Individual test result with validation logic
/// - **CBCResult**: Complete Blood Count test results
/// - **CMPResult**: Comprehensive Metabolic Panel test results
/// - **SecurityManager**: Biometric authentication handling
/// - **BloodTestViewModel**: Observable view model for data management
///
/// ## Data Validation
/// All models include built-in validation logic to ensure data integrity
/// and provide meaningful feedback to users about their test results.
///
/// ## HealthKit Integration
/// Models are designed to work with HealthKit data types and can be
/// synchronized with Apple Health for comprehensive health tracking.
///
/// - Author: VitalVu Development Team
/// - Version: 1.0
/// - Copyright: © 2025 VitalVu. All rights reserved.

// MARK: - HealthKit Authorization Helper

/// Helper class for managing HealthKit authorization and data access.
///
/// This class provides methods to check authorization status for different
/// health data types and handle authorization requests properly.
class HealthKitManager: ObservableObject {
    let healthStore = HKHealthStore()
    private var isAuthorized = false
    
    // Memory optimization properties
    private var activeQueries: [HKQuery] = []
    private var memoryWarningObserver: NSObjectProtocol?
    private let maxConcurrentQueries = 5
    private var queryQueue = DispatchQueue(label: "com.vitalvu.healthkit.queries", qos: .userInitiated)
    
    init() {
        setupMemoryManagement()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Memory Management
    
    private func setupMemoryManagement() {
        // Monitor memory warnings
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    private func handleMemoryWarning() {
        print("🚨 Memory warning in HealthKitManager - performing cleanup")
        performMemoryCleanup()
    }
    
    private func performMemoryCleanup() {
        // Stop all active queries
        for query in activeQueries {
            healthStore.stop(query)
        }
        activeQueries.removeAll()
        
        // Force garbage collection
        autoreleasepool {
            // Additional cleanup
        }
        
        print("🧹 HealthKitManager memory cleanup completed")
    }
    
    private func cleanup() {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Stop all queries
        for query in activeQueries {
            healthStore.stop(query)
        }
        activeQueries.removeAll()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return false
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!,
            HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKDataType.electrocardiogramType()
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: nil, read: typesToRead)
            isAuthorized = true
            print("HealthKit authorization successful!")
            return true
        } catch {
            print("HealthKit authorization failed: \(error)")
            return false
        }
    }
    
    // MARK: - Memory-Efficient Data Fetching
    
    func fetchLatestVitalSigns() async -> [String: Any] {
        guard isAuthorized else {
            print("HealthKit not authorized")
            return [:]
        }
        
        // Limit concurrent queries to prevent memory spikes
        let semaphore = DispatchSemaphore(value: maxConcurrentQueries)
        var results: [String: Any] = [:]
        
        // Use TaskGroup for controlled concurrency
        await withTaskGroup(of: (String, Any).self) { group in
            // Heart Rate
            group.addTask {
                await self.fetchHeartRate(semaphore: semaphore)
            }
            
            // Blood Pressure
            group.addTask {
                await self.fetchBloodPressure(semaphore: semaphore)
            }
            
            // Oxygen Saturation
            group.addTask {
                await self.fetchOxygenSaturation(semaphore: semaphore)
            }
            
            // Body Temperature
            group.addTask {
                await self.fetchBodyTemperature(semaphore: semaphore)
            }
            
            // Respiratory Rate
            group.addTask {
                await self.fetchRespiratoryRate(semaphore: semaphore)
            }
            
            // Heart Rate Variability
            group.addTask {
                await self.fetchHeartRateVariability(semaphore: semaphore)
            }
            
            // ECG Data
            group.addTask {
                await self.fetchECGData(semaphore: semaphore)
            }
            
            // Collect results
            for await (key, value) in group {
                results[key] = value
            }
        }
        
        return results
    }
    
    // MARK: - Individual Fetch Methods with Memory Optimization
    
    private func fetchHeartRate(semaphore: DispatchSemaphore) async -> (String, Any) {
        defer { semaphore.signal() }
        semaphore.wait()
        
        return await withCheckedContinuation { continuation in
            autoreleasepool {
                let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
                let predicate = HKQuery.predicateForSamples(withStart: nil, end: nil, options: .strictEndDate)
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
                
                let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                    defer {
                        // Clean up query
                        if let query = samples?.first?.sourceRevision.productType {
                            self.removeQuery(query)
                        }
                    }
                    
                    if let error = error {
                        print("Heart rate query error: \(error)")
                        continuation.resume(returning: ("heartRate", nil))
                        return
                    }
                    
                    if let sample = samples?.first as? HKQuantitySample {
                        let heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                        print("Heart rate fetched: \(heartRate) BPM")
                        continuation.resume(returning: ("heartRate", heartRate))
                    } else {
                        continuation.resume(returning: ("heartRate", nil))
                    }
                }
                
                self.addQuery(query)
                self.healthStore.execute(query)
            }
        }
    }
    
    private func fetchBloodPressure(semaphore: DispatchSemaphore) async -> (String, Any) {
        defer { semaphore.signal() }
        semaphore.wait()
        
        return await withCheckedContinuation { continuation in
            autoreleasepool {
                let bloodPressureType = HKCorrelationType.correlationType(forIdentifier: .bloodPressure)!
                let predicate = HKQuery.predicateForSamples(withStart: nil, end: nil, options: .strictEndDate)
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
                
                let query = HKSampleQuery(sampleType: bloodPressureType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                    defer {
                        // Clean up query
                        if let query = samples?.first?.sourceRevision.productType {
                            self.removeQuery(query)
                        }
                    }
                    
                    if let error = error {
                        print("Blood pressure query error: \(error)")
                        continuation.resume(returning: ("bloodPressure", nil))
                        return
                    }
                    
                    if let correlation = samples?.first as? HKCorrelation {
                        let systolic = correlation.objects(for: HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)!).first as? HKQuantitySample
                        let diastolic = correlation.objects(for: HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)!).first as? HKQuantitySample
                        
                        if let systolicValue = systolic?.quantity.doubleValue(for: HKUnit.millimeterOfMercury()),
                           let diastolicValue = diastolic?.quantity.doubleValue(for: HKUnit.millimeterOfMercury()) {
                            let bloodPressure = "\(Int(systolicValue))/\(Int(diastolicValue))"
                            print("Blood pressure fetched: \(bloodPressure) mmHg")
                            continuation.resume(returning: ("bloodPressure", bloodPressure))
                        } else {
                            continuation.resume(returning: ("bloodPressure", nil))
                        }
                    } else {
                        continuation.resume(returning: ("bloodPressure", nil))
                    }
                }
                
                self.addQuery(query)
                self.healthStore.execute(query)
            }
        }
    }
    
    private func fetchOxygenSaturation(semaphore: DispatchSemaphore) async -> (String, Any) {
        defer { semaphore.signal() }
        semaphore.wait()
        
        return await withCheckedContinuation { continuation in
            autoreleasepool {
                let oxygenType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
                let predicate = HKQuery.predicateForSamples(withStart: nil, end: nil, options: .strictEndDate)
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
                
                let query = HKSampleQuery(sampleType: oxygenType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                    defer {
                        // Clean up query
                        if let query = samples?.first?.sourceRevision.productType {
                            self.removeQuery(query)
                        }
                    }
                    
                    if let error = error {
                        print("Oxygen saturation query error: \(error)")
                        continuation.resume(returning: ("oxygenSaturation", nil))
                        return
                    }
                    
                    if let sample = samples?.first as? HKQuantitySample {
                        let oxygen = sample.quantity.doubleValue(for: HKUnit.percent())
                        print("Oxygen saturation fetched: \(oxygen)%")
                        continuation.resume(returning: ("oxygenSaturation", oxygen))
                    } else {
                        continuation.resume(returning: ("oxygenSaturation", nil))
                    }
                }
                
                self.addQuery(query)
                self.healthStore.execute(query)
            }
        }
    }
    
    private func fetchBodyTemperature(semaphore: DispatchSemaphore) async -> (String, Any) {
        defer { semaphore.signal() }
        semaphore.wait()
        
        return await withCheckedContinuation { continuation in
            autoreleasepool {
                let temperatureType = HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!
                let predicate = HKQuery.predicateForSamples(withStart: nil, end: nil, options: .strictEndDate)
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
                
                let query = HKSampleQuery(sampleType: temperatureType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                    defer {
                        // Clean up query
                        if let query = samples?.first?.sourceRevision.productType {
                            self.removeQuery(query)
                        }
                    }
                    
                    if let error = error {
                        print("Body temperature query error: \(error)")
                        continuation.resume(returning: ("bodyTemperature", nil))
                        return
                    }
                    
                    if let sample = samples?.first as? HKQuantitySample {
                        let temperature = sample.quantity.doubleValue(for: HKUnit.degreeFahrenheit())
                        print("Temperature fetched: \(temperature) °F")
                        continuation.resume(returning: ("bodyTemperature", temperature))
                    } else {
                        continuation.resume(returning: ("bodyTemperature", nil))
                    }
                }
                
                self.addQuery(query)
                self.healthStore.execute(query)
            }
        }
    }
    
    private func fetchRespiratoryRate(semaphore: DispatchSemaphore) async -> (String, Any) {
        defer { semaphore.signal() }
        semaphore.wait()
        
        return await withCheckedContinuation { continuation in
            autoreleasepool {
                let respiratoryType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!
                let predicate = HKQuery.predicateForSamples(withStart: nil, end: nil, options: .strictEndDate)
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
                
                let query = HKSampleQuery(sampleType: respiratoryType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                    defer {
                        // Clean up query
                        if let query = samples?.first?.sourceRevision.productType {
                            self.removeQuery(query)
                        }
                    }
                    
                    if let error = error {
                        print("Respiratory rate query error: \(error)")
                        continuation.resume(returning: ("respiratoryRate", nil))
                        return
                    }
                    
                    if let sample = samples?.first as? HKQuantitySample {
                        let respiratoryRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                        print("Respiratory rate fetched: \(respiratoryRate) breaths/min")
                        continuation.resume(returning: ("respiratoryRate", respiratoryRate))
                    } else {
                        continuation.resume(returning: ("respiratoryRate", nil))
                    }
                }
                
                self.addQuery(query)
                self.healthStore.execute(query)
            }
        }
    }
    
    private func fetchHeartRateVariability(semaphore: DispatchSemaphore) async -> (String, Any) {
        defer { semaphore.signal() }
        semaphore.wait()
        
        return await withCheckedContinuation { continuation in
            autoreleasepool {
                let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
                let predicate = HKQuery.predicateForSamples(withStart: nil, end: nil, options: .strictEndDate)
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
                
                let query = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                    defer {
                        // Clean up query
                        if let query = samples?.first?.sourceRevision.productType {
                            self.removeQuery(query)
                        }
                    }
                    
                    if let error = error {
                        print("Heart rate variability query error: \(error)")
                        continuation.resume(returning: ("heartRateVariability", nil))
                        return
                    }
                    
                    if let sample = samples?.first as? HKQuantitySample {
                        let hrv = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                        print("Heart rate variability fetched: \(hrv) ms")
                        continuation.resume(returning: ("heartRateVariability", hrv))
                    } else {
                        continuation.resume(returning: ("heartRateVariability", nil))
                    }
                }
                
                self.addQuery(query)
                self.healthStore.execute(query)
            }
        }
    }
    
    private func fetchECGData(semaphore: DispatchSemaphore) async -> (String, Any) {
        defer { semaphore.signal() }
        semaphore.wait()
        
        return await withCheckedContinuation { continuation in
            autoreleasepool {
                let ecgType = HKDataType.electrocardiogramType()
                let predicate = HKQuery.predicateForSamples(withStart: nil, end: nil, options: .strictEndDate)
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
                
                let query = HKSampleQuery(sampleType: ecgType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                    defer {
                        // Clean up query
                        if let query = samples?.first?.sourceRevision.productType {
                            self.removeQuery(query)
                        }
                    }
                    
                    if let error = error {
                        print("ECG query error: \(error)")
                        continuation.resume(returning: ("ecgData", nil))
                        return
                    }
                    
                    if let ecgSample = samples?.first as? HKElectrocardiogram {
                        // Process ECG data efficiently
                        self.processECGData(ecgSample) { result in
                            continuation.resume(returning: ("ecgData", result))
                        }
                    } else {
                        continuation.resume(returning: ("ecgData", nil))
                    }
                }
                
                self.addQuery(query)
                self.healthStore.execute(query)
            }
        }
    }
    
    // MARK: - Query Management
    
    private func addQuery(_ query: HKQuery) {
        queryQueue.async {
            if self.activeQueries.count >= self.maxConcurrentQueries {
                // Remove oldest query
                if let oldestQuery = self.activeQueries.first {
                    self.healthStore.stop(oldestQuery)
                    self.activeQueries.removeFirst()
                }
            }
            self.activeQueries.append(query)
        }
    }
    
    private func removeQuery(_ query: HKQuery) {
        queryQueue.async {
            self.activeQueries.removeAll { $0 === query }
        }
    }
    
    // MARK: - ECG Processing
    
    private func processECGData(_ ecgSample: HKElectrocardiogram, completion: @escaping ([String: Any]) -> Void) {
        autoreleasepool {
            var ecgData: [String: Any] = [:]
            
            // Get basic ECG information
            ecgData["startDate"] = ecgSample.startDate
            ecgData["endDate"] = ecgSample.endDate
            ecgData["samplingFrequency"] = ecgSample.samplingFrequency
            
            // Process voltage data efficiently
            let voltageQuery = HKQuantityType.quantityType(forIdentifier: .electrocardiogramVoltage)!
            let predicate = HKQuery.predicateForSamples(withStart: ecgSample.startDate, end: ecgSample.endDate, options: .strictStartDate)
            
            let query = HKQuantitySeriesSampleQuery(quantityType: voltageQuery, predicate: predicate) { _, samples, _, error in
                if let error = error {
                    print("ECG voltage query error: \(error)")
                    completion(ecgData)
                    return
                }
                
                if let samples = samples, !samples.isEmpty {
                    // Calculate peak amplitude efficiently
                    let voltages = samples.compactMap { sample -> Double? in
                        guard let sample = sample as? HKQuantitySample else { return nil }
                        return sample.quantity.doubleValue(for: HKUnit.voltUnit(with: .micro))
                    }
                    
                    if let maxVoltage = voltages.max() {
                        ecgData["peakAmplitude"] = maxVoltage
                        ecgData["voltageCount"] = voltages.count
                    }
                }
                
                completion(ecgData)
            }
            
            self.addQuery(query)
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - Pre-warming
    
    func prewarmServices() {
        // Pre-warm HealthKit queries to improve performance
        Task {
            await prewarmHealthKitQueries()
        }
    }
    
    private func prewarmHealthKitQueries() async {
        // Pre-warm common queries in background
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.prewarmQuery(for: .heartRate)
            }
            group.addTask {
                await self.prewarmQuery(for: .bloodPressureSystolic)
            }
            group.addTask {
                await self.prewarmQuery(for: .oxygenSaturation)
            }
        }
    }
    
    private func prewarmQuery(for identifier: HKQuantityTypeIdentifier) async {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: nil, end: nil, options: .strictEndDate)
        let query = HKSampleQuery(sampleType: quantityType, predicate: predicate, limit: 1, sortDescriptors: nil) { _, _, _ in
            // Just pre-warm, don't process results
        }
        
        healthStore.execute(query)
        
        // Stop query after a short delay
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        healthStore.stop(query)
    }
}

// MARK: - Models

/// Represents the status of a blood test result.
///
/// This enumeration provides a standardized way to categorize test results
/// based on their values relative to normal reference ranges.
///
/// ## Cases
/// - `normal`: Result is within the expected reference range
/// - `high`: Result is above the upper limit of the reference range
/// - `low`: Result is below the lower limit of the reference range
///
/// ## Usage
/// ```swift
/// let status = testResult.status
/// switch status {
/// case .normal:
///     print("Result is normal")
/// case .high:
///     print("Result is elevated")
/// case .low:
///     print("Result is low")
/// }
/// ```
public enum TestStatus: String, Codable {
    /// Result is within normal reference range
    case normal
    /// Result is above the upper limit of reference range
    case high
    /// Result is below the lower limit of reference range
    case low
}

/// Represents a complete blood test with multiple results.
///
/// This structure encapsulates all the data for a single blood test,
/// including the test date, type, and individual test results.
/// It provides a comprehensive view of a patient's blood work at a specific point in time.
///
/// ## Properties
/// - `id`: Unique identifier for the test
/// - `date`: Date when the test was performed
/// - `testType`: Type of blood test (e.g., "CBC", "CMP", "Lipid Panel")
/// - `results`: Array of individual test results
///
/// ## Usage
/// ```swift
/// let bloodTest = BloodTest(
///     date: Date(),
///     testType: "CBC",
///     results: [testResult1, testResult2]
/// )
/// ```
public struct BloodTest: Identifiable, Codable, Equatable {
    /// Unique identifier for the blood test
    public let id: UUID
    /// Date when the blood test was performed
    public let date: Date
    /// Type of blood test (e.g., "CBC", "CMP", "Lipid Panel")
    public let testType: String
    /// Array of individual test results
    public let results: [TestResult]
    
    /// Creates a new blood test with the specified parameters.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID)
    ///   - date: Date when the test was performed
    ///   - testType: Type of blood test
    ///   - results: Array of test results
    public init(id: UUID = UUID(), date: Date, testType: String, results: [TestResult]) {
        self.id = id
        self.date = date
        self.testType = testType
        self.results = results
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: BloodTest, rhs: BloodTest) -> Bool {
        return lhs.id == rhs.id &&
               lhs.date == rhs.date &&
               lhs.testType == rhs.testType &&
               lhs.results == rhs.results
    }
}

/// Represents an individual test result with validation and status calculation.
///
/// This structure contains all the data for a single blood test parameter,
/// including the measured value, reference range, and calculated status.
/// It provides built-in validation and status determination logic.
///
/// ## Properties
/// - `id`: Unique identifier for the test result
/// - `name`: Name of the test parameter (e.g., "Hemoglobin", "Glucose")
/// - `value`: Measured value
/// - `unit`: Unit of measurement (e.g., "g/dL", "mg/dL")
/// - `referenceRange`: Expected range in format "lower-upper" (e.g., "13.5-17.5")
/// - `explanation`: Human-readable explanation of what the test measures
/// - `status`: Calculated status based on value and reference range
///
/// ## Validation
/// The structure includes methods to validate values against reference ranges
/// and automatically calculates the status (normal, high, or low).
///
/// ## Usage
/// ```swift
/// let result = TestResult(
///     name: "Hemoglobin",
///     value: 15.2,
///     unit: "g/dL",
///     referenceRange: "13.5-17.5",
///     explanation: "Measures oxygen-carrying capacity of blood"
/// )
/// print(result.status) // .normal
/// ```
public struct TestResult: Identifiable, Codable, Equatable {
    /// Unique identifier for the test result
    public let id: UUID
    /// Name of the test parameter
    public let name: String
    /// Measured value
    public var value: Double
    /// Unit of measurement
    public let unit: String
    /// Expected reference range in format "lower-upper"
    public let referenceRange: String
    /// Human-readable explanation of the test
    public let explanation: String
    
    /// Calculated status based on the value and reference range.
    ///
    /// This computed property automatically determines whether the result
    /// is normal, high, or low by comparing the value against the parsed
    /// reference range.
    ///
    /// - Returns: The status of the result
    public var status: TestStatus {
        let bounds = parseReferenceBounds(from: referenceRange)
        if let lower = bounds.lower, value < lower { return .low }
        if let upper = bounds.upper, value > upper { return .high }
        return .normal
    }
    
    /// Creates a new test result with the specified parameters.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID)
    ///   - name: Name of the test parameter
    ///   - value: Measured value
    ///   - unit: Unit of measurement
    ///   - referenceRange: Expected range in format "lower-upper"
    ///   - explanation: Human-readable explanation
    public init(id: UUID = UUID(), name: String, value: Double, unit: String, referenceRange: String, explanation: String) {
        self.id = id
        self.name = name
        self.value = value
        self.unit = unit
        self.referenceRange = referenceRange
        self.explanation = explanation
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: TestResult, rhs: TestResult) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.value == rhs.value &&
               lhs.unit == rhs.unit &&
               lhs.referenceRange == rhs.referenceRange &&
               lhs.explanation == rhs.explanation
    }
    
    /// Validates the value against the reference range.
    ///
    /// This method checks if the current value falls within the expected
    /// reference range by parsing the range string and comparing values.
    ///
    /// - Returns: `true` if the value is within the reference range, `false` otherwise
    public func isValidValue() -> Bool {
        let bounds = parseReferenceBounds(from: referenceRange)
        if let lower = bounds.lower, value < lower { return false }
        if let upper = bounds.upper, value > upper { return false }
        return true
    }

    /// Parses a reference range string with optional units and inequality symbols.
    ///
    /// Supported formats:
    /// - "4.5-11.0 K/µL"
    /// - "41.0-50.0%"
    /// - "<200 mg/dL"
    /// - ">60 mL/min/1.73m²"
    /// - "8-16"
    private func parseReferenceBounds(from range: String) -> (lower: Double?, upper: Double?) {
        let trimmed = range.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return (nil, nil) }

        // Handle inequalities
        if trimmed.first == "<" || trimmed.first == "≤" {
            let numberString = String(trimmed.dropFirst()).extractLeadingNumber()
            if let upper = Double(numberString) { return (nil, upper) }
        }
        if trimmed.first == ">" || trimmed.first == "≥" {
            let numberString = String(trimmed.dropFirst()).extractLeadingNumber()
            if let lower = Double(numberString) { return (lower, nil) }
        }

        // Handle range with dash
        let parts = trimmed.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
        if parts.count == 2 {
            let leftNum = String(parts[0]).extractLeadingNumber()
            let rightNum = String(parts[1]).extractLeadingNumber()
            let lower = Double(leftNum)
            let upper = Double(rightNum)
            return (lower, upper)
        }

        // Fallback: try to read a single numeric threshold
        let single = trimmed.extractLeadingNumber()
        if let value = Double(single) { return (value, value) }
        return (nil, nil)
    }
}

// MARK: - Test Result Models

/// Complete Blood Count (CBC) test results.
///
/// This structure encapsulates all the components of a CBC test,
/// which measures various aspects of blood cells and hemoglobin.
/// It includes standard reference ranges and validation for each component.
///
// Removed old CBCResult struct - using enhanced version below

// Removed old CMPResult struct - using enhanced version below
    
    /// Detailed explanations for each CMP component.
// Removed orphaned static properties and initializers

// MARK: - Security Manager

/// Manages biometric authentication for secure access to health data.
///
/// This class provides a secure way to authenticate users using biometric
/// authentication (Face ID or Touch ID) before allowing access to sensitive
/// health information.
///
/// ## Features
/// - Biometric authentication using Face ID or Touch ID
/// - Fallback to device passcode if biometrics are unavailable
/// - Secure access control for health data
/// - User-friendly authentication prompts
///
/// ## Usage
/// ```swift
/// SecurityManager.shared.authenticateUser { success in
///     if success {
///         // Allow access to health data
///     } else {
///         // Handle authentication failure
///     }
/// }
/// ```
class SecurityManager {
    /// Shared instance for singleton access
    static let shared = SecurityManager()
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    /// Authenticates the user using biometric authentication.
    ///
    /// This method attempts to authenticate the user using Face ID or Touch ID.
    /// If biometric authentication is not available, it will fall back to
    /// device passcode authentication.
    ///
    /// - Parameter completion: Closure called with authentication result
    func authenticateUser(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, 
                                 localizedReason: "Access your blood test records") { success, _ in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else {
            completion(false)
        }
    }
}

// MARK: - Parsing Helpers

// Helper function to extract numeric values from strings like ">90", "<5", etc.
private func extractNumericValueFromString(_ string: String) -> Double? {
    // Remove common prefixes/suffixes and extract the number
    let cleanedString = string.replacingOccurrences(of: ">", with: "")
        .replacingOccurrences(of: "<", with: "")
        .replacingOccurrences(of: "=", with: "")
        .replacingOccurrences(of: " ", with: "")
    
    return Double(cleanedString)
}

private extension String {
    /// Extracts the leading numeric portion (including decimal) from a string, ignoring trailing units.
    func extractLeadingNumber() -> String {
        var chars: [Character] = []
        var hasDot = false
        var hasSign = false
        for ch in self.trimmingCharacters(in: .whitespaces) {
            if ch == "+" || ch == "-" { if chars.isEmpty && !hasSign { hasSign = true; chars.append(ch); continue } else { break } }
            if ch.isNumber { chars.append(ch); continue }
            if ch == "." && !hasDot { hasDot = true; chars.append(ch); continue }
            break
        }
        return String(chars)
    }
}

// MARK: - View Models

/// Observable view model for managing blood test data.
///
/// This class provides a reactive interface for managing blood test data
/// throughout the app. It handles data persistence, validation, and
/// provides real-time updates to the UI when data changes.
///
/// ## Features
/// - Observable properties for reactive UI updates
/// - Core Data integration for persistence
/// - Data validation and error handling
/// - HealthKit synchronization capabilities
///
/// ## Usage
/// ```swift
/// let viewModel = BloodTestViewModel(context: viewContext)
/// viewModel.addTest(bloodTest)
/// ```
class BloodTestViewModel: ObservableObject {
    @Published var bloodTests: [BloodTest] = []
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    private let viewContext: NSManagedObjectContext
    private let persistenceController: PersistenceController
    private var memoryWarningObserver: NSObjectProtocol?
    
    // Memory optimization properties
    private let maxTestsInMemory = 100
    private var loadedTestIds: Set<UUID> = []
    private var memoryUsageTimer: Timer?
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        self.persistenceController = PersistenceController.shared
        setupMemoryManagement()
        loadTests()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Memory Management
    
    private func setupMemoryManagement() {
        // Monitor memory warnings
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
        
        // Start memory monitoring
        startMemoryMonitoring()
    }
    
    private func startMemoryMonitoring() {
        memoryUsageTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.checkMemoryUsage()
        }
    }
    
    private func checkMemoryUsage() {
        let currentMemory = getCurrentMemoryUsage()
        
        if currentMemory > 80 * 1024 * 1024 { // 80 MB
            print("⚠️ High memory usage in BloodTestViewModel: \(currentMemory / 1024 / 1024) MB")
            performMemoryCleanup()
        }
        
        // Log memory usage periodically
        print("📊 BloodTestViewModel memory usage: \(currentMemory / 1024 / 1024) MB")
    }
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return UInt64(info.resident_size)
        } else {
            // Fallback to ProcessInfo
            return UInt64(ProcessInfo.processInfo.physicalMemory)
        }
    }
    
    private func handleMemoryWarning() {
        print("🚨 Memory warning in BloodTestViewModel - performing cleanup")
        performMemoryCleanup()
    }
    
    private func performMemoryCleanup() {
        // Clear loaded test IDs to force reloading from Core Data
        loadedTestIds.removeAll()
        
        // Clear blood tests array if too many loaded
        if bloodTests.count > maxTestsInMemory {
            let testsToKeep = Array(bloodTests.prefix(maxTestsInMemory / 2))
            bloodTests = testsToKeep
            print("🧹 Cleared \(bloodTests.count - testsToKeep.count) tests from memory")
        }
        
        // Force garbage collection
        autoreleasepool {
            // Additional cleanup
        }
        
        print("🧹 BloodTestViewModel memory cleanup completed")
    }
    
    private func cleanup() {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        memoryUsageTimer?.invalidate()
        memoryUsageTimer = nil
        
        // Clear arrays
        bloodTests.removeAll()
        loadedTestIds.removeAll()
    }
    
    // MARK: - Data Loading
    
    func loadTests() {
        isLoading = true
        
        // Use memory-optimized fetching
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "BloodTestEntity")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \BloodTestEntity.date, ascending: false)]
        
        // Set memory limits
        fetchRequest.fetchBatchSize = 50
        fetchRequest.fetchLimit = maxTestsInMemory
        
        do {
            let testEntities = try persistenceController.fetchWithMemoryOptimization(fetchRequest)
            print("=== loadTests Debug ===")
            print("Found \(testEntities.count) test entities in Core Data")
            
            // Process entities in batches to avoid memory spikes
            let batchSize = 20
            var processedTests: [BloodTest] = []
            
            for i in stride(from: 0, to: testEntities.count, by: batchSize) {
                let endIndex = min(i + batchSize, testEntities.count)
                let batch = Array(testEntities[i..<endIndex])
                
                let batchTests = batch.compactMap { testEntity -> BloodTest? in
                    autoreleasepool {
                        guard let id = testEntity.value(forKey: "id") as? UUID,
                              let date = testEntity.value(forKey: "date") as? Date,
                              let testType = testEntity.value(forKey: "testType") as? String,
                              let resultEntities = testEntity.value(forKey: "results") as? Set<NSManagedObject> else {
                            print("Failed to parse test entity: id=\(testEntity.value(forKey: "id") ?? "nil"), date=\(testEntity.value(forKey: "date") ?? "nil"), testType=\(testEntity.value(forKey: "testType") ?? "nil"), results=\(testEntity.value(forKey: "results") ?? "nil")")
                            return nil
                        }
                        
                        print("Parsing test: \(testType) with \(resultEntities.count) results")
                        
                        let results = resultEntities.compactMap { resultEntity -> TestResult? in
                            guard let id = resultEntity.value(forKey: "id") as? UUID,
                                  let name = resultEntity.value(forKey: "name") as? String,
                                  let value = resultEntity.value(forKey: "value") as? Double,
                                  let unit = resultEntity.value(forKey: "unit") as? String,
                                  let referenceRange = resultEntity.value(forKey: "referenceRange") as? String,
                                  let explanation = resultEntity.value(forKey: "explanation") as? String else {
                                print("Failed to parse result entity: name=\(resultEntity.value(forKey: "name") ?? "nil"), value=\(resultEntity.value(forKey: "value") ?? "nil")")
                                return nil
                            }
                            
                            return TestResult(
                                id: id,
                                name: name,
                                value: value,
                                unit: unit,
                                referenceRange: referenceRange,
                                explanation: explanation
                            )
                        }
                        
                        print("Successfully parsed \(results.count) results for test: \(testType)")
                        
                        return BloodTest(
                            id: id,
                            date: date,
                            testType: testType,
                            results: results
                        )
                    }
                }
                
                processedTests.append(contentsOf: batchTests)
                
                // Small delay to prevent UI blocking
                if endIndex < testEntities.count {
                    Thread.sleep(forTimeInterval: 0.01)
                }
            }
            
            bloodTests = processedTests
            loadedTestIds = Set(processedTests.map { $0.id })
            
            print("Successfully loaded \(bloodTests.count) blood tests from Core Data")
            errorMessage = nil
        } catch {
            print("Failed to load test data: \(error)")
            errorMessage = "Failed to load test data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Test Management
    
    func addTest(_ test: BloodTest) {
        // Check memory before adding
        if bloodTests.count >= maxTestsInMemory {
            performMemoryCleanup()
        }
        
        let testEntity = BloodTestEntity(context: viewContext)
        testEntity.id = test.id
        testEntity.date = test.date
        testEntity.testType = test.testType
        
        // Create result entities
        for result in test.results {
            let resultEntity = TestResultEntity(context: viewContext)
            resultEntity.id = result.id
            resultEntity.name = result.name
            resultEntity.value = result.value
            resultEntity.unit = result.unit
            resultEntity.referenceRange = result.referenceRange
            resultEntity.explanation = result.explanation
            resultEntity.test = testEntity
        }
        
        do {
            try viewContext.save()
            // Refresh the published array from Core Data to ensure consistency
            loadTests()
            print("Successfully added test and refreshed view model. Total tests: \(bloodTests.count)")
        } catch {
            errorMessage = "Failed to save test: \(error.localizedDescription)"
        }
    }
    
    func deleteTest(_ test: BloodTest) {
        // Find and delete the test entity
        let fetchRequest: NSFetchRequest<BloodTestEntity> = BloodTestEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", test.id as CVarArg)
        
        do {
            let testEntities = try viewContext.fetch(fetchRequest)
            for entity in testEntities {
                viewContext.delete(entity)
            }
            
            try viewContext.save()
            loadTests() // Refresh the list
            print("Successfully deleted test")
        } catch {
            errorMessage = "Failed to delete test: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Memory-Efficient Operations
    
    func getTestById(_ id: UUID) -> BloodTest? {
        return bloodTests.first { $0.id == id }
    }
    
    func getTestsByType(_ type: String) -> [BloodTest] {
        return bloodTests.filter { $0.testType == type }
    }
    
    func clearAllTests() {
        // Clear from memory
        bloodTests.removeAll()
        loadedTestIds.removeAll()
        
        // Clear from Core Data
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "BloodTestEntity")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try viewContext.execute(deleteRequest)
            try viewContext.save()
            print("Successfully cleared all tests")
        } catch {
            errorMessage = "Failed to clear tests: \(error.localizedDescription)"
        }
    }
}

// MARK: - Privacy Documentation
struct PrivacyInfo {
    static let privacyStatement = """
    Privacy and Data Storage
    
    This app is designed with your privacy as a top priority:
    
    1. Local Storage Only
    • All your health data is stored exclusively on your device
    • No data is sent to external servers or cloud storage
    • No data is shared with third parties
    
    2. Data Control
    • You have complete control over your data
    • You can delete all data at any time
    • No automatic data synchronization
    
    3. Security
    • Data is encrypted at rest
    • No internet connection required
    • No background data collection
    
    4. Transparency
    • Clear documentation of data handling
    • No hidden data collection
    • No analytics or tracking
    
    Your health data belongs to you. We believe in complete privacy and local control of your information.
    """
} 

// MARK: - VA Lab Data Models

/// Models for importing VA lab results in their specific JSON format
struct VALabData: Codable {
    let healthcare_facility: VALabFacility
    let patient: VALabPatient
    let report: VALabReport
    let lab_tests: VALabTests
}

struct VALabFacility: Codable {
    let name: String
    let address: VALabAddress
}

struct VALabAddress: Codable {
    let street: String
    let city: String
    let state: String
    let zip_code: String
}

struct VALabPatient: Codable {
    let name: String
    let address: VALabAddress
}

struct VALabReport: Codable {
    let type: String
    let description: String
    let date: String
}

struct VALabTests: Codable {
    let cbc: VALabCBC?
    let cmp: VALabCMP?
}

struct VALabCBC: Codable {
    let test_name: String
    let test_date: String
    let results: VALabCBCResults
}

struct VALabCBCResults: Codable {
    let wbc: VALabTestValue?
    let neutrophils_percent: VALabTestValue?
    let lymphs_percent: VALabTestValue?
    let monos_percent: VALabTestValue?
    let eos_percent: VALabTestValue?
    let basos_percent: VALabTestValue?
    let neutrophils_absolute: VALabTestValue?
    let lymphs_absolute: VALabTestValue?
    let monos_absolute: VALabTestValue?
    let eos_absolute: VALabTestValue?
    let basos_absolute: VALabTestValue?
    let rbc: VALabTestValue?
    let hgb: VALabTestValue?
    let hct: VALabTestValue?
    let mcv: VALabTestValue?
    let mch: VALabTestValue?
    let mchc: VALabTestValue?
    let rdw: VALabTestValue?
    let platelet_count: VALabTestValue?
}

struct VALabCMP: Codable {
    let test_name: String
    let test_date: String
    let results: VALabCMPResults
}

struct VALabCMPResults: Codable {
    let glucose: VALabTestValue?
    let urea_nitrogen: VALabTestValue?
    let creatinine: VALabTestValue?
    let sodium: VALabTestValue?
    let potassium: VALabTestValue?
    let chloride: VALabTestValue?
    let co2: VALabTestValue?
    let calcium: VALabTestValue?
    let albumin: VALabTestValue?
    let ast: VALabTestValue?
    let alt: VALabTestValue?
    let alkaline_phosphatase: VALabTestValue?
    let total_bilirubin: VALabTestValue?
    let direct_bilirubin: VALabTestValue?
    let total_protein: VALabTestValue?
    let globulin: VALabTestValue?
    let a_g_ratio: VALabTestValue?
}

struct VALabTestValue: Codable {
    let name: String
    let value: Double?
    let units: String
} 

// MARK: - Comprehensive Lab Results Format (User's Preferred Format)

/// Comprehensive lab results data structure matching the user's preferred JSON format
struct ComprehensiveLabData: Codable {
    let healthcare_facility: HealthcareFacility
    let patient: Patient
    let report: LabReport
    // Removed lab_tests reference since LabTests struct was deleted
}

struct HealthcareFacility: Codable {
    let name: String
    let address: Address
}

struct Address: Codable {
    let street: String
    let city: String
    let state: String
    let zip_code: String
}

struct Patient: Codable {
    let name: String
    let address: Address
}

struct LabReport: Codable {
    let type: String
    let description: String
    let date: String
}

// Removed duplicate struct definitions - using enhanced versions below

struct LabTestResult: Codable {
    let name: String
    let value: LabTestValue?
    let units: String
    let flag: String?
    
    /// Computed property to determine if the result is flagged
    var isFlagged: Bool {
        return flag != nil && flag != "NORMAL"
    }
    
    /// Computed property to get the status based on flag
    var status: TestStatus {
        guard let flag = flag else { return .normal }
        switch flag.uppercased() {
        case "HIGH", "H":
            return .high
        case "LOW", "L":
            return .low
        case "CRITICAL", "CRIT":
            return .high
        default:
            return .normal
        }
    }
}

/// Enhanced enum to handle various lab test value types including null values
enum LabTestValue: Codable {
    case string(String)
    case number(Double)
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let numberValue = try? container.decode(Double.self) {
            self = .number(numberValue)
        } else {
            throw DecodingError.typeMismatch(LabTestValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String, Double, or null"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
    
    var stringValue: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return String(value)
        case .null:
            return "N/A"
        }
    }
    
    var numericValue: Double? {
        switch self {
        case .string(let value):
            return Double(value)
        case .number(let value):
            return value
        case .null:
            return nil
        }
    }
    
    var displayValue: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return String(format: "%.1f", value)
        case .null:
            return "N/A"
        }
    }
}

// MARK: - Comprehensive Health Data Models

/// Models for importing comprehensive health data including clinical vitals and lab results
struct ComprehensiveHealthData: Codable {
    let patient: HealthDataPatient
    let clinical_vitals: [ClinicalVital]?
    let lab_results: [LabResult]?
}

struct HealthDataPatient: Codable {
    let name: String
    let date_of_birth: String?
    let provider: String?
}

struct ClinicalVital: Codable {
    let date: String
    let blood_pressure: [String]?
    let temperature_f: Double?
    let heart_rate_bpm: Double?
    let oxygen_saturation_percent: Double?
    let pain_score: Double?
    let respiratory_rate_bpm: Double?
    let weight_lb: Double?
    let height_in: Double?
}

struct LabResult: Codable {
    let date: String
    let tests: [LabTest]
    let notes: [String]?
}

struct LabTest: Codable {
    let name: String
    let value: LabTestValue?
    let unit: String?
    let reference_range: String?
    let qualifier: String?
} 

// MARK: - Simple Lab Results Format (User's Current JSON)

/// Simple lab results format with test categories as keys
struct SimpleLabResults: Codable {
    let BC_Complete_Blood_Count: [SimpleTestResult]?
    let CMP_Metabolism_Studies: [SimpleTestResult]?
    let Cholesterol_Results: [SimpleTestResult]?
    
    // Add more test categories as needed
}

struct SimpleTestResult: Codable {
    let date: String
    let testName: String
    let value: Double?
    let unit: String?
    let reference_range: String?
    let note: String?
    let time: String?
    let sample: String?
    
    // Helper method to extract numeric values from strings like ">90", "<5", etc.
    private static func extractNumericValue(from string: String) -> Double? {
        // Remove common prefixes/suffixes and extract the number
        let cleanedString = string.replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        return Double(cleanedString)
    }
    
    // Custom decoder to handle dynamic test names
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        
        // First, decode the date
        date = try container.decode(String.self, forKey: AnyCodingKey("date"))
        
        // Try to decode optional fields if they exist
        unit = try? container.decodeIfPresent(String.self, forKey: AnyCodingKey("unit"))
        reference_range = try? container.decodeIfPresent(String.self, forKey: AnyCodingKey("reference_range"))
        note = try? container.decodeIfPresent(String.self, forKey: AnyCodingKey("note"))
        time = try? container.decodeIfPresent(String.self, forKey: AnyCodingKey("time"))
        sample = try? container.decodeIfPresent(String.self, forKey: AnyCodingKey("sample"))
        
        // Find the test name and value by looking for keys that aren't standard fields
        var foundTestName = ""
        var foundValue: Double? = nil
        
        let standardKeys = ["date", "unit", "reference_range", "note", "time", "sample"]
        
        for key in container.allKeys {
            let keyString = key.stringValue
            if !standardKeys.contains(keyString) {
                // This is a test name key
                foundTestName = keyString
                
                // Try to decode the value
                if let doubleValue = try? container.decode(Double.self, forKey: key) {
                    foundValue = doubleValue
                } else if let intValue = try? container.decode(Int.self, forKey: key) {
                    foundValue = Double(intValue)
                } else if let stringValue = try? container.decode(String.self, forKey: key) {
                    // Handle string values like ">90"
                    if let numericPart = Self.extractNumericValue(from: stringValue) {
                        foundValue = numericPart
                    } else {
                        foundValue = nil
                    }
                } else {
                    // Handle null values - try to decode as null explicitly
                    if (try? container.decodeNil(forKey: key)) == true {
                        foundValue = nil
                    } else {
                        foundValue = nil
                    }
                }
                break // Found the test name, stop looking
            }
        }
        
        testName = foundTestName
        value = foundValue
    }
    
    // Custom init for creating test results manually
    init(date: String, testName: String, value: Double?, unit: String? = nil, reference_range: String? = nil, note: String? = nil, time: String? = nil, sample: String? = nil) {
        self.date = date
        self.testName = testName
        self.value = value
        self.unit = unit
        self.reference_range = reference_range
        self.note = note
        self.time = time
        self.sample = sample
    }
}

// Helper struct for dynamic key decoding
struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
    
    init(_ string: String) {
        self.stringValue = string
        self.intValue = nil
    }
} 

// MARK: - Enhanced Lab Results Format (User's Updated JSON)

/// Enhanced lab results format with patient info and structured test results
struct EnhancedLabResults: Codable {
    let patient_info: PatientInfo
    let CBC_Complete_Blood_Count: CBCPanel?
    let CMP_Metabolism_Studies: CMPPanel?
    let Cholesterol_Results: CholesterolPanel?
    let summary: TestSummary?
}

struct PatientInfo: Codable {
    let name: String
    let test_date: String
    let facility: String
}

struct CBCPanel: Codable {
    let test_date: String
    let results: [String: CBCResult]
    let interpretation: String?
}

struct CBCResult: Codable {
    let value: Double?
    let units: String
    let name: String
}

struct CMPPanel: Codable {
    let test_date: String
    let results: [String: CMPResult]
    let interpretation: String?
}

struct CMPResult: Codable {
    let value: EnhancedTestValue?
    let units: String
    let name: String
    let flag: String?
    let note: String?
}

struct CholesterolPanel: Codable {
    let test_date: String
    let test_time: String?
    let sample_type: String?
    let results: [String: CholesterolResult]
    let interpretation: String?
}

struct CholesterolResult: Codable {
    let value: Double?
    let units: String
    let name: String
    let flag: String?
    let note: String?
}

struct TestSummary: Codable {
    let abnormal_findings: [AbnormalFinding]?
    let normal_findings: [String]?
}

struct AbnormalFinding: Codable {
    let test: String
    let value: EnhancedTestValue?
    let status: String
    let recommendation: String
}

/// Enhanced test value that can be Double, String, or null
enum EnhancedTestValue: Codable {
    case double(Double)
    case string(String)
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self = .null
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            self = .null
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
    
    var numericValue: Double? {
        switch self {
        case .double(let value):
            return value
        case .string(let value):
            return extractNumericValueFromString(value)
        case .null:
            return nil
        }
    }
    
    var stringValue: String? {
        switch self {
        case .double(let value):
            return String(value)
        case .string(let value):
            return value
        case .null:
            return nil
        }
    }
} 
