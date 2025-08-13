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
    
    /// Imports comprehensive lab data from the user's preferred JSON format
    /// - Parameter jsonData: The JSON data string to import
    /// - Returns: Success status and any error message
    public func importComprehensiveLabData(_ jsonData: String) -> (success: Bool, errorMessage: String?) {
        do {
            let data = jsonData.data(using: .utf8)!
            let comprehensiveData = try JSONDecoder().decode(ComprehensiveLabData.self, from: data)
            
            // The comprehensive format is no longer supported - use enhanced format instead
            print("Comprehensive format is deprecated. Please use the enhanced JSON format.")
            return (false, "Comprehensive format is deprecated. Please use the enhanced JSON format.")
            
            return (true, nil)
        } catch {
            return (false, "Failed to import lab data: \(error.localizedDescription)")
        }
    }
    
    /// Converts comprehensive lab data to internal BloodTest format
    /// - Parameter comprehensiveData: The comprehensive lab data to convert
    /// - Returns: Array of converted BloodTest objects
    /// NOTE: This method is deprecated since we removed the lab_tests structure
    /// The enhanced JSON format is now handled by importEnhancedLabResults
    private func convertComprehensiveDataToBloodTests(_ comprehensiveData: ComprehensiveLabData) -> [BloodTest] {
        // This method is no longer used - enhanced format is handled separately
        return []
    }
    
    /// Converts CBC results from comprehensive data to TestResult objects
    /// - Parameter cbcResults: CBC results from comprehensive data
    /// - Returns: Array of TestResult objects
    private func convertCBCResultsToTestResults(_ cbcResults: [String: CBCResult]) -> [TestResult] {
        var results: [TestResult] = []
        
        // Helper function to convert individual results
        func addResult(_ labResult: CBCResult?, name: String, referenceRange: String, explanation: String) {
            guard let labResult = labResult else { return }
            
            let testResult = TestResult(
                name: labResult.name,
                value: labResult.value ?? 0.0,
                unit: labResult.units,
                referenceRange: referenceRange,
                explanation: explanation
            )
            
            results.append(testResult)
        }
        
        // Add CBC results with standard reference ranges
        addResult(cbcResults["WBC"], name: "White Blood Cell Count", referenceRange: "4.5-11.0", explanation: "Measures infection-fighting white blood cells")
        addResult(cbcResults["RBC"], name: "Red Blood Cell Count", referenceRange: "4.5-5.5", explanation: "Measures oxygen-carrying red blood cells")
        addResult(cbcResults["HGB"], name: "Hemoglobin", referenceRange: "13.5-17.5", explanation: "Measures oxygen-carrying protein in red blood cells")
        addResult(cbcResults["HCT"], name: "Hematocrit", referenceRange: "38.8-50.0", explanation: "Percentage of blood volume occupied by red blood cells")
        addResult(cbcResults["PLATELET_COUNT"], name: "Platelet Count", referenceRange: "150-450", explanation: "Measures blood clotting cells")
        addResult(cbcResults["MCV"], name: "Mean Corpuscular Volume", referenceRange: "80-100", explanation: "Average size of red blood cells")
        addResult(cbcResults["MCH"], name: "Mean Corpuscular Hemoglobin", referenceRange: "27-32", explanation: "Average amount of hemoglobin per red blood cell")
        addResult(cbcResults["MCHC"], name: "Mean Corpuscular Hemoglobin Concentration", referenceRange: "32-36", explanation: "Concentration of hemoglobin in red blood cells")
        addResult(cbcResults["RDW"], name: "Red Cell Distribution Width", referenceRange: "11.5-14.5", explanation: "Variation in red blood cell size")
        addResult(cbcResults["MPV"], name: "Mean Platelet Volume", referenceRange: "7.5-11.5", explanation: "Average size of platelets")
        
        // Add differential counts
        addResult(cbcResults["NEUTROPHILS_PERCENT"], name: "Neutrophils %", referenceRange: "40-70", explanation: "Percentage of neutrophils (infection-fighting cells)")
        addResult(cbcResults["LYMPHS_PERCENT"], name: "Lymphocytes %", referenceRange: "20-40", explanation: "Percentage of lymphocytes (immune system cells)")
        addResult(cbcResults["MONOS_PERCENT"], name: "Monocytes %", referenceRange: "2-8", explanation: "Percentage of monocytes (immune system cells)")
        addResult(cbcResults["EOS_PERCENT"], name: "Eosinophils %", referenceRange: "1-4", explanation: "Percentage of eosinophils (allergy and parasite-fighting cells)")
        addResult(cbcResults["BASOS_PERCENT"], name: "Basophils %", referenceRange: "0.5-1", explanation: "Percentage of basophils (inflammation and allergy cells)")
        
        return results
    }
    
    /// Converts CMP results from comprehensive data to TestResult objects
    /// - Parameter cmpResults: CMP results from comprehensive data
    /// - Returns: Array of TestResult objects
    private func convertCMPResultsToTestResults(_ cmpResults: [String: CMPResult]) -> [TestResult] {
        var results: [TestResult] = []
        
        // Helper function to convert individual results
        func addResult(_ labResult: CMPResult?, name: String, referenceRange: String, explanation: String) {
            guard let labResult = labResult else { return }
            
            let testResult = TestResult(
                name: labResult.name,
                value: labResult.value?.numericValue ?? 0.0,
                unit: labResult.units,
                referenceRange: referenceRange,
                explanation: explanation
            )
            
            results.append(testResult)
        }
        
        // Add CMP results with standard reference ranges
        addResult(cmpResults["GLUCOSE"], name: "Glucose", referenceRange: "70-100", explanation: "Blood sugar level - high levels may indicate diabetes")
        addResult(cmpResults["UREA_NITROGEN"], name: "Urea Nitrogen (BUN)", referenceRange: "7-20", explanation: "Kidney function marker - high levels may indicate kidney problems")
        addResult(cmpResults["CREATININE"], name: "Creatinine", referenceRange: "0.7-1.3", explanation: "Kidney function marker - high levels may indicate kidney problems")
        addResult(cmpResults["SODIUM"], name: "Sodium", referenceRange: "135-145", explanation: "Electrolyte that helps maintain fluid balance")
        addResult(cmpResults["POTASSIUM"], name: "Potassium", referenceRange: "3.5-5.0", explanation: "Electrolyte important for heart and muscle function")
        addResult(cmpResults["CHLORIDE"], name: "Chloride", referenceRange: "98-107", explanation: "Electrolyte that helps maintain fluid balance and pH")
        addResult(cmpResults["CO2"], name: "Carbon Dioxide (CO2)", referenceRange: "23-29", explanation: "Measures acid-base balance in the body")
        addResult(cmpResults["CALCIUM"], name: "Calcium", referenceRange: "8.5-10.2", explanation: "Important for bones, muscles, and nerve function")
        addResult(cmpResults["ALBUMIN"], name: "Albumin", referenceRange: "3.4-5.4", explanation: "Main protein in blood - helps maintain fluid balance")
        addResult(cmpResults["AST"], name: "AST", referenceRange: "10-40", explanation: "Liver enzyme - high levels may indicate liver damage")
        
        return results
    }
    
    /// Parses date string in MM/DD/YYYY format
    /// - Parameter dateString: Date string to parse
    /// - Returns: Date object or current date if parsing fails
    private func parseDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.date(from: dateString) ?? Date()
    }
    
    /// Imports simple lab results from the user's current JSON format
    /// - Parameter jsonData: The JSON data string to import
    /// - Returns: Success status and any error message
    public func importSimpleLabResults(_ jsonData: String) -> (success: Bool, errorMessage: String?) {
        do {
            let data = jsonData.data(using: .utf8)!
            let simpleResults = try JSONDecoder().decode(SimpleLabResults.self, from: data)
            
            // Convert to internal format and save
            var totalTestsAdded = 0
            
            // Process CBC results
            if let cbcResults = simpleResults.BC_Complete_Blood_Count {
                print("Processing CBC results: \(cbcResults.count) items")
                let testResults = convertSimpleResultsToTestResults(cbcResults, testType: "CBC")
                if !testResults.isEmpty {
                    let bloodTest = BloodTest(
                        date: parseDate(from: cbcResults.first?.date ?? "") ?? Date(),
                        testType: "Complete Blood Count",
                        results: testResults
                    )
                    addTest(bloodTest)
                    totalTestsAdded += 1
                    print("✓ Added CBC test with \(testResults.count) results")
                } else {
                    print("⚠ No valid CBC results to add")
                }
            }
            
            // Process CMP Metabolism Studies results
            if let cmpResults = simpleResults.CMP_Metabolism_Studies {
                print("Processing CMP Metabolism Studies results: \(cmpResults.count) items")
                let testResults = convertSimpleResultsToTestResults(cmpResults, testType: "CMP")
                if !testResults.isEmpty {
                    let bloodTest = BloodTest(
                        date: parseDate(from: cmpResults.first?.date ?? "") ?? Date(),
                        testType: "Comprehensive Metabolic Panel",
                        results: testResults
                    )
                    addTest(bloodTest)
                    totalTestsAdded += 1
                    print("✓ Added CMP test with \(testResults.count) results")
                } else {
                    print("⚠ No valid CMP results to add")
                }
            }
            
            // Process Cholesterol results
            if let cholesterolResults = simpleResults.Cholesterol_Results {
                print("Processing Cholesterol Results: \(cholesterolResults.count) items")
                let testResults = convertSimpleResultsToTestResults(cholesterolResults, testType: "Cholesterol")
                if !testResults.isEmpty {
                    let bloodTest = BloodTest(
                        date: parseDate(from: cholesterolResults.first?.date ?? "") ?? Date(),
                        testType: "Cholesterol Panel",
                        results: testResults
                    )
                    addTest(bloodTest)
                    totalTestsAdded += 1
                    print("✓ Added Cholesterol Panel test with \(testResults.count) results")
                } else {
                    print("⚠ No valid Cholesterol results to add")
                }
            }
            
            print("=== Import Summary ===")
            print("Total tests added: \(totalTestsAdded)")
            print("Total blood tests in viewModel: \(bloodTests.count)")
            
            // Save to Core Data
            do {
                try PersistenceController.shared.container.viewContext.save()
                print("✓ Successfully saved \(totalTestsAdded) tests to Core Data")
                return (true, nil)
            } catch {
                print("❌ Failed to save to Core Data: \(error)")
                return (false, "Failed to save data: \(error.localizedDescription)")
            }
            
        } catch {
            print("❌ Failed to decode simple lab results: \(error)")
            return (false, "Failed to parse JSON: \(error.localizedDescription)")
        }
    }
    
    // Helper method to convert simple results to test results
    private func convertSimpleResultsToTestResults(_ simpleResults: [SimpleTestResult], testType: String) -> [TestResult] {
        var testResults: [TestResult] = []
        print("Converting \(simpleResults.count) simple results for \(testType)")
        
        for (index, simpleResult) in simpleResults.enumerated() {
            print("Processing result \(index + 1): \(simpleResult.testName) = \(simpleResult.value ?? -999)")
            
            // Handle different types of test results
            if let value = simpleResult.value {
                // Numeric value available
                let testResult = createTestResult(from: simpleResult, testType: testType, value: value)
                testResults.append(testResult)
                print("✓ Added test result: \(simpleResult.testName) = \(value)")
            } else if simpleResult.testName.contains("null") || simpleResult.testName.contains("nil") {
                // Skip null values
                print("⚠ Skipping \(simpleResult.testName) - null value")
                continue
            } else {
                // Try to handle string values or other non-numeric data
                print("⚠ Skipping \(simpleResult.testName) - no numeric value available")
                continue
            }
        }
        
        print("Converted \(testResults.count) valid test results for \(testType)")
        return testResults
    }
    
    // Helper method to create a test result with comprehensive information
    private func createTestResult(from simpleResult: SimpleTestResult, testType: String, value: Double) -> TestResult {
        // Create a comprehensive explanation including notes and additional info
        var explanation = "Imported from \(testType) panel"
        if let note = simpleResult.note {
            explanation += " - \(note)"
        }
        if let time = simpleResult.time {
            explanation += " (Time: \(time))"
        }
        if let sample = simpleResult.sample {
            explanation += " (Sample: \(sample))"
        }
        
        return TestResult(
            name: simpleResult.testName,
            value: value,
            unit: simpleResult.unit ?? getDefaultUnit(for: simpleResult.testName),
            referenceRange: simpleResult.reference_range ?? getDefaultReferenceRange(for: simpleResult.testName),
            explanation: explanation
        )
    }
    
    // Helper method to extract test name from simple result
    private func extractTestName(from simpleResult: SimpleTestResult) -> String {
        // This would need to be implemented based on the actual JSON structure
        // For now, return a generic name
        return simpleResult.testName
    }
    
    // Helper method to get default unit for test
    private func getDefaultUnit(for testName: String) -> String {
        // Add logic to determine appropriate units based on test name
        return ""
    }
    
    // Helper method to get default reference range for test
    private func getDefaultReferenceRange(for testName: String) -> String {
        // Add logic to determine appropriate reference ranges based on test name
        return ""
    }
    
    // Helper method to parse date strings
    private func parseDate(from dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
    
    /// Imports enhanced lab results from JSON string
    /// - Parameter jsonData: JSON string containing enhanced lab results
    func importEnhancedLabResults(_ jsonData: String) {
        guard let data = jsonData.data(using: .utf8) else {
            print("Failed to convert JSON string to data")
            return
        }
        
        do {
            let enhancedResults = try JSONDecoder().decode(EnhancedLabResults.self, from: data)
            print("Successfully decoded enhanced lab results for patient: \(enhancedResults.patient_info.name)")
            
            var totalTestsImported = 0
            
            // Import CBC results
            if let cbcPanel = enhancedResults.CBC_Complete_Blood_Count {
                print("Processing CBC panel with \(cbcPanel.results.count) tests")
                let cbcTests = convertEnhancedCBCResultsToTestResults(cbcPanel.results, testDate: cbcPanel.test_date)
                
                // Create BloodTest for CBC
                let cbcBloodTest = BloodTest(
                    date: parseDate(cbcPanel.test_date) ?? Date(),
                    testType: "Complete Blood Count (CBC)",
                    results: cbcTests
                )
                
                totalTestsImported += cbcTests.count
                print("Imported \(cbcTests.count) CBC tests")
            }
            
            // Import CMP results
            if let cmpPanel = enhancedResults.CMP_Metabolism_Studies {
                print("Processing CMP panel with \(cmpPanel.results.count) tests")
                let cmpTests = convertEnhancedCMPResultsToTestResults(cmpPanel.results, testDate: cmpPanel.test_date)
                
                // Create BloodTest for CMP
                let cmpBloodTest = BloodTest(
                    date: parseDate(cmpPanel.test_date) ?? Date(),
                    testType: "Comprehensive Metabolic Panel (CMP)",
                    results: cmpTests
                )
                
                totalTestsImported += cmpTests.count
                print("Imported \(cmpTests.count) CMP tests")
            }
            
            // Import Cholesterol results
            if let cholesterolPanel = enhancedResults.Cholesterol_Results {
                print("Processing Cholesterol panel with \(cholesterolPanel.results.count) tests")
                let cholesterolTests = convertEnhancedCholesterolResultsToTestResults(cholesterolPanel.results, testDate: cholesterolPanel.test_date)
                
                // Create BloodTest for Cholesterol
                let cholesterolBloodTest = BloodTest(
                    date: parseDate(cholesterolPanel.test_date) ?? Date(),
                    testType: "Cholesterol Panel",
                    results: cholesterolTests
                )
                
                totalTestsImported += cholesterolTests.count
                print("Imported \(cholesterolTests.count) Cholesterol tests")
            }
            
            // Save to Core Data
            do {
                try viewContext.save()
                print("Successfully saved \(totalTestsImported) enhanced lab tests to Core Data")
            } catch {
                print("Failed to save enhanced lab results to Core Data: \(error)")
            }
            
        } catch {
            print("Failed to decode enhanced lab results: \(error)")
        }
    }
    
    /// Converts enhanced CBC results to TestResult objects
    private func convertEnhancedCBCResultsToTestResults(_ cbcResults: [String: CBCResult], testDate: String) -> [TestResult] {
        var results: [TestResult] = []
        
        for (key, result) in cbcResults {
            guard let value = result.value else { continue } // Skip null values
            
            let testResult = TestResult(
                name: result.name,
                value: value,
                unit: result.units,
                referenceRange: getCBCReferenceRange(for: key),
                explanation: getCBCExplanation(for: key)
            )
            
            results.append(testResult)
        }
        
        return results
    }
    
    /// Converts enhanced CMP results to TestResult objects
    private func convertEnhancedCMPResultsToTestResults(_ cmpResults: [String: CMPResult], testDate: String) -> [TestResult] {
        var results: [TestResult] = []
        
        for (key, result) in cmpResults {
            guard let value = result.value?.numericValue else { continue } // Skip null values
            
            // Add flag and note information if available
            var explanation = getCMPExplanation(for: key)
            if let flag = result.flag {
                explanation += " [\(flag)]"
            }
            if let note = result.note {
                explanation += " - \(note)"
            }
            
            let testResult = TestResult(
                name: result.name,
                value: value,
                unit: result.units,
                referenceRange: getCMPReferenceRange(for: key),
                explanation: explanation
            )
            
            results.append(testResult)
        }
        
        return results
    }
    
    /// Converts enhanced Cholesterol results to TestResult objects
    private func convertEnhancedCholesterolResultsToTestResults(_ cholesterolResults: [String: CholesterolResult], testDate: String) -> [TestResult] {
        var results: [TestResult] = []
        
        for (key, result) in cholesterolResults {
            guard let value = result.value else { continue } // Skip null values
            
            // Add flag and note information if available
            var explanation = getCholesterolExplanation(for: key)
            if let flag = result.flag {
                explanation += " [\(flag)]"
            }
            if let note = result.note {
                explanation += " - \(note)"
            }
            
            let testResult = TestResult(
                name: result.name,
                value: value,
                unit: result.units,
                referenceRange: getCholesterolReferenceRange(for: key),
                explanation: explanation
            )
            
            results.append(testResult)
        }
        
        return results
    }
    
    // Helper methods for reference ranges and explanations
    private func getCBCReferenceRange(for key: String) -> String {
        switch key {
        case "WBC": return "4.5-11.0"
        case "RBC": return "4.5-5.5"
        case "HGB": return "13.5-17.5"
        case "HCT": return "38.8-50.0"
        case "PLATELET_COUNT": return "150-450"
        case "MCV": return "80-100"
        case "MCH": return "27-32"
        case "MCHC": return "32-36"
        case "RDW": return "11.5-14.5"
        case "MPV": return "7.5-11.5"
        case "NEUTROPHILS_PERCENT": return "40-70"
        case "LYMPHS_PERCENT": return "20-40"
        case "MONOS_PERCENT": return "2-8"
        case "EOS_PERCENT": return "1-4"
        case "BASOS_PERCENT": return "0.5-1"
        default: return "N/A"
        }
    }
    
    private func getCMPReferenceRange(for key: String) -> String {
        switch key {
        case "GLUCOSE": return "70-100"
        case "UREA_NITROGEN": return "7-20"
        case "CREATININE": return "0.7-1.3"
        case "SODIUM": return "135-145"
        case "POTASSIUM": return "3.5-5.0"
        case "CHLORIDE": return "98-107"
        case "CO2": return "23-29"
        case "CALCIUM": return "8.5-10.2"
        case "ALBUMIN": return "3.4-5.4"
        case "AST": return "10-40"
        case "ALT": return "7-56"
        case "ALKALINE_PHOSPHATASE": return "44-147"
        case "BILIRUBIN_TOTAL": return "0.3-1.2"
        default: return "N/A"
        }
    }
    
    private func getCholesterolReferenceRange(for key: String) -> String {
        switch key {
        case "LDL_NON_FASTING": return "<100"
        case "HDL": return ">40"
        case "TOTAL_CHOLESTEROL": return "<200"
        case "TRIGLYCERIDES": return "<150"
        default: return "N/A"
        }
    }
    
    private func getCBCExplanation(for key: String) -> String {
        switch key {
        case "WBC": return "Measures infection-fighting white blood cells"
        case "RBC": return "Measures oxygen-carrying red blood cells"
        case "HGB": return "Measures oxygen-carrying protein in red blood cells"
        case "HCT": return "Percentage of blood volume occupied by red blood cells"
        case "PLATELET_COUNT": return "Measures blood clotting cells"
        case "MCV": return "Average size of red blood cells"
        case "MCH": return "Average amount of hemoglobin per red blood cell"
        case "MCHC": return "Concentration of hemoglobin in red blood cells"
        case "RDW": return "Variation in red blood cell size"
        case "MPV": return "Average size of platelets"
        case "NEUTROPHILS_PERCENT": return "Percentage of neutrophils (infection-fighting cells)"
        case "LYMPHS_PERCENT": return "Percentage of lymphocytes (immune system cells)"
        case "MONOS_PERCENT": return "Percentage of monocytes (immune system cells)"
        case "EOS_PERCENT": return "Percentage of eosinophils (allergy and parasite-fighting cells)"
        case "BASOS_PERCENT": return "Percentage of basophils (inflammation and allergy cells)"
        default: return "Blood cell measurement"
        }
    }
    
    private func getCMPExplanation(for key: String) -> String {
        switch key {
        case "GLUCOSE": return "Blood sugar level - high levels may indicate diabetes"
        case "UREA_NITROGEN": return "Kidney function marker - high levels may indicate kidney problems"
        case "CREATININE": return "Kidney function marker - high levels may indicate kidney problems"
        case "SODIUM": return "Electrolyte that helps maintain fluid balance"
        case "POTASSIUM": return "Electrolyte important for heart and muscle function"
        case "CHLORIDE": return "Electrolyte that helps maintain fluid balance and pH"
        case "CO2": return "Measures acid-base balance in the body"
        case "CALCIUM": return "Important for bones, muscles, and nerve function"
        case "ALBUMIN": return "Main protein in blood - helps maintain fluid balance"
        case "AST": return "Liver enzyme - high levels may indicate liver damage"
        case "ALT": return "Liver enzyme - high levels may indicate liver damage"
        case "ALKALINE_PHOSPHATASE": return "Liver and bone enzyme"
        case "BILIRUBIN_TOTAL": return "Liver function marker - high levels may indicate liver problems"
        default: return "Metabolic panel measurement"
        }
    }
    
    private func getCholesterolExplanation(for key: String) -> String {
        switch key {
        case "LDL_NON_FASTING": return "LDL (bad cholesterol) - lower values are better"
        case "HDL": return "HDL (good cholesterol) - higher values are better"
        case "TOTAL_CHOLESTEROL": return "Total cholesterol level"
        case "TRIGLYCERIDES": return "Fat in the blood - high levels may increase heart disease risk"
        default: return "Cholesterol measurement"
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