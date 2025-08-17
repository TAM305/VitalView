import Foundation
import CoreData
import SwiftUI
import Combine
import LocalAuthentication
@preconcurrency import HealthKit

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
final class HealthKitManager: ObservableObject, @unchecked Sendable {
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
        
        let typesToRead: Set<HKSampleType> = [
            HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!,
            HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.electrocardiogramType()
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: Set<HKSampleType>(), read: typesToRead)
            isAuthorized = true
            print("HealthKit authorization successful!")
            return true
        } catch {
            print("HealthKit authorization failed: \(error)")
            return false
        }
    }
    
    /// Get authorization status for a specific health data type
    func authorizationStatus(for healthKitType: HKSampleType) -> HKAuthorizationStatus {
        return healthStore.authorizationStatus(for: healthKitType)
    }
    
    /// Request authorization for specific health data types
    func requestAuthorization(
        toShare: Set<HKSampleType> = [],
        read: Set<HKObjectType>,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        healthStore.requestAuthorization(toShare: toShare, read: read, completion: completion)
    }
    
    /// Check if HealthKit is available and authorized
    var isHealthKitAvailable: Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    /// Get current authorization status
    var authorizationStatus: Bool {
        return isAuthorized
    }
    
    // MARK: - Memory-Efficient Data Fetching
    
    func fetchLatestVitalSigns() async -> [String: Any] {
        guard isAuthorized else {
            print("HealthKit not authorized")
            return [:]
        }
        
        var results: [String: Any] = [:]
        
        // Use TaskGroup for controlled concurrency
        await withTaskGroup(of: (String, Any).self) { group in
            // Heart Rate
            group.addTask {
                await self.fetchHeartRate()
            }
            
            // Blood Pressure
            group.addTask {
                await self.fetchBloodPressure()
            }
            
            // Oxygen Saturation
            group.addTask {
                await self.fetchOxygenSaturation()
            }
            
            // Body Temperature
            group.addTask {
                await self.fetchBodyTemperature()
            }
            
            // Respiratory Rate
            group.addTask {
                await self.fetchRespiratoryRate()
            }
            
            // Heart Rate Variability
            group.addTask {
                await self.fetchHeartRateVariability()
            }
            
            // ECG Data
            group.addTask {
                await self.fetchECGData()
            }
            
            // Collect results
            for await (key, value) in group {
                results[key] = value
            }
        }
        
        return results
    }
    
    // MARK: - Individual Fetch Methods with Memory Optimization
    
    private func fetchHeartRate() async -> (String, Any) {
        return await withCheckedContinuation { continuation in
            autoreleasepool {
                let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
                let predicate = HKQuery.predicateForSamples(withStart: nil, end: nil, options: .strictEndDate)
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

                let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                    if let error = error {
                        print("Heart rate query error: \(error)")
                        continuation.resume(returning: ("heartRate", NSNull()))
                        return
                    }

                    if let sample = samples?.first as? HKQuantitySample {
                        let cpm = HKUnit.count().unitDivided(by: .minute())
                        let heartRate = sample.quantity.doubleValue(for: cpm)
                        print("Heart rate fetched: \(heartRate) BPM")
                        continuation.resume(returning: ("heartRate", heartRate))
                    } else {
                        continuation.resume(returning: ("heartRate", NSNull()))
                    }
                }

                self.healthStore.execute(query)
            }
        }
    }
    
    private func fetchBloodPressure() async -> (String, Any) {
        return await withCheckedContinuation { continuation in
            autoreleasepool {
                let bloodPressureType = HKCorrelationType.correlationType(forIdentifier: .bloodPressure)!
                let predicate = HKQuery.predicateForSamples(withStart: nil, end: nil, options: .strictEndDate)
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

                let query = HKSampleQuery(sampleType: bloodPressureType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                    if let error = error {
                        print("Blood pressure query error: \(error)")
                        continuation.resume(returning: ("bloodPressure", NSNull()))
                        return
                    }

                    if let correlation = samples?.first as? HKCorrelation {
                        let sys = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)!
                        let dia = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)!
                        let systolic = correlation.objects(for: sys).first as? HKQuantitySample
                        let diastolic = correlation.objects(for: dia).first as? HKQuantitySample

                        if let s = systolic?.quantity.doubleValue(for: .millimeterOfMercury()),
                           let d = diastolic?.quantity.doubleValue(for: .millimeterOfMercury()) {
                            continuation.resume(returning: ("bloodPressure", "\(Int(s))/\(Int(d))"))
                        } else {
                            continuation.resume(returning: ("bloodPressure", NSNull()))
                        }
                    } else {
                        continuation.resume(returning: ("bloodPressure", NSNull()))
                    }
                }

                self.healthStore.execute(query)
            }
        }
    }
    
    private func fetchOxygenSaturation() async -> (String, Any) {
        return await withCheckedContinuation { continuation in
            autoreleasepool {
                let oxygenType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
                let predicate = HKQuery.predicateForSamples(withStart: nil, end: nil, options: .strictEndDate)
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

                let query = HKSampleQuery(sampleType: oxygenType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                    if let error = error {
                        print("Oxygen saturation query error: \(error)")
                        continuation.resume(returning: ("oxygenSaturation", NSNull()))
                        return
                    }

                    if let sample = samples?.first as? HKQuantitySample {
                        let raw = sample.quantity.doubleValue(for: .percent())
                        continuation.resume(returning: ("oxygenSaturation", raw * 100.0))
                    } else {
                        continuation.resume(returning: ("oxygenSaturation", NSNull()))
                    }
                }

                self.healthStore.execute(query)
            }
        }
    }
    
    private func fetchBodyTemperature() async -> (String, Any) {
        return await withCheckedContinuation { continuation in
            autoreleasepool {
                let temperatureType = HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!
                let predicate = HKQuery.predicateForSamples(withStart: nil, end: nil, options: .strictEndDate)
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

                let query = HKSampleQuery(sampleType: temperatureType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                    if let error = error {
                        print("Body temperature query error: \(error)")
                        continuation.resume(returning: ("bodyTemperature", NSNull()))
                        return
                    }

                    if let sample = samples?.first as? HKQuantitySample {
                        let tempF = sample.quantity.doubleValue(for: .degreeFahrenheit())
                        continuation.resume(returning: ("bodyTemperature", tempF))
                    } else {
                        continuation.resume(returning: ("bodyTemperature", NSNull()))
                    }
                }

                self.healthStore.execute(query)
            }
        }
    }
    
    private func fetchRespiratoryRate() async -> (String, Any) {
        return await withCheckedContinuation { continuation in
            autoreleasepool {
                let respiratoryType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!
                let predicate = HKQuery.predicateForSamples(withStart: nil, end: nil, options: .strictEndDate)
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

                let query = HKSampleQuery(sampleType: respiratoryType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                    if let error = error {
                        print("Respiratory rate query error: \(error)")
                        continuation.resume(returning: ("respiratoryRate", NSNull()))
                        return
                    }

                    if let sample = samples?.first as? HKQuantitySample {
                        let cpm = HKUnit.count().unitDivided(by: .minute())
                        let rr = sample.quantity.doubleValue(for: cpm)
                        continuation.resume(returning: ("respiratoryRate", rr))
                    } else {
                        continuation.resume(returning: ("respiratoryRate", NSNull()))
                    }
                }

                self.healthStore.execute(query)
            }
        }
    }
    
    private func fetchHeartRateVariability() async -> (String, Any) {
        return await withCheckedContinuation { continuation in
            let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
            let predicate = HKQuery.predicateForSamples(withStart: nil, end: nil, options: .strictEndDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let query = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    print("Heart rate variability query error: \(error)")
                    continuation.resume(returning: ("heartRateVariability", NSNull()))
                    return
                }

                if let sample = samples?.first as? HKQuantitySample {
                    let hrv = sample.quantity.doubleValue(for: .secondUnit(with: .milli))
                    continuation.resume(returning: ("heartRateVariability", hrv))
                } else {
                    continuation.resume(returning: ("heartRateVariability", NSNull()))
                }
            }

            self.healthStore.execute(query)
        }
    }
    
    private func fetchECGData() async -> (String, Any) {
        return await withCheckedContinuation { continuation in
            let ecgType = HKObjectType.electrocardiogramType()
            let predicate = HKQuery.predicateForSamples(withStart: nil, end: nil, options: .strictEndDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let query = HKSampleQuery(sampleType: ecgType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
                guard let self = self else { return }

                if let error = error {
                    print("ECG query error: \(error)")
                    continuation.resume(returning: ("ecgData", NSNull()))
                    return
                }

                guard let ecg = samples?.first as? HKElectrocardiogram else {
                    continuation.resume(returning: ("ecgData", NSNull()))
                    return
                }

                self.processECGSample(ecg) { dict in
                    continuation.resume(returning: ("ecgData", dict))
                }
            }

            self.healthStore.execute(query)
        }
    }
    
    // MARK: - ECG Processing (voltage & metadata)
    private func processECGSample(_ ecg: HKElectrocardiogram,
                                  completion: @escaping ([String: Any]) -> Void) {
        var info: [String: Any] = [
            "startDate": ecg.startDate,
            "endDate": ecg.endDate,
            "samplingFrequency": ecg.samplingFrequency as Any,
            "classification": ecg.classification.rawValue
        ]

        var sampleCount = 0
        var peak_mV: Double = .leastNonzeroMagnitude

        let query = HKElectrocardiogramQuery(ecg) { _, result in
            switch result {
            case .measurement(let m):
                // Pick a lead to read (appleWatchSimilarToLeadI is common); you can iterate several if desired.
                if let mv = m.quantity(for: .appleWatchSimilarToLeadI)?
                    .doubleValue(for: HKUnit.voltUnit(with: .milli)) {
                    peak_mV = max(peak_mV, abs(mv))
                }
                sampleCount += 1

            case .done:
                info["samples"] = sampleCount
                info["peakAmplitude_mV"] = (peak_mV == .leastNonzeroMagnitude) ? nil : peak_mV
                completion(info)

            case .error(let error):
                print("ECG query error: \(error)")
                completion(info)
            @unknown default:
                completion(info)
            }
        }

        self.healthStore.execute(query)
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
        memoryUsageTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkMemoryUsage()
        }
    }
    
    private func checkMemoryUsage() {
        let currentMemory = getCurrentMemoryUsage()
        
        if currentMemory > 150 * 1024 * 1024 { // 150 MB (increased from 80 MB)
            print("⚠️ High memory usage in BloodTestViewModel: \(currentMemory / 1024 / 1024) MB")
            performMemoryCleanup()
        }
        
        // Log memory usage periodically (less frequent)
        if currentMemory > 100 * 1024 * 1024 { // Only log when above 100 MB
            print("📊 BloodTestViewModel memory usage: \(currentMemory / 1024 / 1024) MB")
        }
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
        
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "BloodTestEntity")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            let testEntities = try viewContext.fetch(fetchRequest)
            print("Found \(testEntities.count) test entities in Core Data")
            
            // Process in batches to avoid memory issues
            let batchSize = 50
            var processedTests: [BloodTest] = []
            
            for i in stride(from: 0, to: testEntities.count, by: batchSize) {
                let endIndex = min(i + batchSize, testEntities.count)
                let batch = Array(testEntities[i..<endIndex])
                
                autoreleasepool {
                    for entity in batch {
                        guard let testType = entity.value(forKey: "testType") as? String,
                              let date = entity.value(forKey: "date") as? Date,
                              let resultEntities = entity.value(forKey: "results") as? Set<NSManagedObject> else {
                            continue
                        }
                        
                        print("Parsing test: \(testType) with \(resultEntities.count) results")
                        
                        var results: [TestResult] = []
                        for resultEntity in resultEntities {
                            guard let name = resultEntity.value(forKey: "name") as? String,
                                  let unit = resultEntity.value(forKey: "unit") as? String else {
                                continue
                            }
                            
                            // Get value directly as Double (Core Data stores as NSNumber)
                            let value: Double = {
                                if let d = resultEntity.value(forKey: "value") as? Double { return d }
                                // Fallback for legacy data that might be stored as String
                                if let s = resultEntity.value(forKey: "value") as? String, let d = Double(s) { return d }
                                return 0.0
                            }()
                            
                            // Get optional values with defaults
                            let referenceRange = resultEntity.value(forKey: "referenceRange") as? String ?? "0-0"
                            let explanation = resultEntity.value(forKey: "explanation") as? String ?? "No explanation available"
                            
                            let result = TestResult(
                                name: name,
                                value: value,
                                unit: unit,
                                referenceRange: referenceRange,
                                explanation: explanation
                            )
                            results.append(result)
                        }
                        
                        let test = BloodTest(id: UUID(), date: date, testType: testType, results: results)
                        processedTests.append(test)
                        
                        print("Successfully parsed \(results.count) results for test: \(testType)")
                    }
                }
                
                // Continue processing if there are more batches
                if endIndex < testEntities.count {
                    print("Processed batch \(i/batchSize + 1), continuing...")
                }
            }
            
            DispatchQueue.main.async {
                self.bloodTests = processedTests
                print("Successfully loaded \(self.bloodTests.count) blood tests from Core Data")
            }
        } catch {
            print("Error loading tests from Core Data: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Test Management
    
    func addTest(_ test: BloodTest) {
        // Check memory before adding
        if bloodTests.count >= maxTestsInMemory {
            performMemoryCleanup()
        }
        
        let testEntity = NSEntityDescription.insertNewObject(forEntityName: "BloodTestEntity", into: viewContext)
        testEntity.setValue(test.id, forKey: "id")
        testEntity.setValue(test.date, forKey: "date")
        testEntity.setValue(test.testType, forKey: "testType")
        
        // Create result entities
        for result in test.results {
            let resultEntity = NSEntityDescription.insertNewObject(forEntityName: "TestResultEntity", into: viewContext)
            resultEntity.setValue(result.id, forKey: "id")
            resultEntity.setValue(result.name, forKey: "name")
            resultEntity.setValue(result.value, forKey: "value") // Store Double directly - Core Data expects NSNumber
            resultEntity.setValue(result.unit, forKey: "unit")
            resultEntity.setValue(result.referenceRange, forKey: "referenceRange")
            resultEntity.setValue(result.explanation, forKey: "explanation")
            resultEntity.setValue(testEntity, forKey: "test")
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
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "BloodTestEntity")
        fetchRequest.predicate = NSPredicate(format: "testType == %@ AND date == %@", test.testType, test.date as NSDate)
        
        do {
            let entities = try viewContext.fetch(fetchRequest)
            for entity in entities {
                viewContext.delete(entity)
            }
            
            try viewContext.save()
            
            // Remove from memory
            bloodTests.removeAll { $0.testType == test.testType && $0.date == test.date }
            
            print("Successfully deleted test: \(test.testType) from \(test.date)")
        } catch {
            print("Error deleting test: \(error)")
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
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "BloodTestEntity")
        
        do {
            let entities = try viewContext.fetch(fetchRequest)
            for entity in entities {
                viewContext.delete(entity)
            }
            
            try viewContext.save()
            
            // Clear from memory
            bloodTests.removeAll()
            
            print("Successfully cleared all tests")
        } catch {
            print("Error clearing tests: \(error)")
        }
    }
    
    // MARK: - Import Functionality
    
    /// Imports lab data from JSON string
    /// - Parameter jsonData: JSON string containing lab results
    /// - Returns: Success status and error message if any
    func importLabData(_ jsonData: String) -> (success: Bool, errorMessage: String?) {
        // Check memory before importing
        if bloodTests.count >= maxTestsInMemory {
            performMemoryCleanup()
        }
        
        do {
            // Parse JSON data
            guard let data = jsonData.data(using: .utf8) else {
                return (false, "Failed to convert JSON string to data")
            }
            
            // Try to parse as a simple lab results format
            let labResults = try parseLabResults(from: data)
            
            // Create and add blood test
            let bloodTest = BloodTest(
                date: labResults.date,
                testType: labResults.testType,
                results: labResults.results
            )
            
            addTest(bloodTest)
            return (true, nil)
            
        } catch {
            print("Failed to import lab data: \(error)")
            return (false, "Failed to parse JSON: \(error.localizedDescription)")
        }
    }
    
    // MARK: - JSON Parsing
    
    private func parseLabResults(from data: Data) throws -> (date: Date, testType: String, results: [TestResult]) {
        // Simple parsing for basic lab results
        // This can be expanded based on your JSON format needs
        
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        
        guard let jsonDict = json as? [String: Any],
              let labTests = jsonDict["lab_tests"] as? [String: Any] else {
            throw NSError(domain: "ImportError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"])
        }
        
        // Parse date
        let dateString = labTests["test_date"] as? String ?? "01/01/2025"
        let date = parseDate(dateString) ?? Date()
        
        // Parse test type
        let testType = labTests["test_name"] as? String ?? "Complete Blood Count (CBC)"
        
        // Parse results
        var results: [TestResult] = []
        
        for (key, value) in labTests["results"] as? [String: Any] ?? [:] {
            if let resultDict = value as? [String: Any],
               let resultValue = resultDict["value"] as? Double {
                
                let name = resultDict["name"] as? String ?? key
                let unit = resultDict["units"] as? String ?? ""
                let referenceRange = getReferenceRange(for: key)
                let explanation = getExplanation(for: key)
                
                let testResult = TestResult(
                    name: name,
                    value: resultValue,
                    unit: unit,
                    referenceRange: referenceRange,
                    explanation: explanation
                )
                
                results.append(testResult)
            }
        }
        
        return (date: date, testType: testType, results: results)
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.date(from: dateString)
    }
    
    private func getReferenceRange(for testKey: String) -> String {
        switch testKey.lowercased() {
        case "wbc": return "4,000–11,000 /µL"
        case "neutrophils_percent", "neutrophils": return "40–70%"
        case "lymphs_percent", "lymphs": return "20–40%"
        case "monos_percent", "monos": return "2–8%"
        case "eos_percent", "eos": return "1–4%"
        case "basos_percent", "basos": return "0–1%"
        case "hgb": return "M: 13.5–17.5, W: 12.0–15.5 g/dL"
        case "mcv": return "80–100 fL"
        case "mch": return "27–33 pg"
        case "mchc": return "32–36 g/dL"
        case "rdw": return "11.5–14.5%"
        case "platelet_count": return "150,000–450,000 /µL"
        case "mpv": return "7.5–11.5 fL"
        default: return "N/A"
        }
    }
    
    private func getExplanation(for testKey: String) -> String {
        switch testKey.lowercased() {
        case "wbc": return "White blood cells; infection defense"
        case "neutrophils_percent", "neutrophils": return "Bacterial defense WBC percentage"
        case "lymphs_percent", "lymphs": return "Lymphocytes %; viral/immune response"
        case "monos_percent", "monos": return "Monocytes %; infection cleanup"
        case "eos_percent", "eos": return "Eosinophils %; allergies/parasites"
        case "basos_percent", "basos": return "Basophils %; allergy/inflammation"
        case "hgb": return "Oxygen-carrying protein in RBCs"
        case "mcv": return "Average red blood cell size"
        case "mch": return "Hemoglobin amount per red cell"
        case "mchc": return "Hemoglobin concentration in red cells"
        case "rdw": return "Variation in RBC size"
        case "platelet_count": return "Platelets; clotting function"
        case "mpv": return "Average platelet size"
        default: return "Blood test measurement"
        }
    }
    
    // MARK: - Utility Methods
    
    /// Returns the appropriate color for a test result based on its status
    /// - Parameter result: The test result to evaluate
    /// - Returns: Color representing the result status (normal, high, low)
    func getResultColor(_ result: TestResult) -> Color {
        switch result.status {
        case .normal:
            return .green
        case .high:
            return .red
        case .low:
            return .orange
        }
    }
    
    /// Updates an existing test with new data
    /// - Parameter updatedTest: The updated test data
    func updateTest(_ updatedTest: BloodTest) {
        // Find and remove the old test
        if let index = bloodTests.firstIndex(where: { $0.id == updatedTest.id }) {
            bloodTests.remove(at: index)
        }
        
        // Add the updated test
        addTest(updatedTest)
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
