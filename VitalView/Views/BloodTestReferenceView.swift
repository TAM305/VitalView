import SwiftUI

struct BloodTestReferenceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory = "CBC"
    
    let categories = ["CBC", "CMP", "Lipid Panel", "Thyroid", "Diabetes"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category selector
                Picker("Category", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Test reference list
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(getTestsForCategory(selectedCategory), id: \.name) { test in
                            TestReferenceCard(test: test)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Test Reference")
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
    
    private func getTestsForCategory(_ category: String) -> [TestReference] {
        switch category {
        case "CBC":
            return cbcTests
        case "CMP":
            return cmpTests
        case "Lipid Panel":
            return lipidTests
        case "Thyroid":
            return thyroidTests
        case "Diabetes":
            return diabetesTests
        default:
            return []
        }
    }
}

struct TestReferenceCard: View {
    let test: TestReference
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(test.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(test.unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
            }
            
            // Normal range
            HStack {
                Text("Normal Range:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(test.normalRange)
                    .font(.subheadline)
                    .foregroundColor(.green)
                Spacer()
            }
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    
                    // What it measures
                    VStack(alignment: .leading, spacing: 4) {
                        Text("What it measures:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(test.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Clinical significance
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Clinical significance:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(test.clinicalSignificance)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // High levels
                    if !test.highLevels.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("High levels may indicate:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                            Text(test.highLevels)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Low levels
                    if !test.lowLevels.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Low levels may indicate:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                            Text(test.lowLevels)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TestReference {
    let name: String
    let unit: String
    let normalRange: String
    let description: String
    let clinicalSignificance: String
    let highLevels: String
    let lowLevels: String
}

// MARK: - Test Data

let cbcTests: [TestReference] = [
    TestReference(
        name: "WBC (White Blood Cells)",
        unit: "K/µL",
        normalRange: "4.5-11.0",
        description: "White blood cells are your body's defense system against infections and diseases. They help fight bacteria, viruses, and other harmful invaders.",
        clinicalSignificance: "WBC count is crucial for evaluating immune system function and detecting infections, inflammation, or blood disorders.",
        highLevels: "Infection, inflammation, leukemia, stress, exercise, pregnancy, smoking, or medication side effects.",
        lowLevels: "Bone marrow problems, autoimmune disorders, severe infections, chemotherapy, radiation therapy, or vitamin deficiencies."
    ),
    TestReference(
        name: "RBC (Red Blood Cells)",
        unit: "M/µL",
        normalRange: "4.5-5.9",
        description: "Red blood cells carry oxygen from your lungs to all tissues in your body and return carbon dioxide to your lungs for exhalation.",
        clinicalSignificance: "RBC count helps diagnose anemia, polycythemia, and other blood disorders affecting oxygen delivery.",
        highLevels: "Dehydration, lung disease, heart disease, smoking, high altitude, or bone marrow disorders.",
        lowLevels: "Anemia, blood loss, bone marrow problems, kidney disease, or nutritional deficiencies (iron, B12, folate)."
    ),
    TestReference(
        name: "HGB (Hemoglobin)",
        unit: "g/dL",
        normalRange: "13.5-17.5",
        description: "Hemoglobin is the oxygen-carrying protein in red blood cells. It binds oxygen in the lungs and releases it to tissues throughout the body.",
        clinicalSignificance: "Hemoglobin is the primary indicator of anemia and overall oxygen-carrying capacity of the blood.",
        highLevels: "Dehydration, lung disease, heart disease, smoking, high altitude, or bone marrow disorders.",
        lowLevels: "Anemia, blood loss, bone marrow problems, kidney disease, or nutritional deficiencies."
    ),
    TestReference(
        name: "HCT (Hematocrit)",
        unit: "%",
        normalRange: "41.0-50.0",
        description: "Hematocrit measures the percentage of blood volume occupied by red blood cells. It's a key indicator of blood's oxygen-carrying capacity.",
        clinicalSignificance: "Hematocrit helps evaluate blood composition and diagnose conditions affecting red blood cell production or destruction.",
        highLevels: "Dehydration, lung disease, heart disease, smoking, high altitude, or bone marrow disorders.",
        lowLevels: "Anemia, blood loss, bone marrow problems, kidney disease, or nutritional deficiencies."
    ),
    TestReference(
        name: "Platelets",
        unit: "K/µL",
        normalRange: "150-450",
        description: "Platelets are tiny blood cells that help form clots to stop bleeding. They are essential for wound healing and preventing excessive blood loss.",
        clinicalSignificance: "Platelet count is crucial for evaluating bleeding disorders, clotting problems, and bone marrow function.",
        highLevels: "Inflammation, infection, iron deficiency, cancer, or bone marrow disorders.",
        lowLevels: "Bleeding disorders, bone marrow problems, chemotherapy, radiation therapy, or autoimmune disorders."
    )
]

let cmpTests: [TestReference] = [
    TestReference(
        name: "Glucose",
        unit: "mg/dL",
        normalRange: "70-100",
        description: "Glucose is the primary sugar in your blood and the main source of energy for your body's cells. It's regulated by insulin and other hormones.",
        clinicalSignificance: "Glucose is the primary test for diabetes diagnosis and monitoring. It's essential for evaluating metabolic health.",
        highLevels: "Diabetes, prediabetes, stress, infection, certain medications, or pancreatic disorders.",
        lowLevels: "Hypoglycemia, excessive insulin, liver disease, adrenal insufficiency, or fasting."
    ),
    TestReference(
        name: "Creatinine",
        unit: "mg/dL",
        normalRange: "0.7-1.3",
        description: "Creatinine is a waste product from muscle metabolism that is filtered by your kidneys. It's a reliable indicator of kidney function.",
        clinicalSignificance: "Creatinine is the gold standard for evaluating kidney function and detecting kidney disease early.",
        highLevels: "Kidney disease, dehydration, muscle damage, certain medications, or urinary obstruction.",
        lowLevels: "Reduced muscle mass, pregnancy, or certain medications."
    ),
    TestReference(
        name: "Sodium",
        unit: "mEq/L",
        normalRange: "135-145",
        description: "Sodium is an essential electrolyte that helps regulate fluid balance, blood pressure, and nerve function throughout your body.",
        clinicalSignificance: "Sodium levels are critical for maintaining proper fluid balance and preventing neurological problems.",
        highLevels: "Dehydration, diabetes insipidus, certain medications, or excessive salt intake.",
        lowLevels: "Overhydration, heart failure, liver disease, kidney disease, or certain medications."
    ),
    TestReference(
        name: "Potassium",
        unit: "mEq/L",
        normalRange: "3.5-5.0",
        description: "Potassium is crucial for heart rhythm, muscle function, and nerve transmission. It must be carefully balanced for proper heart function.",
        clinicalSignificance: "Potassium is essential for heart health. Abnormal levels can cause serious heart rhythm problems.",
        highLevels: "Kidney disease, certain medications, tissue damage, or adrenal disorders.",
        lowLevels: "Diuretic use, vomiting, diarrhea, certain medications, or adrenal disorders."
    ),
    TestReference(
        name: "ALT",
        unit: "U/L",
        normalRange: "7-56",
        description: "Alanine aminotransferase is a liver-specific enzyme that indicates liver damage. It's the most sensitive test for liver injury.",
        clinicalSignificance: "ALT is essential for monitoring liver health and detecting liver disease early, including hepatitis and medication effects.",
        highLevels: "Liver disease, hepatitis, fatty liver, certain medications, or alcohol use.",
        lowLevels: "Normal liver function (low levels are generally good)."
    ),
    TestReference(
        name: "AST",
        unit: "U/L",
        normalRange: "10-40",
        description: "Aspartate aminotransferase is a liver enzyme that indicates liver damage or disease. It's also found in heart and muscle tissue.",
        clinicalSignificance: "AST helps evaluate liver function and can indicate liver disease, heart problems, or muscle damage.",
        highLevels: "Liver disease, heart problems, muscle damage, certain medications, or alcohol use.",
        lowLevels: "Normal liver function (low levels are generally good)."
    )
]

let lipidTests: [TestReference] = [
    TestReference(
        name: "Total Cholesterol",
        unit: "mg/dL",
        normalRange: "<200",
        description: "Total cholesterol measures all cholesterol in your blood, including HDL, LDL, and other lipid components.",
        clinicalSignificance: "Total cholesterol is fundamental for cardiovascular risk assessment and heart disease prevention.",
        highLevels: "Increased heart disease risk, poor diet, lack of exercise, obesity, or genetic factors.",
        lowLevels: "Malnutrition, liver disease, or certain medications."
    ),
    TestReference(
        name: "HDL",
        unit: "mg/dL",
        normalRange: ">40",
        description: "High-density lipoprotein is the 'good' cholesterol that removes excess cholesterol from arteries and transports it to the liver.",
        clinicalSignificance: "HDL is protective against heart disease. Higher levels are better for cardiovascular health.",
        highLevels: "Good cardiovascular health, regular exercise, healthy diet, or genetic factors.",
        lowLevels: "Increased heart disease risk, poor diet, lack of exercise, smoking, or obesity."
    ),
    TestReference(
        name: "LDL",
        unit: "mg/dL",
        normalRange: "<100",
        description: "Low-density lipoprotein is the 'bad' cholesterol that can build up in artery walls, increasing heart disease and stroke risk.",
        clinicalSignificance: "LDL is the primary target for cholesterol-lowering treatments and cardiovascular risk assessment.",
        highLevels: "Increased heart disease risk, poor diet, lack of exercise, obesity, or genetic factors.",
        lowLevels: "Good cardiovascular health, healthy diet, exercise, or certain medications."
    ),
    TestReference(
        name: "Triglycerides",
        unit: "mg/dL",
        normalRange: "<150",
        description: "Triglycerides are fats that provide energy and are stored in fat cells. They are the most common type of fat in your body.",
        clinicalSignificance: "Triglycerides are important for cardiovascular risk assessment and may indicate metabolic syndrome or diabetes.",
        highLevels: "Increased heart disease risk, poor diet, obesity, diabetes, or alcohol use.",
        lowLevels: "Good cardiovascular health, healthy diet, or certain medications."
    )
]

let thyroidTests: [TestReference] = [
    TestReference(
        name: "TSH",
        unit: "µIU/mL",
        normalRange: "0.4-4.0",
        description: "Thyroid stimulating hormone regulates thyroid function by stimulating the thyroid gland to produce thyroid hormones.",
        clinicalSignificance: "TSH is the most sensitive test for thyroid disorders and is essential for thyroid health monitoring.",
        highLevels: "Hypothyroidism, thyroid gland problems, certain medications, or pituitary disorders.",
        lowLevels: "Hyperthyroidism, excessive thyroid medication, or pituitary problems."
    ),
    TestReference(
        name: "T4",
        unit: "µg/dL",
        normalRange: "5.0-12.0",
        description: "Thyroxine is the main thyroid hormone that regulates metabolism, energy, and growth throughout your body.",
        clinicalSignificance: "T4 helps diagnose thyroid disorders and monitor thyroid treatment effectiveness.",
        highLevels: "Hyperthyroidism, thyroid medication overdose, or certain medications.",
        lowLevels: "Hypothyroidism, thyroid medication underdose, or pituitary problems."
    ),
    TestReference(
        name: "T3",
        unit: "ng/dL",
        normalRange: "80-200",
        description: "Triiodothyronine is the active thyroid hormone that affects metabolism and energy levels more directly than T4.",
        clinicalSignificance: "T3 helps evaluate thyroid function and can detect hyperthyroidism or thyroid hormone resistance.",
        highLevels: "Hyperthyroidism, thyroid medication overdose, or certain medications.",
        lowLevels: "Hypothyroidism, thyroid medication underdose, or pituitary problems."
    )
]

let diabetesTests: [TestReference] = [
    TestReference(
        name: "HbA1c",
        unit: "%",
        normalRange: "<5.7",
        description: "Hemoglobin A1c measures average blood sugar over the past 2-3 months by measuring glucose attached to hemoglobin.",
        clinicalSignificance: "HbA1c is the gold standard for diabetes diagnosis and monitoring long-term blood sugar control.",
        highLevels: "Diabetes (≥6.5%), prediabetes (5.7-6.4%), poor blood sugar control, or certain medications.",
        lowLevels: "Good blood sugar control, recent blood loss, or certain medications."
    ),
    TestReference(
        name: "Insulin",
        unit: "µIU/mL",
        normalRange: "3-25",
        description: "Insulin regulates blood sugar levels by helping cells absorb glucose from the bloodstream.",
        clinicalSignificance: "Insulin helps evaluate insulin resistance, diabetes type, and metabolic health.",
        highLevels: "Insulin resistance, type 2 diabetes, obesity, or certain medications.",
        lowLevels: "Type 1 diabetes, pancreatic problems, or certain medications."
    ),
    TestReference(
        name: "C-Peptide",
        unit: "ng/mL",
        normalRange: "0.8-3.1",
        description: "C-peptide indicates insulin production by the pancreas and helps distinguish between different types of diabetes.",
        clinicalSignificance: "C-peptide is essential for diabetes diagnosis and treatment planning.",
        highLevels: "Type 2 diabetes, insulin resistance, or certain medications.",
        lowLevels: "Type 1 diabetes, pancreatic problems, or certain medications."
    )
]

#Preview {
    BloodTestReferenceView()
}
