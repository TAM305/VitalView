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
                        HStack {
                            Button("Reference") {
                                showingReference = true
                            }
                            .font(.caption)
                            
                            Button("Save") {
                                saveTest()
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingReference) {
            BloodTestReferenceView()
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
            return "White Blood Cell count measures your body's immune system strength. These cells fight infections and protect against disease. Normal levels indicate good immune function, while high levels may suggest infection or inflammation, and low levels can indicate immune system problems."
        case "RBC":
            return "Red Blood Cell count measures oxygen-carrying capacity. These cells transport oxygen from your lungs to tissues throughout your body. Normal levels ensure adequate oxygen delivery, while low levels (anemia) can cause fatigue and shortness of breath."
        case "HGB":
            return "Hemoglobin is the oxygen-carrying protein in red blood cells. It binds oxygen in your lungs and releases it to tissues. This test is crucial for detecting anemia and monitoring oxygen delivery efficiency. Low levels can cause fatigue, weakness, and shortness of breath."
        case "HCT":
            return "Hematocrit measures the percentage of blood volume occupied by red blood cells. It's a key indicator of blood's oxygen-carrying capacity and helps diagnose anemia or polycythemia (too many red cells). This test is essential for understanding blood composition."
        case "MCV":
            return "Mean Corpuscular Volume measures the average size of your red blood cells. This helps classify types of anemia - microcytic (small cells), normocytic (normal size), or macrocytic (large cells). It's crucial for determining the cause of blood disorders."
        case "MCH":
            return "Mean Corpuscular Hemoglobin measures the average amount of hemoglobin per red blood cell. This test helps identify the type and cause of anemia. Low values suggest iron deficiency, while high values may indicate vitamin B12 or folate deficiency."
        case "MCHC":
            return "Mean Corpuscular Hemoglobin Concentration measures hemoglobin density in red blood cells. This test helps distinguish between different types of anemia and provides insight into the quality of your red blood cells."
        case "RDW":
            return "Red Cell Distribution Width measures variation in red blood cell size. High values indicate cells of varying sizes, which can help diagnose early iron deficiency or other blood disorders before other tests show abnormalities."
        case "Platelets":
            return "Platelet count measures your blood's clotting ability. These tiny cells help stop bleeding by forming clots. Low levels can cause excessive bleeding, while high levels may increase clotting risk. Essential for monitoring bleeding disorders and bone marrow function."
        case "MPV":
            return "Mean Platelet Volume measures the average size of your platelets. This helps evaluate platelet production and can indicate bone marrow disorders. Large platelets may suggest active platelet production, while small platelets might indicate decreased production."
        case "Glucose":
            return "Blood glucose measures sugar levels in your bloodstream. This is the primary test for diabetes and metabolic health. High levels may indicate diabetes or prediabetes, while very low levels can cause hypoglycemia. Regular monitoring is crucial for diabetes management."
        case "Urea Nitrogen":
            return "Blood Urea Nitrogen (BUN) measures kidney function and protein metabolism. It's a waste product filtered by your kidneys. High levels may indicate kidney problems, dehydration, or high protein intake. Essential for monitoring kidney health."
        case "Creatinine":
            return "Creatinine is a waste product from muscle metabolism, filtered by your kidneys. This test is crucial for evaluating kidney function. High levels indicate reduced kidney function, while normal levels suggest healthy kidney filtration."
        case "eGFR":
            return "Estimated Glomerular Filtration Rate measures how well your kidneys filter waste. This is the gold standard for kidney function assessment. Values above 60 indicate normal function, while lower values suggest kidney disease stages."
        case "Sodium":
            return "Sodium is an essential electrolyte that regulates fluid balance, blood pressure, and nerve function. Abnormal levels can affect heart rhythm, brain function, and fluid balance. Critical for monitoring hydration and electrolyte disorders."
        case "Potassium":
            return "Potassium is crucial for heart rhythm, muscle function, and nerve transmission. This electrolyte must be carefully balanced - too high or too low can cause serious heart problems. Essential for monitoring heart health and kidney function."
        case "Chloride":
            return "Chloride is an electrolyte that helps maintain acid-base balance and fluid levels. It works with sodium and potassium to regulate body fluids. Abnormal levels can indicate dehydration, kidney problems, or acid-base disorders."
        case "CO2":
            return "Carbon dioxide (bicarbonate) measures acid-base balance in your blood. This test helps evaluate respiratory and metabolic function. Low levels may indicate acidosis, while high levels suggest alkalosis. Critical for monitoring acid-base balance."
        case "Anion Gap":
            return "Anion Gap helps identify acid-base disorders and metabolic problems. It's calculated from other electrolytes and helps diagnose conditions like diabetic ketoacidosis, kidney failure, or poisoning. Essential for emergency medicine and metabolic evaluation."
        case "Calcium":
            return "Calcium is essential for bone health, muscle function, and nerve transmission. This test evaluates calcium metabolism and can detect bone disorders, parathyroid problems, or kidney disease. Critical for bone and metabolic health."
        case "Total Protein":
            return "Total protein measures overall protein levels in your blood. Proteins are essential for immune function, fluid balance, and tissue repair. Low levels may indicate malnutrition or liver disease, while high levels can suggest inflammation or dehydration."
        case "Albumin":
            return "Albumin is the main protein in blood plasma, essential for maintaining fluid balance and transporting substances. Low levels may indicate liver disease, kidney problems, or malnutrition. Critical for evaluating liver function and nutritional status."
        case "AST":
            return "Aspartate Aminotransferase is a liver enzyme that indicates liver damage or disease. Elevated levels suggest liver injury, heart problems, or muscle damage. This test is crucial for monitoring liver health and detecting liver disease early."
        case "ALT":
            return "Alanine Aminotransferase is a liver-specific enzyme that indicates liver damage. This is the most sensitive test for liver injury and is essential for monitoring liver health, detecting hepatitis, or evaluating medication effects on the liver."
        case "Alkaline Phosphatase":
            return "Alkaline Phosphatase is an enzyme found in liver, bones, and other tissues. Elevated levels may indicate liver disease, bone disorders, or bile duct problems. This test helps evaluate liver and bone health simultaneously."
        case "Bilirubin Total":
            return "Bilirubin is a waste product from red blood cell breakdown, processed by the liver. High levels can cause jaundice and may indicate liver disease, bile duct problems, or blood disorders. Essential for evaluating liver function and detecting jaundice."
        case "Total Cholesterol":
            return "Total cholesterol measures overall lipid levels in your blood. While cholesterol is essential for cell membranes and hormone production, high levels increase heart disease risk. This test is fundamental for cardiovascular health assessment."
        case "HDL":
            return "High-Density Lipoprotein is the 'good' cholesterol that removes excess cholesterol from arteries. Higher levels are protective against heart disease. This test is crucial for evaluating cardiovascular risk and heart health."
        case "LDL":
            return "Low-Density Lipoprotein is the 'bad' cholesterol that can build up in artery walls. High levels increase heart disease and stroke risk. This is the primary target for cholesterol-lowering treatments and cardiovascular risk assessment."
        case "Triglycerides":
            return "Triglycerides are fats that provide energy and are stored in fat cells. High levels increase heart disease risk and may indicate metabolic syndrome or diabetes. This test is essential for cardiovascular risk assessment and metabolic health."
        case "TSH":
            return "Thyroid Stimulating Hormone regulates thyroid function and is the most sensitive test for thyroid disorders. High levels suggest hypothyroidism, while low levels may indicate hyperthyroidism. Essential for thyroid health monitoring."
        case "T4":
            return "Thyroxine (T4) is the main thyroid hormone that regulates metabolism, energy, and growth. This test helps diagnose thyroid disorders and monitor thyroid treatment effectiveness. Critical for metabolic health evaluation."
        case "T3":
            return "Triiodothyronine (T3) is the active thyroid hormone that affects metabolism and energy levels. This test helps evaluate thyroid function and can detect hyperthyroidism. Important for comprehensive thyroid assessment."
        case "Free T4":
            return "Free T4 measures the active, unbound thyroid hormone available to tissues. This test is more accurate than total T4 for evaluating thyroid function and is essential for thyroid disorder diagnosis and treatment monitoring."
        case "Free T3":
            return "Free T3 measures the active, unbound T3 hormone that directly affects metabolism. This test helps evaluate thyroid function and can detect hyperthyroidism or thyroid hormone resistance. Critical for thyroid health assessment."
        case "HbA1c":
            return "Hemoglobin A1c measures average blood sugar over the past 2-3 months. This is the gold standard for diabetes diagnosis and monitoring. Values above 6.5% suggest diabetes, while 5.7-6.4% indicates prediabetes. Essential for diabetes management."
        case "Insulin":
            return "Insulin regulates blood sugar levels by helping cells absorb glucose. This test helps evaluate insulin resistance, diabetes type, and metabolic health. High levels may indicate insulin resistance, while low levels suggest type 1 diabetes."
        case "C-Peptide":
            return "C-Peptide indicates insulin production by the pancreas. This test helps distinguish between type 1 and type 2 diabetes, and evaluates pancreatic function. Essential for diabetes diagnosis and treatment planning."
        default:
            return "This test measures important health markers in your blood that help evaluate your overall health, detect diseases early, and monitor treatment effectiveness. Regular testing is essential for preventive healthcare."
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
