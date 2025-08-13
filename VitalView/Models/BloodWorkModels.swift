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
    private let healthStore = HKHealthStore()
    
    /// Checks if HealthKit is available on the current device.
    ///
    /// - Returns: `true` if HealthKit is available, `false` otherwise
    func isHealthKitAvailable() -> Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    /// Checks the authorization status for a specific health data type.
    ///
    /// - Parameter type: The health data type to check
    /// - Returns: The current authorization status
    func getAuthorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        return healthStore.authorizationStatus(for: type)
    }
    
    /// Requests authorization for multiple health data types.
    ///
    /// - Parameters:
    ///   - typesToRead: Set of health data types to request read access for
    ///   - completion: Completion handler called with success status and error
    func requestAuthorization(for typesToRead: Set<HKObjectType>, completion: @escaping (Bool, Error?) -> Void) {
        guard isHealthKitAvailable() else {
            completion(false, NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "HealthKit is not available on this device"]))
            return
        }
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
    
    /// Gets the authorization status for basal body temperature.
    ///
    /// - Returns: The authorization status for basal body temperature
    func getBasalTemperatureAuthorizationStatus() -> HKAuthorizationStatus {
        guard let basalTemperatureType = HKObjectType.quantityType(forIdentifier: .basalBodyTemperature) else {
            return .notDetermined
        }
        return getAuthorizationStatus(for: basalTemperatureType)
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
public struct BloodTest: Identifiable, Codable {
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
public struct TestResult: Identifiable, Codable {
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
    /// - Returns: The status of the test result
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
/// ## Components
/// - White Blood Cells (WBC): Infection fighting cells
/// - Red Blood Cells (RBC): Oxygen-carrying cells
/// - Hemoglobin (HGB): Oxygen-carrying protein
/// - Hematocrit (HCT): Percentage of blood volume occupied by red cells
/// - Platelets (PLT): Blood clotting cells
///
/// ## Reference Ranges
/// The structure includes standard reference ranges for all CBC components
/// based on typical laboratory values.
public struct CBCResult: Codable {
    /// White blood cell count
    public let whiteBloodCells: TestResult
    /// Red blood cell count
    public let redBloodCells: TestResult
    /// Hemoglobin level
    public let hemoglobin: TestResult
    /// Hematocrit percentage
    public let hematocrit: TestResult
    /// Platelet count
    public let platelets: TestResult
    
    /// Standard reference ranges for CBC components.
    ///
    /// These ranges are based on typical laboratory values and may vary
    /// slightly between different laboratories and patient populations.
    public static let normalRanges: [String: ClosedRange<Double>] = [
        "WBC": 4.5...11.0,  // 10^9/L
        "RBC": 4.5...5.5,   // 10^12/L
        "HGB": 13.5...17.5, // g/dL
        "HCT": 38.8...50.0, // %
        "PLT": 150...450    // 10^9/L
    ]
    
    /// Creates a new CBC result with the specified components.
    ///
    /// - Parameters:
    ///   - whiteBloodCells: WBC test result
    ///   - redBloodCells: RBC test result
    ///   - hemoglobin: Hemoglobin test result
    ///   - hematocrit: Hematocrit test result
    ///   - platelets: Platelet test result
    public init(whiteBloodCells: TestResult,
                redBloodCells: TestResult,
                hemoglobin: TestResult,
                hematocrit: TestResult,
                platelets: TestResult) {
        self.whiteBloodCells = whiteBloodCells
        self.redBloodCells = redBloodCells
        self.hemoglobin = hemoglobin
        self.hematocrit = hematocrit
        self.platelets = platelets
    }
}

/// Comprehensive Metabolic Panel (CMP) test results.
///
/// This structure encapsulates all the components of a CMP test,
/// which measures various metabolic functions including kidney function,
/// liver function, and electrolyte balance.
///
/// ## Components
/// - Glucose: Blood sugar level
/// - BUN: Blood Urea Nitrogen (kidney function)
/// - Creatinine: Kidney function marker
/// - Sodium: Electrolyte balance
/// - Potassium: Heart and muscle function
/// - Chloride: Fluid balance
/// - Carbon Dioxide: Acid-base balance
/// - Calcium: Bone and muscle function
///
/// ## Explanations
/// Each component includes detailed explanations of what it measures
/// and what abnormal values might indicate.
public struct CMPResult: Codable {
    /// Blood glucose level
    public let glucose: TestResult
    /// Blood urea nitrogen level
    public let bun: TestResult
    /// Creatinine level
    public let creatinine: TestResult
    /// Sodium level
    public let sodium: TestResult
    /// Potassium level
    public let potassium: TestResult
    /// Chloride level
    public let chloride: TestResult
    /// Carbon dioxide level
    public let carbonDioxide: TestResult
    /// Calcium level
    public let calcium: TestResult
    
    /// Standard reference ranges for CMP components.
    ///
    /// These ranges are based on typical laboratory values and may vary
    /// between different laboratories and patient populations.
    public static let normalRanges: [String: ClosedRange<Double>] = [
        "GLU": 70...100,    // mg/dL
        "BUN": 7...20,      // mg/dL
        "CRE": 0.7...1.3,   // mg/dL
        "NA": 135...145,    // mmol/L
        "K": 3.5...5.0,     // mmol/L
        "CL": 98...107,     // mmol/L
        "CO2": 23...29,     // mmol/L
        "CA": 8.5...10.2    // mg/dL
    ]
    
    /// Detailed explanations for each CMP component.
    ///
    /// These explanations help users understand what each test measures
    /// and what abnormal values might indicate for their health.
    public static let explanations: [String: String] = [
        "GLU": "Glucose measures your blood sugar level. High levels may indicate diabetes, while low levels may suggest hypoglycemia.",
        "BUN": "Blood Urea Nitrogen measures kidney function. High levels may indicate kidney problems or dehydration.",
        "CRE": "Creatinine is a waste product from muscle metabolism. High levels may indicate kidney problems.",
        "NA": "Sodium helps maintain fluid balance. Abnormal levels may indicate dehydration or other electrolyte disorders.",
        "K": "Potassium is important for heart and muscle function. Abnormal levels can affect heart rhythm.",
        "CL": "Chloride helps maintain fluid balance and pH. Abnormal levels may indicate kidney or acid-base problems.",
        "CO2": "Carbon dioxide levels indicate acid-base balance. Abnormal levels may suggest respiratory or metabolic problems.",
        "CA": "Calcium is important for bones and muscle function. Abnormal levels may indicate bone, parathyroid, or kidney problems."
    ]
    
    /// Creates a new CMP result with the specified components.
    ///
    /// - Parameters:
    ///   - glucose: Glucose test result
    ///   - bun: BUN test result
    ///   - creatinine: Creatinine test result
    ///   - sodium: Sodium test result
    ///   - potassium: Potassium test result
    ///   - chloride: Chloride test result
    ///   - carbonDioxide: Carbon dioxide test result
    ///   - calcium: Calcium test result
    public init(glucose: TestResult,
                bun: TestResult,
                creatinine: TestResult,
                sodium: TestResult,
                potassium: TestResult,
                chloride: TestResult,
                carbonDioxide: TestResult,
                calcium: TestResult) {
        self.glucose = glucose
        self.bun = bun
        self.creatinine = creatinine
        self.sodium = sodium
        self.potassium = potassium
        self.chloride = chloride
        self.carbonDioxide = carbonDioxide
        self.calcium = calcium
    }
}

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
public final class BloodTestViewModel: ObservableObject {
    /// Published array of blood tests for reactive UI updates
    @Published public var bloodTests: [BloodTest] = []
    /// Currently selected blood test
    @Published public var selectedTest: BloodTest?
    /// Error message for user feedback
    @Published public var errorMessage: String?
    
    /// Core Data managed object context for persistence
    private let viewContext: NSManagedObjectContext
    
    /// Creates a new view model with the specified Core Data context.
    ///
    /// - Parameter context: Core Data managed object context
    public init(context: NSManagedObjectContext) {
        self.viewContext = context
        loadTests()
    }
    
    /// Adds a new blood test to the collection.
    ///
    /// This method validates the test results before adding them to ensure
    /// data integrity and provides user feedback for any validation issues.
    ///
    /// - Parameter test: The blood test to add
    public func addTest(_ test: BloodTest) {
        // Validate test results (non-blocking)
        let invalidResults = test.results.filter { !$0.isValidValue() }
        if !invalidResults.isEmpty {
            errorMessage = "Some test results are outside their reference ranges. Saved anyway."
        }
        
        // Create BloodTestEntity
        let testEntity = NSEntityDescription.insertNewObject(forEntityName: "BloodTestEntity", into: viewContext)
        
        testEntity.setValue(test.id, forKey: "id")
        testEntity.setValue(test.date, forKey: "date")
        testEntity.setValue(test.testType, forKey: "testType")
        
        // Create TestResultEntity for each result
        for result in test.results {
            let resultEntity = NSEntityDescription.insertNewObject(forEntityName: "TestResultEntity", into: viewContext)
            
            resultEntity.setValue(result.id, forKey: "id")
            resultEntity.setValue(result.name, forKey: "name")
            resultEntity.setValue(result.value, forKey: "value")
            resultEntity.setValue(result.unit, forKey: "unit")
            resultEntity.setValue(result.referenceRange, forKey: "referenceRange")
            resultEntity.setValue(result.explanation, forKey: "explanation")
            resultEntity.setValue(testEntity, forKey: "test")
        }
        
        // Save to Core Data
        do {
            try viewContext.save()
            bloodTests.append(test)
        } catch {
            errorMessage = "Failed to save test: \(error.localizedDescription)"
        }
    }
    
    public func deleteTest(_ test: BloodTest) {
        // Find and delete the test entity
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "BloodTestEntity")
        fetchRequest.predicate = NSPredicate(format: "id == %@", test.id as CVarArg)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            if let testEntity = results.first {
                viewContext.delete(testEntity)
                try viewContext.save()
                bloodTests.removeAll { $0.id == test.id }
            }
        } catch {
            errorMessage = "Failed to delete test: \(error.localizedDescription)"
        }
    }
    
    public func updateTest(_ test: BloodTest) {
        // Validate test results (non-blocking)
        let invalidResults = test.results.filter { !$0.isValidValue() }
        if !invalidResults.isEmpty {
            errorMessage = "Some test results are outside their reference ranges. Saved anyway."
        }
        
        // Find the existing test entity
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "BloodTestEntity")
        fetchRequest.predicate = NSPredicate(format: "id == %@", test.id as CVarArg)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            if let testEntity = results.first {
                // Update test entity
                testEntity.setValue(test.date, forKey: "date")
                testEntity.setValue(test.testType, forKey: "testType")
                
                // Remove existing results
                if let existingResults = testEntity.value(forKey: "results") as? Set<NSManagedObject> {
                    for result in existingResults {
                        viewContext.delete(result)
                    }
                }
                
                // Add new results
                for result in test.results {
                    let resultEntity = NSEntityDescription.insertNewObject(forEntityName: "TestResultEntity", into: viewContext)
                    
                    resultEntity.setValue(result.id, forKey: "id")
                    resultEntity.setValue(result.name, forKey: "name")
                    resultEntity.setValue(result.value, forKey: "value")
                    resultEntity.setValue(result.unit, forKey: "unit")
                    resultEntity.setValue(result.referenceRange, forKey: "referenceRange")
                    resultEntity.setValue(result.explanation, forKey: "explanation")
                    resultEntity.setValue(testEntity, forKey: "test")
                }
                
                try viewContext.save()
                
                // Update published property
                if let index = bloodTests.firstIndex(where: { $0.id == test.id }) {
                    bloodTests[index] = test
                }
            }
        } catch {
            errorMessage = "Failed to update test: \(error.localizedDescription)"
        }
    }
    
    public func loadTests() {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "BloodTestEntity")
        
        do {
            let testEntities = try viewContext.fetch(fetchRequest)
            bloodTests = testEntities.compactMap { testEntity in
                guard let id = testEntity.value(forKey: "id") as? UUID,
                      let date = testEntity.value(forKey: "date") as? Date,
                      let testType = testEntity.value(forKey: "testType") as? String,
                      let resultEntities = testEntity.value(forKey: "results") as? Set<NSManagedObject> else {
                    return nil
                }
                
                let results = resultEntities.compactMap { resultEntity -> TestResult? in
                    guard let id = resultEntity.value(forKey: "id") as? UUID,
                          let name = resultEntity.value(forKey: "name") as? String,
                          let value = resultEntity.value(forKey: "value") as? Double,
                          let unit = resultEntity.value(forKey: "unit") as? String,
                          let referenceRange = resultEntity.value(forKey: "referenceRange") as? String,
                          let explanation = resultEntity.value(forKey: "explanation") as? String else {
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
                
                return BloodTest(
                    id: id,
                    date: date,
                    testType: testType,
                    results: results
                )
            }
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load test data: \(error.localizedDescription)"
        }
    }
    
    public func getResultColor(_ result: TestResult) -> Color {
        switch result.status {
        case .normal:
            return .green
        case .high:
            return .red
        case .low:
            return .blue
        }
    }
    
    // Helper method to get test history for a specific test type
    public func getTestHistory(for testType: String) -> [BloodTest] {
        return bloodTests.filter { $0.testType == testType }
            .sorted { $0.date > $1.date }
    }
    
    // Helper method to get the most recent test of a specific type
    public func getMostRecentTest(of testType: String) -> BloodTest? {
        return getTestHistory(for: testType).first
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

enum LabTestValue: Codable {
    case number(Double)
    case string(String)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let doubleValue = try? container.decode(Double.self) {
            self = .number(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(LabTestValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected number or string"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .number(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }
    
    var numericValue: Double? {
        switch self {
        case .number(let value):
            return value
        case .string(let value):
            return Double(value)
        }
    }
    
    var stringValue: String {
        switch self {
        case .number(let value):
            return String(value)
        case .string(let value):
            return value
        }
    }
} 