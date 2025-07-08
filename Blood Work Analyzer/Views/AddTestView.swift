import SwiftUI
import Combine
import CoreData

// Import the models


struct TestTypeInfo {
    let title: String
    let description: String
    let icon: String
    let color: Color
}

struct TestResultInfo: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let importance: String
    let relatedConditions: [String]
}

struct TestResultInfoView: View {
    let info: TestResultInfo
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Description")) {
                    Text(info.description)
                }
                
                Section(header: Text("Why It's Important")) {
                    Text(info.importance)
                }
                
                Section(header: Text("Related Conditions")) {
                    ForEach(info.relatedConditions, id: \.self) { condition in
                        Text(condition)
                    }
                }
            }
            .navigationTitle(info.name)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

struct AddTestView: View {
    @Environment(\.managedObjectContext) private var context
    @StateObject private var viewModel: BloodTestViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTestType: String = "Complete Blood Count"
    @State private var testDate: Date = Date()
    @State private var resultValues: [String: Double] = [:]
    @State private var showingTestInfo = false
    @State private var selectedResultInfo: TestResultInfo?
    
    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: BloodTestViewModel(context: context))
    }
    
    private let testTypes: [TestTypeInfo] = [
        TestTypeInfo(
            title: "Complete Blood Count",
            description: "Measures blood cells and related components",
            icon: "drop.fill",
            color: .blue
        ),
        TestTypeInfo(
            title: "Basic Metabolic Panel",
            description: "Measures kidney function, blood sugar, and electrolyte levels",
            icon: "heart.fill",
            color: .red
        ),
        TestTypeInfo(
            title: "Comprehensive Metabolic Panel",
            description: "Includes liver function and protein levels",
            icon: "waveform.path.ecg",
            color: .green
        )
    ]
    
    private let cardBackground = Color(.systemBackground)
    private let accentColor = Color.blue
    
    private func getResultFields() -> [(name: String, unit: String, referenceRange: String)] {
        switch selectedTestType {
        case "Complete Blood Count":
            return [
                ("White Blood Cells", "10^9/L", "4.5-11.0"),
                ("Red Blood Cells", "10^12/L", "4.5-5.5"),
                ("Hemoglobin", "g/dL", "13.5-17.5"),
                ("Hematocrit", "%", "38.8-50.0"),
                ("Platelets", "10^9/L", "150-450")
            ]
        case "Basic Metabolic Panel":
            return [
                ("Glucose", "mg/dL", "70-100"),
                ("BUN", "mg/dL", "7-20"),
                ("Creatinine", "mg/dL", "0.7-1.3"),
                ("Sodium", "mmol/L", "135-145"),
                ("Potassium", "mmol/L", "3.5-5.0"),
                ("Chloride", "mmol/L", "98-107"),
                ("CO2", "mmol/L", "23-29")
            ]
        case "Comprehensive Metabolic Panel":
            return [
                ("Glucose", "mg/dL", "70-100"),
                ("BUN", "mg/dL", "7-20"),
                ("Creatinine", "mg/dL", "0.7-1.3"),
                ("Sodium", "mmol/L", "135-145"),
                ("Potassium", "mmol/L", "3.5-5.0"),
                ("Chloride", "mmol/L", "98-107"),
                ("CO2", "mmol/L", "23-29"),
                ("Calcium", "mg/dL", "8.5-10.5"),
                ("Total Protein", "g/dL", "6.0-8.3"),
                ("Albumin", "g/dL", "3.5-5.0"),
                ("Total Bilirubin", "mg/dL", "0.1-1.2"),
                ("Alkaline Phosphatase", "U/L", "44-147"),
                ("AST", "U/L", "8-48"),
                ("ALT", "U/L", "7-55")
            ]
        default:
            return []
        }
    }
    
    private func getResultInfo(for testName: String) -> TestResultInfo {
        switch testName {
        case "Glucose":
            return TestResultInfo(
                name: "Glucose",
                description: "Glucose is the main type of sugar in your blood and your body's main source of energy. It comes from the food you eat and is carried to your cells through your bloodstream.",
                importance: "Glucose levels are crucial for diagnosing and monitoring diabetes. High levels can indicate diabetes, while low levels can cause hypoglycemia.",
                relatedConditions: ["Diabetes", "Hypoglycemia", "Metabolic Syndrome"]
            )
        case "White Blood Cells":
            return TestResultInfo(
                name: "White Blood Cells (WBC)",
                description: "White blood cells are part of your immune system. They help your body fight infections and other diseases.",
                importance: "WBC count helps identify infections, inflammation, and immune system disorders. High levels may indicate infection, while low levels may suggest immune system problems.",
                relatedConditions: ["Infections", "Leukemia", "Autoimmune Disorders"]
            )
        case "Red Blood Cells":
            return TestResultInfo(
                name: "Red Blood Cells (RBC)",
                description: "Red blood cells carry oxygen from your lungs to your body's tissues and organs, and carry carbon dioxide back to your lungs.",
                importance: "RBC count helps diagnose anemia and other blood disorders. Low levels may indicate anemia, while high levels may suggest dehydration or other conditions.",
                relatedConditions: ["Anemia", "Dehydration", "Polycythemia"]
            )
        case "Hemoglobin":
            return TestResultInfo(
                name: "Hemoglobin",
                description: "Hemoglobin is a protein in red blood cells that carries oxygen throughout your body.",
                importance: "Hemoglobin levels are crucial for diagnosing anemia and monitoring oxygen-carrying capacity. Low levels may indicate anemia or blood loss.",
                relatedConditions: ["Anemia", "Iron Deficiency", "Blood Loss"]
            )
        case "Hematocrit":
            return TestResultInfo(
                name: "Hematocrit",
                description: "Hematocrit measures the percentage of your blood that consists of red blood cells.",
                importance: "Hematocrit levels help diagnose anemia and other blood disorders. Low levels may indicate anemia, while high levels may suggest dehydration.",
                relatedConditions: ["Anemia", "Dehydration", "Polycythemia"]
            )
        case "Platelets":
            return TestResultInfo(
                name: "Platelets",
                description: "Platelets are small blood cells that help your body form clots to stop bleeding.",
                importance: "Platelet count is crucial for blood clotting. Low levels may cause excessive bleeding, while high levels may increase clotting risk.",
                relatedConditions: ["Thrombocytopenia", "Thrombocytosis", "Bleeding Disorders"]
            )
        case "BUN":
            return TestResultInfo(
                name: "Blood Urea Nitrogen (BUN)",
                description: "BUN measures the amount of nitrogen in your blood that comes from urea, a waste product of protein metabolism.",
                importance: "BUN levels help assess kidney function. High levels may indicate kidney problems or dehydration.",
                relatedConditions: ["Kidney Disease", "Dehydration", "Heart Failure"]
            )
        case "Creatinine":
            return TestResultInfo(
                name: "Creatinine",
                description: "Creatinine is a waste product from muscle metabolism that is filtered by your kidneys.",
                importance: "Creatinine levels are a key indicator of kidney function. High levels may indicate kidney damage or disease.",
                relatedConditions: ["Kidney Disease", "Muscle Disorders", "Dehydration"]
            )
        case "Sodium":
            return TestResultInfo(
                name: "Sodium",
                description: "Sodium is an electrolyte that helps maintain fluid balance and nerve function.",
                importance: "Sodium levels are crucial for fluid balance and nerve function. Abnormal levels can affect brain function and fluid balance.",
                relatedConditions: ["Dehydration", "Heart Failure", "Kidney Disease"]
            )
        case "Potassium":
            return TestResultInfo(
                name: "Potassium",
                description: "Potassium is an electrolyte that helps with nerve function and muscle control.",
                importance: "Potassium levels are vital for heart and muscle function. Abnormal levels can cause serious heart problems.",
                relatedConditions: ["Heart Disease", "Kidney Disease", "Muscle Disorders"]
            )
        case "Chloride":
            return TestResultInfo(
                name: "Chloride",
                description: "Chloride is an electrolyte that helps maintain fluid balance and acid-base balance.",
                importance: "Chloride levels help assess acid-base balance and fluid status. Abnormal levels may indicate metabolic disorders.",
                relatedConditions: ["Dehydration", "Kidney Disease", "Metabolic Disorders"]
            )
        case "CO2":
            return TestResultInfo(
                name: "Carbon Dioxide (CO2)",
                description: "CO2 levels in blood help maintain acid-base balance in your body.",
                importance: "CO2 levels are crucial for maintaining proper pH balance. Abnormal levels may indicate respiratory or metabolic problems.",
                relatedConditions: ["Respiratory Disorders", "Kidney Disease", "Metabolic Disorders"]
            )
        case "Calcium":
            return TestResultInfo(
                name: "Calcium",
                description: "Calcium is essential for bone health, muscle function, and nerve transmission.",
                importance: "Calcium levels are vital for bone health and muscle function. Abnormal levels can affect bones, muscles, and nerves.",
                relatedConditions: ["Osteoporosis", "Kidney Disease", "Parathyroid Disorders"]
            )
        case "Total Protein":
            return TestResultInfo(
                name: "Total Protein",
                description: "Total protein measures the amount of protein in your blood, including albumin and globulins.",
                importance: "Protein levels help assess liver and kidney function, and nutritional status. Abnormal levels may indicate various disorders.",
                relatedConditions: ["Liver Disease", "Kidney Disease", "Malnutrition"]
            )
        case "Albumin":
            return TestResultInfo(
                name: "Albumin",
                description: "Albumin is a protein made by your liver that helps maintain fluid balance and transport substances in blood.",
                importance: "Albumin levels help assess liver function and nutritional status. Low levels may indicate liver disease or malnutrition.",
                relatedConditions: ["Liver Disease", "Malnutrition", "Kidney Disease"]
            )
        case "Total Bilirubin":
            return TestResultInfo(
                name: "Total Bilirubin",
                description: "Bilirubin is a waste product from the breakdown of red blood cells, processed by the liver.",
                importance: "Bilirubin levels help assess liver function and bile duct health. High levels may indicate liver disease or bile duct problems.",
                relatedConditions: ["Liver Disease", "Bile Duct Disorders", "Hemolytic Anemia"]
            )
        case "Alkaline Phosphatase":
            return TestResultInfo(
                name: "Alkaline Phosphatase",
                description: "Alkaline phosphatase is an enzyme found in various tissues, especially liver and bones.",
                importance: "ALP levels help assess liver and bone health. High levels may indicate liver disease or bone disorders.",
                relatedConditions: ["Liver Disease", "Bone Disorders", "Bile Duct Problems"]
            )
        case "AST":
            return TestResultInfo(
                name: "Aspartate Aminotransferase (AST)",
                description: "AST is an enzyme found in liver, heart, and muscle cells.",
                importance: "AST levels help assess liver and heart health. High levels may indicate liver damage or heart problems.",
                relatedConditions: ["Liver Disease", "Heart Disease", "Muscle Disorders"]
            )
        case "ALT":
            return TestResultInfo(
                name: "Alanine Aminotransferase (ALT)",
                description: "ALT is an enzyme found mainly in liver cells.",
                importance: "ALT levels are a specific indicator of liver health. High levels may indicate liver damage or disease.",
                relatedConditions: ["Liver Disease", "Hepatitis", "Fatty Liver"]
            )
        default:
            return TestResultInfo(
                name: testName,
                description: "No detailed information available for this test.",
                importance: "Please consult your healthcare provider for more information.",
                relatedConditions: []
            )
        }
    }
    
    private func saveTest() {
        let results = getResultFields().map { field in
            let value = resultValues[field.name] ?? 0.0
            let validValue = value.isNaN || value.isInfinite ? 0.0 : value
            return TestResult(
                name: field.name,
                value: validValue,
                unit: field.unit,
                referenceRange: field.referenceRange,
                explanation: ""
            )
        }
        
        let test = BloodTest(
            date: testDate,
            testType: selectedTestType,
            results: results
        )
        
        viewModel.addTest(test)
        dismiss()
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Test Type Selection Card
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Test Type")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $selectedTestType) {
                            ForEach(testTypes, id: \.title) { type in
                                HStack {
                                    Image(systemName: type.icon)
                                        .foregroundColor(type.color)
                                    Text(type.title)
                                }
                                .tag(type.title)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Text(testTypes.first(where: { $0.title == selectedTestType })?.description ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 5)
                        
                        Button(action: { showingTestInfo = true }) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(accentColor)
                                Text("View Test Information")
                                    .foregroundColor(accentColor)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 10)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cardBackground)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    )
                    
                    // Test Date Card
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Test Date")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        DatePicker("", selection: $testDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cardBackground)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    )
                    
                    // Results Card
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Test Results")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ForEach(getResultFields(), id: \.name) { field in
                            Button(action: { selectedResultInfo = getResultInfo(for: field.name) }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(field.name)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "info.circle")
                                            .foregroundColor(accentColor)
                                    }
                                    
                                    HStack {
                                        TextField("Enter value", value: Binding(
                                            get: { resultValues[field.name] ?? 0.0 },
                                            set: { resultValues[field.name] = $0 }
                                        ), format: .number)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .keyboardType(.decimalPad)
                                        .frame(width: 100)
                                        
                                        Text(field.unit)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Text("Ref: \(field.referenceRange)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.secondarySystemBackground))
                                )
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cardBackground)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    )
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add New Test")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    saveTest()
                }
                .bold()
            )
            .sheet(isPresented: $showingTestInfo) {
                NavigationView {
                    TestInfoView(testType: selectedTestType)
                }
            }
            .sheet(item: $selectedResultInfo) { info in
                TestResultInfoView(info: info)
            }
        }
    }
}

struct ResultInputCard: View {
    let name: String
    let unit: String
    let referenceRange: String
    @Binding var value: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.headline)
            
            HStack {
                TextField("Enter value", value: $value, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text(unit)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("Reference Range: \(referenceRange)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
}
