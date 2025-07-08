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
