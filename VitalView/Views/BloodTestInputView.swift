import SwiftUI

struct BloodTestInputView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTestType = "CBC"
    @State private var testDate = Date()
    @State private var testValues: [String: String] = [:]
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    let onSave: (BloodTest) -> Void
    
    // Test categories and their components
    let testCategories = [
        "CBC": [
            "WBC", "RBC", "HGB", "HCT", "MCV", "MCH", "MCHC", "RDW", 
            "Platelets", "MPV", "Neutrophils %", "Lymphs %", "Monos %", 
            "EOS %", "BASOS %"
        ],
        "CMP": [
            "Glucose", "Urea Nitrogen", "Creatinine", "eGFR", "Sodium", 
            "Potassium", "Chloride", "CO2", "Anion Gap", "Calcium", 
            "Total Protein", "Albumin", "AST", "ALT", "Alkaline Phosphatase", 
            "Bilirubin Total"
        ],
        "Lipid Panel": [
            "Total Cholesterol", "HDL", "LDL", "Triglycerides"
        ],
        "Thyroid": [
            "TSH", "T4", "T3", "Free T4", "Free T3"
        ],
        "Diabetes": [
            "HbA1c", "Glucose", "Insulin", "C-Peptide"
        ]
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    // Test type selector
                    Picker("Test Type", selection: $selectedTestType) {
                        ForEach(Array(testCategories.keys), id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Date picker
                    DatePicker("Test Date", selection: $testDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .padding(.horizontal)
                }
                .padding(.top)
                .background(Color(.systemBackground))
                
                // Test values input
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(testCategories[selectedTestType] ?? [], id: \.self) { test in
                            TestValueRow(
                                testName: test,
                                value: Binding(
                                    get: { testValues[test] ?? "" },
                                    set: { testValues[test] = $0 }
                                )
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Blood Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTest()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func saveTest() {
        // Validate required fields
        guard !testValues.isEmpty else {
            alertMessage = "Please enter at least one test value"
            showingAlert = true
            return
        }
        
        // Create test results
        var results: [TestResult] = []
        for (testName, value) in testValues {
            if !value.isEmpty {
                let result = TestResult(
                    name: testName,
                    value: Double(value) ?? 0.0,
                    unit: getUnit(for: testName),
                    referenceRange: getReferenceRange(for: testName),
                    explanation: getExplanation(for: testName)
                )
                results.append(result)
            }
        }
        
        // Create blood test
        let bloodTest = BloodTest(
            date: testDate,
            testType: selectedTestType,
            results: results
        )
        
        onSave(bloodTest)
        dismiss()
    }
    
    private func getUnit(for testName: String) -> String {
        switch testName {
        case "WBC", "RBC", "Platelets", "Neutrophils #", "Lymphs #", "Monos #", "EOS #", "BASOS #":
            return "K/µL"
        case "HGB":
            return "g/dL"
        case "HCT", "Neutrophils %", "Lymphs %", "Monos %", "EOS %", "BASOS %":
            return "%"
        case "MCV":
            return "fL"
        case "MCH":
            return "pg"
        case "MCHC":
            return "g/dL"
        case "RDW":
            return "%"
        case "MPV":
            return "fL"
        case "Glucose":
            return "mg/dL"
        case "Urea Nitrogen":
            return "mg/dL"
        case "Creatinine":
            return "mg/dL"
        case "eGFR":
            return "mL/min/1.73m²"
        case "Sodium", "Potassium", "Chloride", "CO2", "Anion Gap":
            return "mEq/L"
        case "Calcium":
            return "mg/dL"
        case "Total Protein", "Albumin":
            return "g/dL"
        case "AST", "ALT", "Alkaline Phosphatase":
            return "U/L"
        case "Bilirubin Total":
            return "mg/dL"
        case "Total Cholesterol", "HDL", "LDL", "Triglycerides":
            return "mg/dL"
        case "TSH":
            return "µIU/mL"
        case "T4", "T3", "Free T4", "Free T3":
            return "ng/dL"
        case "HbA1c":
            return "%"
        case "Insulin", "C-Peptide":
            return "µIU/mL"
        default:
            return ""
        }
    }
    
    private func getReferenceRange(for testName: String) -> String {
        switch testName {
        case "WBC":
            return "4.5-11.0 K/µL"
        case "RBC":
            return "4.5-5.9 M/µL"
        case "HGB":
            return "13.5-17.5 g/dL"
        case "HCT":
            return "41.0-50.0%"
        case "MCV":
            return "80-100 fL"
        case "MCH":
            return "27-33 pg"
        case "MCHC":
            return "32-36 g/dL"
        case "RDW":
            return "11.5-14.5%"
        case "Platelets":
            return "150-450 K/µL"
        case "MPV":
            return "7.5-11.5 fL"
        case "Glucose":
            return "70-100 mg/dL"
        case "Urea Nitrogen":
            return "7-20 mg/dL"
        case "Creatinine":
            return "0.7-1.3 mg/dL"
        case "eGFR":
            return ">60 mL/min/1.73m²"
        case "Sodium":
            return "135-145 mEq/L"
        case "Potassium":
            return "3.5-5.0 mEq/L"
        case "Chloride":
            return "96-106 mEq/L"
        case "CO2":
            return "22-28 mEq/L"
        case "Anion Gap":
            return "8-16 mEq/L"
        case "Calcium":
            return "8.5-10.5 mg/dL"
        case "Total Protein":
            return "6.0-8.3 g/dL"
        case "Albumin":
            return "3.5-5.0 g/dL"
        case "AST":
            return "10-40 U/L"
        case "ALT":
            return "7-56 U/L"
        case "Alkaline Phosphatase":
            return "44-147 U/L"
        case "Bilirubin Total":
            return "0.3-1.2 mg/dL"
        case "Total Cholesterol":
            return "<200 mg/dL"
        case "HDL":
            return ">40 mg/dL"
        case "LDL":
            return "<100 mg/dL"
        case "Triglycerides":
            return "<150 mg/dL"
        case "TSH":
            return "0.4-4.0 µIU/mL"
        case "T4":
            return "5.0-12.0 µg/dL"
        case "T3":
            return "80-200 ng/dL"
        case "Free T4":
            return "0.8-1.8 ng/dL"
        case "Free T3":
            return "2.3-4.2 pg/mL"
        case "HbA1c":
            return "<5.7%"
        case "Insulin":
            return "3-25 µIU/mL"
        case "C-Peptide":
            return "0.8-3.1 ng/mL"
        default:
            return ""
        }
    }
    
    private func getExplanation(for testName: String) -> String {
        switch testName {
        case "WBC":
            return "White blood cell count measures your body's ability to fight infections"
        case "RBC":
            return "Red blood cell count indicates oxygen-carrying capacity"
        case "HGB":
            return "Hemoglobin measures the oxygen-carrying protein in red blood cells"
        case "HCT":
            return "Hematocrit shows the percentage of blood volume occupied by red cells"
        case "MCV":
            return "Mean corpuscular volume indicates average red blood cell size"
        case "MCH":
            return "Mean corpuscular hemoglobin measures average hemoglobin per red cell"
        case "MCHC":
            return "Mean corpuscular hemoglobin concentration shows hemoglobin density"
        case "RDW":
            return "Red cell distribution width measures variation in red cell size"
        case "Platelets":
            return "Platelet count measures blood clotting ability"
        case "MPV":
            return "Mean platelet volume indicates average platelet size"
        case "Glucose":
            return "Blood glucose measures sugar levels in your bloodstream"
        case "Urea Nitrogen":
            return "BUN measures kidney function and protein metabolism"
        case "Creatinine":
            return "Creatinine indicates kidney function and muscle mass"
        case "eGFR":
            return "Estimated glomerular filtration rate measures kidney filtering ability"
        case "Sodium":
            return "Sodium is an electrolyte that helps regulate fluid balance"
        case "Potassium":
            return "Potassium is an electrolyte important for heart and muscle function"
        case "Chloride":
            return "Chloride is an electrolyte that helps maintain acid-base balance"
        case "CO2":
            return "Carbon dioxide measures acid-base balance in blood"
        case "Anion Gap":
            return "Anion gap helps identify acid-base disorders"
        case "Calcium":
            return "Calcium is essential for bone health and muscle function"
        case "Total Protein":
            return "Total protein measures overall protein levels in blood"
        case "Albumin":
            return "Albumin is the main protein in blood plasma"
        case "AST":
            return "Aspartate aminotransferase indicates liver function"
        case "ALT":
            return "Alanine aminotransferase indicates liver function"
        case "Alkaline Phosphatase":
            return "Alkaline phosphatase indicates liver and bone health"
        case "Bilirubin Total":
            return "Bilirubin measures liver function and red blood cell breakdown"
        case "Total Cholesterol":
            return "Total cholesterol measures overall lipid levels"
        case "HDL":
            return "High-density lipoprotein is the 'good' cholesterol"
        case "LDL":
            return "Low-density lipoprotein is the 'bad' cholesterol"
        case "Triglycerides":
            return "Triglycerides are fats that provide energy"
        case "TSH":
            return "Thyroid stimulating hormone regulates thyroid function"
        case "T4":
            return "Thyroxine is the main thyroid hormone"
        case "T3":
            return "Triiodothyronine is an active thyroid hormone"
        case "Free T4":
            return "Free thyroxine measures available thyroid hormone"
        case "Free T3":
            return "Free triiodothyronine measures active thyroid hormone"
        case "HbA1c":
            return "Hemoglobin A1c measures average blood sugar over 3 months"
        case "Insulin":
            return "Insulin regulates blood sugar levels"
        case "C-Peptide":
            return "C-peptide indicates insulin production"
        default:
            return "This test measures important health markers in your blood"
        }
    }
}

struct TestValueRow: View {
    let testName: String
    @Binding var value: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(testName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(getUnit(for: testName))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            TextField("Value", text: $value)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func getUnit(for testName: String) -> String {
        switch testName {
        case "WBC", "RBC", "Platelets":
            return "K/µL"
        case "HGB":
            return "g/dL"
        case "HCT":
            return "%"
        case "Glucose":
            return "mg/dL"
        case "Creatinine":
            return "mg/dL"
        case "Sodium", "Potassium":
            return "mEq/L"
        case "Calcium":
            return "mg/dL"
        case "AST", "ALT":
            return "U/L"
        case "LDL", "HDL":
            return "mg/dL"
        default:
            return ""
        }
    }
}

#Preview {
    BloodTestInputView { _ in }
}
