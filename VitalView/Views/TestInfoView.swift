import SwiftUI

// Import the models


struct TestInfoView: View {
    let testType: String
    
    private var testInfo: TestInformation {
        TestInformation.getInfo(for: testType)
    }
    
    var body: some View {
        List {
            Section(header: Text("Overview")) {
                Text(testInfo.description)
                    .font(.body)
            }
            
            Section(header: Text("What it measures")) {
                Text(testInfo.whatItMeasures)
                    .font(.body)
            }
            
            Section(header: Text("Why it's important")) {
                Text(testInfo.importance)
                    .font(.body)
            }
            
            if !testInfo.relatedConditions.isEmpty {
                Section(header: Text("Related Conditions")) {
                    ForEach(testInfo.relatedConditions, id: \.self) { condition in
                        Text("• \(condition)")
                            .font(.body)
                    }
                }
            }
            
            Section(header: Text("Reference Ranges")) {
                ForEach(testInfo.referenceRanges.sorted(by: { $0.key < $1.key }), id: \.key) { name, range in
                    HStack {
                        Text(name)
                        Spacer()
                        Text(range)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("\(testType) Information")
    }
}

// MARK: - Individual Test Information

struct IndividualTestInfo: View {
    let testName: String
    
    private var testInfo: IndividualTestInformation {
        IndividualTestInformation.getInfo(for: testName)
    }
    
    var body: some View {
        List {
            Section(header: Text("Test Definition")) {
                Text(testInfo.definition)
                    .font(.body)
            }
            
            Section(header: Text("What it measures")) {
                Text(testInfo.whatItMeasures)
                    .font(.body)
            }
            
            Section(header: Text("Clinical significance")) {
                Text(testInfo.clinicalSignificance)
                    .font(.body)
            }
            
            Section(header: Text("Normal range")) {
                HStack {
                    Text("Reference Range")
                    Spacer()
                    Text(testInfo.normalRange)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                }
            }
            
            if !testInfo.highLevels.isEmpty {
                Section(header: Text("High levels may indicate")) {
                    Text(testInfo.highLevels)
                        .font(.body)
                        .foregroundColor(.red)
                }
            }
            
            if !testInfo.lowLevels.isEmpty {
                Section(header: Text("Low levels may indicate")) {
                    Text(testInfo.lowLevels)
                        .font(.body)
                        .foregroundColor(.orange)
                }
            }
            
            if !testInfo.additionalInfo.isEmpty {
                Section(header: Text("Additional Information")) {
                    Text(testInfo.additionalInfo)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(testName)
    }
}

struct TestInformation {
    let description: String
    let whatItMeasures: String
    let importance: String
    let relatedConditions: [String]
    let referenceRanges: [String: String]
    
    static func getInfo(for testType: String) -> TestInformation {
        switch testType {
        case "CBC":
            return TestInformation(
                description: "A Complete Blood Count (CBC) is a common blood test that provides important information about your blood cells, including red blood cells, white blood cells, and platelets.",
                whatItMeasures: "Measures the number and characteristics of different types of blood cells in your body, including their size, shape, and content.",
                importance: "Helps detect a wide range of disorders, including anemia, infection, and leukemia. It's essential for monitoring overall health and detecting various medical conditions.",
                relatedConditions: [
                    "Anemia",
                    "Infection",
                    "Inflammation",
                    "Blood disorders",
                    "Immune system disorders"
                ],
                referenceRanges: [
                    "White Blood Cells (WBC)": "4.5-11.0 x10^9/L",
                    "Red Blood Cells (RBC)": "4.5-5.5 x10^12/L",
                    "Hemoglobin (HGB)": "13.5-17.5 g/dL",
                    "Hematocrit (HCT)": "38.8-50.0%",
                    "Platelets (PLT)": "150-450 x10^9/L"
                ]
            )
            
        case "CMP":
            return TestInformation(
                description: "A Comprehensive Metabolic Panel (CMP) is a blood test that measures your body's chemical balance and metabolism.",
                whatItMeasures: "Measures various substances in your blood, including glucose, electrolytes, and proteins, to evaluate your body's metabolism and organ function.",
                importance: "Helps evaluate kidney and liver function, blood sugar levels, and electrolyte balance. Essential for monitoring chronic conditions and overall metabolic health.",
                relatedConditions: [
                    "Diabetes",
                    "Kidney disease",
                    "Liver disease",
                    "Electrolyte imbalances",
                    "Metabolic disorders"
                ],
                referenceRanges: [
                    "Glucose": "70-100 mg/dL",
                    "Blood Urea Nitrogen (BUN)": "7-20 mg/dL",
                    "Creatinine": "0.7-1.3 mg/dL",
                    "Sodium": "135-145 mmol/L",
                    "Potassium": "3.5-5.0 mmol/L",
                    "Chloride": "98-107 mmol/L",
                    "Carbon Dioxide": "23-29 mmol/L",
                    "Calcium": "8.5-10.2 mg/dL"
                ]
            )
            
        case "Cholesterol":
            return TestInformation(
                description: "A Cholesterol Panel measures the levels of different types of cholesterol and fats in your blood.",
                whatItMeasures: "Measures total cholesterol, HDL (good cholesterol), LDL (bad cholesterol), and triglycerides to assess cardiovascular health.",
                importance: "Essential for evaluating heart disease risk and monitoring cardiovascular health. High cholesterol is a major risk factor for heart attacks and strokes.",
                relatedConditions: [
                    "Heart disease",
                    "Stroke",
                    "Atherosclerosis",
                    "Metabolic syndrome",
                    "Diabetes"
                ],
                referenceRanges: [
                    "Total Cholesterol": "<200 mg/dL",
                    "HDL (Good)": ">40 mg/dL",
                    "LDL (Bad)": "<100 mg/dL",
                    "Triglycerides": "<150 mg/dL"
                ]
            )
            
        default:
            return TestInformation(
                description: "This test provides important information about your health.",
                whatItMeasures: "Measures various health indicators in your blood.",
                importance: "Helps monitor your health and detect potential issues.",
                relatedConditions: [],
                referenceRanges: [:]
            )
        }
    }
}

// MARK: - Individual Test Information

struct IndividualTestInformation {
    let definition: String
    let whatItMeasures: String
    let clinicalSignificance: String
    let normalRange: String
    let highLevels: String
    let lowLevels: String
    let additionalInfo: String
    
    static func getInfo(for testName: String) -> IndividualTestInformation {
        switch testName.lowercased() {
        case "wbc", "white blood cell count":
            return IndividualTestInformation(
                definition: "White Blood Cell Count measures the total number of white blood cells in your blood.",
                whatItMeasures: "Counts all types of white blood cells including neutrophils, lymphocytes, monocytes, eosinophils, and basophils.",
                clinicalSignificance: "WBC count is crucial for evaluating immune system function and detecting infections, inflammation, or blood disorders.",
                normalRange: "4.5-11.0 K/µL",
                highLevels: "Infection, inflammation, leukemia, stress, exercise, pregnancy, smoking, or medication side effects.",
                lowLevels: "Bone marrow problems, autoimmune disorders, severe infections, chemotherapy, radiation therapy, or vitamin deficiencies.",
                additionalInfo: "WBCs are your body's defense system against infections and diseases."
            )
            
        case "rbc", "red blood cell count":
            return IndividualTestInformation(
                definition: "Red Blood Cell Count measures the number of red blood cells in your blood.",
                whatItMeasures: "Counts the total number of red blood cells that carry oxygen throughout your body.",
                clinicalSignificance: "RBC count helps diagnose anemia, polycythemia, and other blood disorders affecting oxygen delivery.",
                normalRange: "4.5-5.9 M/µL",
                highLevels: "Dehydration, lung disease, heart disease, smoking, high altitude, or bone marrow disorders.",
                lowLevels: "Anemia, blood loss, bone marrow problems, kidney disease, or nutritional deficiencies (iron, B12, folate).",
                additionalInfo: "RBCs carry oxygen from your lungs to all tissues and return carbon dioxide to your lungs."
            )
            
        case "hgb", "hemoglobin":
            return IndividualTestInformation(
                definition: "Hemoglobin is the oxygen-carrying protein in red blood cells.",
                whatItMeasures: "Measures the amount of hemoglobin protein that binds and transports oxygen in your blood.",
                clinicalSignificance: "Hemoglobin is the primary indicator of anemia and overall oxygen-carrying capacity of the blood.",
                normalRange: "13.5-17.5 g/dL",
                highLevels: "Dehydration, lung disease, heart disease, smoking, high altitude, or bone marrow disorders.",
                lowLevels: "Anemia, blood loss, bone marrow problems, kidney disease, or nutritional deficiencies.",
                additionalInfo: "Hemoglobin gives blood its red color and is essential for oxygen transport."
            )
            
        case "hct", "hematocrit":
            return IndividualTestInformation(
                definition: "Hematocrit measures the percentage of blood volume occupied by red blood cells.",
                whatItMeasures: "Calculates the proportion of blood that consists of red blood cells compared to plasma.",
                clinicalSignificance: "Hematocrit helps evaluate blood composition and diagnose conditions affecting red blood cell production or destruction.",
                normalRange: "41.0-50.0%",
                highLevels: "Dehydration, lung disease, heart disease, smoking, high altitude, or bone marrow disorders.",
                lowLevels: "Anemia, blood loss, bone marrow problems, kidney disease, or nutritional deficiencies.",
                additionalInfo: "Hematocrit is directly related to hemoglobin levels and provides similar clinical information."
            )
            
        case "platelets", "platelet count":
            return IndividualTestInformation(
                definition: "Platelet Count measures the number of platelets in your blood.",
                whatItMeasures: "Counts the tiny blood cells that help form clots to stop bleeding.",
                clinicalSignificance: "Platelet count is crucial for evaluating bleeding disorders, clotting problems, and bone marrow function.",
                normalRange: "150-450 K/µL",
                highLevels: "Inflammation, infection, iron deficiency, cancer, or bone marrow disorders.",
                lowLevels: "Bleeding disorders, bone marrow problems, chemotherapy, radiation therapy, or autoimmune disorders.",
                additionalInfo: "Platelets are essential for wound healing and preventing excessive blood loss."
            )
            
        case "glucose":
            return IndividualTestInformation(
                definition: "Glucose is the primary sugar in your blood and main source of energy for your body.",
                whatItMeasures: "Measures the amount of sugar (glucose) circulating in your bloodstream.",
                clinicalSignificance: "Glucose levels are essential for diagnosing and monitoring diabetes, as well as evaluating metabolic health.",
                normalRange: "70-100 mg/dL",
                highLevels: "Diabetes, stress, infection, certain medications, or pancreatic disorders.",
                lowLevels: "Hypoglycemia, excessive insulin, liver disease, or certain medications.",
                additionalInfo: "Glucose levels are tightly regulated by insulin and glucagon hormones."
            )
            
        case "creatinine":
            return IndividualTestInformation(
                definition: "Creatinine is a waste product produced by muscle metabolism and filtered by the kidneys.",
                whatItMeasures: "Measures the level of creatinine in your blood, which reflects kidney function.",
                clinicalSignificance: "Creatinine is a key indicator of kidney function and helps diagnose kidney disease.",
                normalRange: "0.7-1.3 mg/dL",
                highLevels: "Kidney disease, dehydration, muscle injury, or certain medications.",
                lowLevels: "Low muscle mass, pregnancy, or certain medical conditions.",
                additionalInfo: "Creatinine levels increase when kidneys are not functioning properly."
            )
            
        case "sodium":
            return IndividualTestInformation(
                definition: "Sodium is an essential electrolyte that helps regulate fluid balance and blood pressure.",
                whatItMeasures: "Measures the concentration of sodium ions in your blood.",
                clinicalSignificance: "Sodium levels are crucial for maintaining proper fluid balance, nerve function, and muscle contractions.",
                normalRange: "135-145 mmol/L",
                highLevels: "Dehydration, excessive salt intake, kidney disease, or certain medications.",
                lowLevels: "Overhydration, heart failure, liver disease, or certain medications.",
                additionalInfo: "Sodium is the most abundant electrolyte in your blood."
            )
            
        case "potassium":
            return IndividualTestInformation(
                definition: "Potassium is an essential electrolyte that helps regulate heart rhythm and muscle function.",
                whatItMeasures: "Measures the concentration of potassium ions in your blood.",
                clinicalSignificance: "Potassium levels are critical for heart function, nerve transmission, and muscle contractions.",
                normalRange: "3.5-5.0 mmol/L",
                highLevels: "Kidney disease, certain medications, tissue injury, or metabolic disorders.",
                lowLevels: "Diarrhea, vomiting, certain medications, or kidney disease.",
                additionalInfo: "Potassium is essential for maintaining normal heart rhythm."
            )
            
        case "total cholesterol":
            return IndividualTestInformation(
                definition: "Total Cholesterol measures the sum of all cholesterol types in your blood.",
                whatItMeasures: "Measures the combined level of HDL (good), LDL (bad), and other cholesterol particles.",
                clinicalSignificance: "Total cholesterol is a key indicator of cardiovascular health and heart disease risk.",
                normalRange: "<200 mg/dL",
                highLevels: "High-fat diet, genetics, obesity, diabetes, or liver disease.",
                lowLevels: "Malnutrition, liver disease, or certain medications.",
                additionalInfo: "Cholesterol is essential for cell membranes and hormone production."
            )
            
        case "hdl", "hdl cholesterol":
            return IndividualTestInformation(
                definition: "HDL (High-Density Lipoprotein) is known as 'good cholesterol' that helps remove bad cholesterol.",
                whatItMeasures: "Measures the level of protective cholesterol that carries excess cholesterol to the liver for removal.",
                clinicalSignificance: "Higher HDL levels are associated with lower heart disease risk.",
                normalRange: ">40 mg/dL",
                highLevels: "Regular exercise, healthy diet, moderate alcohol consumption, or genetics.",
                lowLevels: "Poor diet, lack of exercise, smoking, obesity, or diabetes.",
                additionalInfo: "HDL acts as a scavenger, removing excess cholesterol from your arteries."
            )
            
        case "ldl", "ldl cholesterol":
            return IndividualTestInformation(
                definition: "LDL (Low-Density Lipoprotein) is known as 'bad cholesterol' that can build up in arteries.",
                whatItMeasures: "Measures the level of cholesterol that can accumulate in artery walls.",
                clinicalSignificance: "High LDL levels increase the risk of heart disease and stroke.",
                normalRange: "<100 mg/dL",
                highLevels: "High-fat diet, genetics, obesity, diabetes, or liver disease.",
                lowLevels: "Healthy diet, exercise, certain medications, or genetics.",
                additionalInfo: "LDL can form plaques that narrow and harden your arteries."
            )
            
        case "triglycerides":
            return IndividualTestInformation(
                definition: "Triglycerides are the most common type of fat in your blood.",
                whatItMeasures: "Measures the level of fats that store excess energy from your diet.",
                clinicalSignificance: "High triglyceride levels are associated with heart disease and metabolic syndrome.",
                normalRange: "<150 mg/dL",
                highLevels: "High-fat diet, obesity, diabetes, alcohol consumption, or genetics.",
                lowLevels: "Healthy diet, regular exercise, or certain medical conditions.",
                additionalInfo: "Triglycerides are stored in fat cells and released for energy between meals."
            )
            
        default:
            return IndividualTestInformation(
                definition: "This test measures important health indicators in your blood.",
                whatItMeasures: "Measures various substances that help evaluate your health status.",
                clinicalSignificance: "Results help healthcare providers assess your health and detect potential issues.",
                normalRange: "Varies by test",
                highLevels: "High levels may indicate various health conditions.",
                lowLevels: "Low levels may indicate various health conditions.",
                additionalInfo: "Always discuss your results with your healthcare provider."
            )
        }
    }
} 
