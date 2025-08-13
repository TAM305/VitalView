import SwiftUI
import CoreData
import UniformTypeIdentifiers
import LocalAuthentication

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SettingsView: View {
    @ObservedObject var viewModel: BloodTestViewModel
    @State private var showingDeleteConfirmation = false
    @State private var showingExportSheet = false
    @State private var showingImportPicker = false
    @State private var exportData: Data?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isAuthenticated = false
    @State private var lastAuthenticationTime: Date?
    @State private var isBiometricAvailable = false
    @State private var showingPasscodeFallback = false
    @State private var showingAboutApp = false
    
    private let authenticationTimeout: TimeInterval = 300 // 5 minutes
    
    // App version information
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        isBiometricAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    private func authenticateWithPasscode(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication,
                                 localizedReason: "Access your blood test records") { success, error in
                DispatchQueue.main.async {
                    if success {
                        lastAuthenticationTime = Date()
                    }
                    completion(success)
                }
            }
        } else {
            if let error = error {
                alertMessage = "Authentication failed: \(error.localizedDescription)"
                showingAlert = true
            }
            completion(false)
        }
    }
    
    private func authenticateUser(completion: @escaping (Bool) -> Void) {
        // Check if we need to re-authenticate
        if let lastAuth = lastAuthenticationTime,
           Date().timeIntervalSince(lastAuth) < authenticationTimeout {
            completion(true)
            return
        }
        
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, 
                                 localizedReason: "Access your blood test records") { success, error in
                DispatchQueue.main.async {
                    if success {
                        lastAuthenticationTime = Date()
                        completion(true)
                    } else {
                        // If biometrics fail, show passcode fallback
                        showingPasscodeFallback = true
                        authenticateWithPasscode(completion: completion)
                    }
                }
            }
        } else {
            // If biometrics aren't available, use passcode
            authenticateWithPasscode(completion: completion)
        }
    }
    
    private func performAuthenticatedAction(_ action: @escaping () -> Void) {
        authenticateUser { success in
            if success {
                action()
            } else {
                showingAlert = true
                alertMessage = "Authentication failed. Please try again."
            }
        }
    }
    
    private func encodeData() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(viewModel.bloodTests)
            print("Successfully encoded \(viewModel.bloodTests.count) blood tests")
            return data
        } catch {
            print("Failed to encode blood tests: \(error)")
            alertMessage = "Failed to export data: \(error.localizedDescription)"
            showingAlert = true
            return nil
        }
    }
    
    private func importData(_ data: Data) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        print("=== Import Debug ===")
        print("Attempting to decode data of size: \(data.count)")
        
        // Try to get a preview of the JSON content
        if let jsonString = String(data: data, encoding: .utf8) {
            let previewLength = min(500, jsonString.count)
            let preview = String(jsonString.prefix(previewLength))
            print("JSON preview (first \(previewLength) characters):")
            print(preview)
            if jsonString.count > previewLength {
                print("... (truncated)")
            }
        }
        
        // First try to decode as enhanced lab results format (most comprehensive)
        do {
            let enhancedResults = try decoder.decode(EnhancedLabResults.self, from: data)
            print("Successfully decoded as enhanced lab results format")
            importEnhancedLabResults(enhancedResults)
            alertMessage = "Enhanced lab results imported successfully"
            return
        } catch {
            print("Failed to decode as enhanced lab results format: \(error)")
        }
        
        // If that fails, try to decode as standard BloodTest format
        do {
            let tests = try decoder.decode([BloodTest].self, from: data)
            print("Successfully decoded as standard BloodTest format: \(tests.count) tests")
            for test in tests {
                viewModel.addTest(test)
            }
            alertMessage = "Data imported successfully"
            return
        } catch {
            print("Failed to decode as standard BloodTest format: \(error)")
        }
        
        // If that fails, try to decode as comprehensive health data format
        do {
            let healthData = try decoder.decode(ComprehensiveHealthData.self, from: data)
            print("Successfully decoded as comprehensive health data format")
            importComprehensiveHealthData(healthData)
            alertMessage = "Comprehensive health data imported successfully"
            return
        } catch {
            print("Failed to decode as comprehensive health data format: \(error)")
            print("Error details: \(error.localizedDescription)")
            
            // Try to get more specific error information
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("Missing key: \(key.stringValue) at path: \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    print("Type mismatch: expected \(type) at path: \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("Value not found: expected \(type) at path: \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("Data corrupted at path: \(context.codingPath)")
                @unknown default:
                    print("Unknown decoding error")
                }
            }
        }
        
        // If that fails, try to decode as VA lab format
        do {
            let vaLabData = try decoder.decode(VALabData.self, from: data)
            print("Successfully decoded as enhanced lab results format")
            importVALabData(vaLabData)
            alertMessage = "VA Lab data imported successfully"
            return
        } catch {
            print("Failed to decode as VA lab format: \(error)")
        }
        
        // If that fails, try to decode as simple lab results format
        do {
            let simpleResults = try decoder.decode(SimpleLabResults.self, from: data)
            print("Successfully decoded as simple lab results format")
            importSimpleLabResults(simpleResults)
            alertMessage = "Simple lab results imported successfully"
            return
        } catch {
            print("Failed to decode as simple lab results format: \(error)")
        }
        
        // If that fails, try to decode as comprehensive lab data format
        do {
            let comprehensiveData = try decoder.decode(ComprehensiveLabData.self, from: data)
            print("Successfully decoded as comprehensive lab data format")
            importComprehensiveLabData(comprehensiveData)
            alertMessage = "Comprehensive lab data imported successfully"
            return
        } catch {
            print("Failed to decode as comprehensive lab data format: \(error)")
        }
        
        // If all fail, show error
        print("Failed to decode data in any format")
        alertMessage = "Failed to import data: Unsupported format"
    }
    
    private func importVALabData(_ vaData: VALabData) {
        print("=== Starting VA Lab Import ===")
        print("Facility: \(vaData.healthcare_facility.name)")
        print("Patient: \(vaData.patient.name)")
        print("Report date: \(vaData.report.date)")
        print("Has CBC: \(vaData.lab_tests.cbc != nil)")
        print("Has CMP: \(vaData.lab_tests.cmp != nil)")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy"
        
        var totalTestsAdded = 0
        
        // Import CBC data
        if let cbcData = vaData.lab_tests.cbc {
            print("=== Processing CBC Data ===")
            print("CBC test date: \(cbcData.test_date)")
            let cbcDate = dateFormatter.date(from: cbcData.test_date) ?? Date()
            print("Parsed CBC date: \(cbcDate)")
            
            var cbcResults: [TestResult] = []
            
            // Convert CBC results
            if let wbc = cbcData.results.wbc?.value {
                cbcResults.append(TestResult(
                    name: "White Blood Cell Count",
                    value: wbc,
                    unit: cbcData.results.wbc?.units ?? "K/uL",
                    referenceRange: "4.5-11.0",
                    explanation: "White Blood Cell Count - measures immune system cells"
                ))
                print("Added WBC: \(wbc)")
            } else {
                print("WBC value is nil")
            }
            
            if let rbc = cbcData.results.rbc?.value {
                cbcResults.append(TestResult(
                    name: "Red Blood Cell Count",
                    value: rbc,
                    unit: cbcData.results.rbc?.units ?? "M/uL",
                    referenceRange: "4.5-5.9",
                    explanation: "Red Blood Cell Count - measures oxygen-carrying cells"
                ))
                print("Added RBC: \(rbc)")
            } else {
                print("RBC value is nil")
            }
            
            if let hgb = cbcData.results.hgb?.value {
                cbcResults.append(TestResult(
                    name: "Hemoglobin",
                    value: hgb,
                    unit: cbcData.results.hgb?.units ?? "g/dL",
                    referenceRange: "13.5-17.5",
                    explanation: "Hemoglobin - measures oxygen-carrying protein"
                ))
                print("Added Hemoglobin: \(hgb)")
            } else {
                print("Hemoglobin value is nil")
            }
            
            if let hct = cbcData.results.hct?.value {
                cbcResults.append(TestResult(
                    name: "Hematocrit",
                    value: hct,
                    unit: cbcData.results.hct?.units ?? "%",
                    referenceRange: "41.0-50.0",
                    explanation: "Hematocrit - percentage of blood volume occupied by red cells"
                ))
                print("Added Hematocrit: \(hct)")
            } else {
                print("Hematocrit value is nil")
            }
            
            if let platelets = cbcData.results.platelet_count?.value {
                cbcResults.append(TestResult(
                    name: "Platelets",
                    value: platelets,
                    unit: cbcData.results.platelet_count?.units ?? "K/uL",
                    referenceRange: "150-450",
                    explanation: "Platelet Count - measures clotting cells"
                ))
                print("Added Platelets: \(platelets)")
            } else {
                print("Platelets value is nil")
            }
            
            if let neutrophils = cbcData.results.neutrophils_percent?.value {
                cbcResults.append(TestResult(
                    name: "Neutrophils %",
                    value: neutrophils,
                    unit: cbcData.results.neutrophils_percent?.units ?? "%",
                    referenceRange: "40.0-70.0",
                    explanation: "Neutrophils Percentage - measures infection-fighting cells"
                ))
                print("Added Neutrophils %: \(neutrophils)")
            } else {
                print("Neutrophils % value is nil")
            }
            
            if let lymphs = cbcData.results.lymphs_percent?.value {
                cbcResults.append(TestResult(
                    name: "Lymphocytes %",
                    value: lymphs,
                    unit: cbcData.results.lymphs_percent?.units ?? "%",
                    referenceRange: "20.0-40.0",
                    explanation: "Lymphocytes Percentage - measures immune system cells"
                ))
                print("Added Lymphocytes %: \(lymphs)")
            } else {
                print("Lymphocytes % value is nil")
            }
            
            if let monocytes = cbcData.results.monos_percent?.value {
                cbcResults.append(TestResult(
                    name: "Monocytes %",
                    value: monocytes,
                    unit: cbcData.results.monos_percent?.units ?? "%",
                    referenceRange: "2.0-8.0",
                    explanation: "Monocytes Percentage - measures immune system cells"
                ))
                print("Added Monocytes %: \(monocytes)")
            } else {
                print("Monocytes % value is nil")
            }
            
            if let eosinophils = cbcData.results.eos_percent?.value {
                cbcResults.append(TestResult(
                    name: "Eosinophils %",
                    value: eosinophils,
                    unit: cbcData.results.eos_percent?.units ?? "%",
                    referenceRange: "1.0-4.0",
                    explanation: "Eosinophils Percentage - measures allergy/infection response"
                ))
                print("Added Eosinophils %: \(eosinophils)")
            } else {
                print("Eosinophils % value is nil")
            }
            
            if let basophils = cbcData.results.basos_percent?.value {
                cbcResults.append(TestResult(
                    name: "Basophils %",
                    value: basophils,
                    unit: cbcData.results.basos_percent?.units ?? "%",
                    referenceRange: "0.5-1.0",
                    explanation: "Basophils Percentage - measures inflammatory response"
                ))
                print("Added Basophils %: \(basophils)")
            } else {
                print("Basophils % value is nil")
            }
            
            print("CBC results count: \(cbcResults.count)")
            if !cbcResults.isEmpty {
                let cbcTest = BloodTest(
                    date: cbcDate,
                    testType: "CBC",
                    results: cbcResults
                )
                viewModel.addTest(cbcTest)
                totalTestsAdded += 1
                print("Added CBC test with \(cbcResults.count) results")
            } else {
                print("No CBC results to add!")
            }
        } else {
            print("No CBC data found in VA lab results")
        }
        
        // Import CMP data
        if let cmpData = vaData.lab_tests.cmp {
            print("=== Processing CMP Data ===")
            print("CMP test date: \(cmpData.test_date)")
            let cmpDate = dateFormatter.date(from: cmpData.test_date) ?? Date()
            print("Parsed CMP date: \(cmpDate)")
            
            var cmpResults: [TestResult] = []
            
            // Convert CMP results
            if let glucose = cmpData.results.glucose?.value {
                cmpResults.append(TestResult(
                    name: "Glucose",
                    value: glucose,
                    unit: cmpData.results.glucose?.units ?? "mg/dL",
                    referenceRange: "70-100",
                    explanation: "Glucose - measures blood sugar levels"
                ))
                print("Added Glucose: \(glucose)")
            } else {
                print("Glucose value is nil")
            }
            
            if let bun = cmpData.results.urea_nitrogen?.value {
                cmpResults.append(TestResult(
                    name: "Urea Nitrogen",
                    value: bun,
                    unit: cmpData.results.urea_nitrogen?.units ?? "mg/dL",
                    referenceRange: "7-20",
                    explanation: "Urea Nitrogen (BUN) - measures kidney function"
                ))
                print("Added Urea Nitrogen: \(bun)")
            } else {
                print("Urea Nitrogen value is nil")
            }
            
            if let creatinine = cmpData.results.creatinine?.value {
                cmpResults.append(TestResult(
                    name: "Creatinine",
                    value: creatinine,
                    unit: cmpData.results.creatinine?.units ?? "mg/dL",
                    referenceRange: "0.7-1.3",
                    explanation: "Creatinine - measures kidney function"
                ))
                print("Added Creatinine: \(creatinine)")
            } else {
                print("Creatinine value is nil")
            }
            
            if let sodium = cmpData.results.sodium?.value {
                cmpResults.append(TestResult(
                    name: "Sodium",
                    value: sodium,
                    unit: cmpData.results.sodium?.units ?? "mmol/L",
                    referenceRange: "135-145",
                    explanation: "Sodium - measures electrolyte balance"
                ))
                print("Added Sodium: \(sodium)")
            } else {
                print("Sodium value is nil")
            }
            
            if let potassium = cmpData.results.potassium?.value {
                cmpResults.append(TestResult(
                    name: "Potassium",
                    value: potassium,
                    unit: cmpData.results.potassium?.units ?? "mmol/L",
                    referenceRange: "3.5-5.0",
                    explanation: "Potassium - measures electrolyte balance"
                ))
                print("Added Potassium: \(potassium)")
            } else {
                print("Potassium value is nil")
            }
            
            if let chloride = cmpData.results.chloride?.value {
                cmpResults.append(TestResult(
                    name: "Chloride",
                    value: chloride,
                    unit: cmpData.results.chloride?.units ?? "mmol/L",
                    referenceRange: "96-106",
                    explanation: "Chloride - measures electrolyte balance"
                ))
                print("Added Chloride: \(chloride)")
            } else {
                print("Chloride value is nil")
            }
            
            if let co2 = cmpData.results.co2?.value {
                cmpResults.append(TestResult(
                    name: "CO2",
                    value: co2,
                    unit: cmpData.results.co2?.units ?? "mmol/L",
                    referenceRange: "22-28",
                    explanation: "Carbon Dioxide - measures acid-base balance"
                ))
                print("Added CO2: \(co2)")
            } else {
                print("CO2 value is nil")
            }
            
            if let calcium = cmpData.results.calcium?.value {
                cmpResults.append(TestResult(
                    name: "Calcium",
                    value: calcium,
                    unit: cmpData.results.calcium?.units ?? "mg/dL",
                    referenceRange: "8.5-10.5",
                    explanation: "Calcium - measures bone and muscle function"
                ))
                print("Added Calcium: \(calcium)")
            } else {
                print("Calcium value is nil")
            }
            
            if let albumin = cmpData.results.albumin?.value {
                cmpResults.append(TestResult(
                    name: "Albumin",
                    value: albumin,
                    unit: cmpData.results.albumin?.units ?? "g/dL",
                    referenceRange: "3.5-5.0",
                    explanation: "Albumin - measures protein levels and liver function"
                ))
                print("Added Albumin: \(albumin)")
            } else {
                print("Albumin value is nil")
            }
            
            if let ast = cmpData.results.ast?.value {
                cmpResults.append(TestResult(
                    name: "AST",
                    value: ast,
                    unit: cmpData.results.ast?.units ?? "U/L",
                    referenceRange: "10-40",
                    explanation: "AST - measures liver function"
                ))
                print("Added AST: \(ast)")
            } else {
                print("AST value is nil")
            }
            
            print("CMP results count: \(cmpResults.count)")
            if !cmpResults.isEmpty {
                let cmpTest = BloodTest(
                    date: cmpDate,
                    testType: "CMP",
                    results: cmpResults
                )
                viewModel.addTest(cmpTest)
                totalTestsAdded += 1
                print("Added CMP test with \(cmpResults.count) results")
            } else {
                print("No CMP results to add!")
            }
        } else {
            print("No CMP data found in VA lab results")
        }
        
        print("=== VA Lab Import Complete ===")
        print("Total tests added: \(totalTestsAdded)")
        print("Current bloodTests count: \(viewModel.bloodTests.count)")
    }
    
    private func importComprehensiveHealthData(_ healthData: ComprehensiveHealthData) {
        print("=== Starting Comprehensive Health Data Import ===")
        print("Patient: \(healthData.patient.name)")
        print("Has clinical vitals: \(healthData.clinical_vitals?.count ?? 0)")
        print("Has lab results: \(healthData.lab_results?.count ?? 0)")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy"
        dateFormatter.locale = Locale(identifier: "en_US") // Ensure English month abbreviations
        
        var totalTestsAdded = 0
        
        // Import lab results
        if let labResults = healthData.lab_results {
            print("=== Processing Lab Results ===")
            print("Total lab results to process: \(labResults.count)")
            
            for (index, labResult) in labResults.enumerated() {
                print("=== Processing Lab Result \(index + 1)/\(labResults.count) ===")
                print("Raw date string: '\(labResult.date)'")
                
                let labDate = dateFormatter.date(from: labResult.date)
                if let labDate = labDate {
                    print("Successfully parsed date: \(labDate)")
                } else {
                    print("FAILED to parse date: '\(labResult.date)'")
                    print("Trying alternative date formats...")
                    
                    // Try alternative date formats
                    let alternativeFormats = ["MMM dd, yyyy", "MMM d, yyyy", "MMM dd yyyy", "MMM d yyyy"]
                    var parsedDate: Date?
                    
                    for format in alternativeFormats {
                        let altFormatter = DateFormatter()
                        altFormatter.dateFormat = format
                        altFormatter.locale = Locale(identifier: "en_US")
                        if let date = altFormatter.date(from: labResult.date) {
                            parsedDate = date
                            print("Successfully parsed with format '\(format)': \(date)")
                            break
                        }
                    }
                    
                    if let parsedDate = parsedDate {
                        print("Using alternative parsed date: \(parsedDate)")
                        // Continue with the parsed date
                    } else {
                        print("All date parsing attempts failed for: '\(labResult.date)'")
                        print("Skipping this lab result")
                        continue
                    }
                }
                
                print("Tests in this lab result: \(labResult.tests.count)")
                var testResults: [TestResult] = []
                
                for (testIndex, test) in labResult.tests.enumerated() {
                    print("Processing test \(testIndex + 1)/\(labResult.tests.count): '\(test.name)'")
                    print("Test value: \(test.value?.stringValue ?? "nil")")
                    print("Test unit: \(test.unit ?? "nil")")
                    print("Test reference range: \(test.reference_range ?? "nil")")
                    
                    if let numericValue = test.value?.numericValue {
                        // Create test result with numeric value
                        let testResult = TestResult(
                            name: test.name,
                            value: numericValue,
                            unit: test.unit ?? "",
                            referenceRange: test.reference_range ?? "",
                            explanation: "Imported from comprehensive health data"
                        )
                        testResults.append(testResult)
                        print("✓ Added numeric test result: \(test.name) = \(numericValue)")
                    } else if let stringValue = test.value?.stringValue, stringValue != "Unknown" {
                        // For non-numeric values that aren't "Unknown", try to convert to number if possible
                        if let convertedValue = Double(stringValue) {
                            let testResult = TestResult(
                                name: test.name,
                                value: convertedValue,
                                unit: test.unit ?? "",
                                referenceRange: test.reference_range ?? "",
                                explanation: "Imported from comprehensive health data"
                            )
                            testResults.append(testResult)
                            print("✓ Added converted test result: \(test.name) = \(convertedValue)")
                        } else {
                            print("⚠ Skipping non-numeric test: \(test.name) = \(stringValue)")
                        }
                    } else {
                        print("⚠ Skipping test with no valid value: \(test.name)")
                    }
                }
                
                print("Valid test results for this date: \(testResults.count)")
                if !testResults.isEmpty {
                    let bloodTest = BloodTest(
                        date: labDate ?? Date(),
                        testType: "Comprehensive",
                        results: testResults
                    )
                    print("Creating BloodTest with \(testResults.count) results for date \(labResult.date)")
                    
                    viewModel.addTest(bloodTest)
                    totalTestsAdded += 1
                    print("✓ Added comprehensive test with \(testResults.count) results for date \(labResult.date)")
                    print("Current total tests in viewModel: \(viewModel.bloodTests.count)")
                } else {
                    print("⚠ No valid test results for date \(labResult.date)")
                }
            }
        } else {
            print("No lab results found in comprehensive health data")
        }
        
        print("=== Comprehensive Health Data Import Complete ===")
        print("Total tests added: \(totalTestsAdded)")
        print("Final bloodTests count in viewModel: \(viewModel.bloodTests.count)")
        
        // Force a save to Core Data
        do {
            try PersistenceController.shared.container.viewContext.save()
            print("✓ Successfully saved to Core Data")
        } catch {
            print("❌ Failed to save to Core Data: \(error)")
        }
    }
    
    private func importComprehensiveLabData(_ comprehensiveData: ComprehensiveLabData) {
        print("=== Starting Comprehensive Lab Data Import ===")
        print("Facility: \(comprehensiveData.healthcare_facility.name)")
        print("Patient: \(comprehensiveData.patient.name)")
        print("Report date: \(comprehensiveData.report.date)")
        // Removed lab_tests reference since it was deleted
        print("Comprehensive lab data imported successfully")
        
        // Convert back to JSON string and use the viewModel's import method
        do {
            let jsonData = try JSONEncoder().encode(comprehensiveData)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            let result = viewModel.importComprehensiveLabData(jsonString)
            
            if result.success {
                print("✓ Comprehensive lab data imported successfully")
            } else {
                print("❌ Failed to import comprehensive lab data: \(result.errorMessage ?? "Unknown error")")
            }
        } catch {
            print("❌ Failed to encode comprehensive data: \(error)")
        }
    }
    
    private func importSimpleLabResults(_ simpleResults: SimpleLabResults) {
        print("=== Starting Simple Lab Results Import ===")
        
        // Convert back to JSON string and use the viewModel's import method
        do {
            let jsonData = try JSONEncoder().encode(simpleResults)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            let result = viewModel.importSimpleLabResults(jsonString)
            
            if result.success {
                print("✓ Simple lab results imported successfully")
            } else {
                print("❌ Failed to import simple lab results: \(result.errorMessage ?? "Unknown error")")
            }
        } catch {
            print("❌ Failed to encode simple results: \(error)")
        }
    }
    
    private func importEnhancedLabResults(_ enhancedResults: EnhancedLabResults) {
        print("=== Starting Enhanced Lab Results Import ===")
        print("Patient: \(enhancedResults.patient_info.name)")
        print("Test Date: \(enhancedResults.patient_info.test_date)")
        print("Facility: \(enhancedResults.patient_info.facility)")
        
        // Convert the enhanced results to JSON string and pass to viewModel
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(enhancedResults)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            
            // Call the viewModel method to import the enhanced lab results
            viewModel.importEnhancedLabResults(jsonString)
            
            print("Enhanced lab results import completed successfully")
        } catch {
            print("Failed to encode enhanced lab results: \(error)")
            alertMessage = "Failed to import enhanced lab results: \(error.localizedDescription)"
        }
    }
    
    private func deleteAllData() {
        for test in viewModel.bloodTests {
            viewModel.deleteTest(test)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    if isBiometricAvailable {
                        Button(action: {
                            performAuthenticatedAction {
                                showingDeleteConfirmation = true
                            }
                        }) {
                            Label("Delete All Data", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                        
                        Button(action: {
                            performAuthenticatedAction {
                                if let data = encodeData() {
                                    exportData = data
                                    showingExportSheet = true
                                }
                            }
                        }) {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: {
                            performAuthenticatedAction {
                                showingImportPicker = true
                            }
                        }) {
                            Label("Import Data", systemImage: "square.and.arrow.down")
                        }
                    } else {
                        Text("Biometric authentication is required for data management")
                            .foregroundColor(.secondary)
                            .font(.footnote)
                    }
                } header: {
                    Text("Data Management")
                }
                
                Section {
                    NavigationLink(destination: PrivacyView()) {
                        Label("Privacy Policy", systemImage: "lock.shield")
                    }
                } header: {
                    Text("Privacy")
                }
                
                Section {
                    Button(action: { showingAboutApp = true }) {
                        Label("About VitalVu", systemImage: "info.circle")
                    }
                    
                    HStack {
                        Label("Version", systemImage: "tag")
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("App Information")
                }
            }
            .navigationTitle("Settings")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                checkBiometricAvailability()
            }
            .alert("Delete All Data", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAllData()
                    viewModel.loadTests()
                }
            } message: {
                Text("Are you sure you want to delete all your blood test data? This action cannot be undone.")
            }
            .alert("Export Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingExportSheet) {
                if let data = exportData {
                    ShareSheet(items: [data])
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("No Data to Export")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("There are no blood tests available to export.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("OK") {
                            showingExportSheet = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .sheet(isPresented: $showingAboutApp) {
                NavigationView {
                    AboutAppView()
                }
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    
                    // Start accessing the security-scoped resource
                    guard url.startAccessingSecurityScopedResource() else {
                        showingAlert = true
                        alertMessage = "Failed to access the selected file"
                        return
                    }
                    
                    defer {
                        // Stop accessing the security-scoped resource when done
                        url.stopAccessingSecurityScopedResource()
                    }
                    
                    do {
                        let data = try Data(contentsOf: url)
                        importData(data)
                        showingAlert = true
                        alertMessage = "Data imported successfully"
                    } catch {
                        showingAlert = true
                        alertMessage = "Failed to import data: \(error.localizedDescription)"
                    }
                    
                case .failure(let error):
                    showingAlert = true
                    alertMessage = "Failed to select file: \(error.localizedDescription)"
                }
            }
            .alert("Import Result", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - About App View
struct AboutAppView: View {
    @Environment(\.dismiss) private var dismiss
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // App Header
                VStack(spacing: 16) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    Text("VitalVu")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your personal health companion")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                
                // App Description
                VStack(alignment: .leading, spacing: 16) {
                    Text("About")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("VitalVu is a comprehensive health monitoring app that helps you track and understand your vital signs and blood test results. The app integrates with Apple HealthKit to provide real-time health metrics and offers detailed analysis of your blood work.")
                        .font(.body)
                        .lineSpacing(4)
                }
                
                // Features
                VStack(alignment: .leading, spacing: 16) {
                    Text("Key Features")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(icon: "heart.fill", title: "Vital Signs Monitoring", description: "Track heart rate, blood pressure, oxygen saturation, and more through HealthKit integration")
                        
                        FeatureRow(icon: "drop.fill", title: "Blood Test Analysis", description: "Enter and analyze blood test results with automatic reference range validation")
                        
                        FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Trend Analysis", description: "Visualize your health data over time with interactive charts and trend analysis")
                        
                        FeatureRow(icon: "lock.shield", title: "Privacy First", description: "All data stored locally with biometric authentication for maximum security")
                        
                        FeatureRow(icon: "square.and.arrow.up", title: "Data Export", description: "Export your health data for backup or sharing with healthcare providers")
                    }
                }
                
                // Technical Information
                VStack(alignment: .leading, spacing: 16) {
                    Text("Technical Information")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(title: "Platform", value: "iOS 15.0+")
                        InfoRow(title: "Framework", value: "SwiftUI")
                        InfoRow(title: "Health Integration", value: "HealthKit")
                        InfoRow(title: "Data Storage", value: "Core Data")
                        InfoRow(title: "Authentication", value: "Local Authentication")
                    }
                }
                
                // Privacy Notice
                VStack(alignment: .leading, spacing: 16) {
                    Text("Privacy & Security")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Your health data is stored locally on your device and is never transmitted to external servers. The app uses Apple's HealthKit framework to access health data only with your explicit permission. All data management features require biometric authentication for added security.")
                        .font(.body)
                        .lineSpacing(4)
                }
                
                // Support
                VStack(alignment: .leading, spacing: 16) {
                    Text("Support")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("For support, feature requests, or bug reports, please contact us through the App Store review system or your preferred support channel.")
                        .font(.body)
                        .lineSpacing(4)
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Helper Views
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
} 
