import SwiftUI

// Import the models


struct ExplanationView: View {
    let result: TestResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(getDetailedExplanation(for: result))
                .font(.body)
            
            if result.status != .normal {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What this means:")
                        .font(.headline)
                    
                    if result.status == .high {
                        Text("Your \(result.name) level is higher than normal. This could indicate:")
                            .font(.subheadline)
                    } else {
                        Text("Your \(result.name) level is lower than normal. This could indicate:")
                            .font(.subheadline)
                    }
                    
                    Text(getSpecificExplanation(for: result))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            
            Text("Note: Always consult with your healthcare provider about your test results.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private func getDetailedExplanation(for result: TestResult) -> String {
        switch result.name {
        case "WBC", "White Blood Cells":
            return "White blood cells (WBC) are your body's defense system against infections and diseases. They help fight bacteria, viruses, and other harmful invaders. Your WBC count indicates how well your immune system is working."
        case "RBC", "Red Blood Cells":
            return "Red blood cells (RBC) carry oxygen from your lungs to all parts of your body and bring carbon dioxide back to your lungs. They contain hemoglobin, which gives blood its red color and binds oxygen."
        case "HGB", "Hemoglobin":
            return "Hemoglobin is a protein in red blood cells that carries oxygen throughout your body. It's essential for delivering oxygen to your tissues and organs. Hemoglobin levels help diagnose anemia and other blood disorders."
        case "HCT", "Hematocrit":
            return "Hematocrit measures the percentage of your blood that consists of red blood cells. It helps evaluate your blood's oxygen-carrying capacity and can indicate conditions like anemia or dehydration."
        case "PLT", "Platelets":
            return "Platelets are small blood cells that help your body form clots to stop bleeding. They're essential for wound healing and preventing excessive blood loss from injuries."
        case "GLU", "Glucose":
            return "Glucose is your body's main source of energy. It comes from the food you eat and is regulated by insulin. Glucose levels are crucial for diagnosing and monitoring diabetes and other metabolic disorders."
        case "BUN", "Blood Urea Nitrogen":
            return "BUN measures the amount of nitrogen in your blood from urea, a waste product of protein metabolism. It's primarily used to evaluate kidney function and can indicate kidney disease or dehydration."
        case "CRE", "Creatinine":
            return "Creatinine is a waste product from muscle metabolism that's filtered out by your kidneys. It's a key indicator of kidney function - high levels may suggest kidney problems."
        case "NA", "Sodium":
            return "Sodium is an electrolyte that helps maintain fluid balance in your body. It's essential for nerve and muscle function. Abnormal levels can indicate dehydration, kidney problems, or other electrolyte disorders."
        case "K", "Potassium":
            return "Potassium is crucial for heart and muscle function. It helps regulate your heartbeat and muscle contractions. Abnormal levels can affect heart rhythm and muscle function."
        case "CL", "Chloride":
            return "Chloride is an electrolyte that works with sodium to maintain fluid balance and pH in your body. It's important for digestion and acid-base balance."
        case "CO2", "Carbon Dioxide":
            return "Carbon dioxide levels in your blood help maintain acid-base balance. They're important for proper pH regulation and can indicate respiratory or metabolic problems."
        case "CA", "Calcium":
            return "Calcium is essential for bone health, muscle function, and nerve transmission. It's important for blood clotting and maintaining strong bones and teeth."
        default:
            return "This test measures important health indicators in your blood. The results help your healthcare provider assess your overall health and detect potential medical conditions."
        }
    }
    
    private func getSpecificExplanation(for result: TestResult) -> String {
        switch result.name {
        case "WBC", "White Blood Cells":
            return result.status == .high ? 
                "• Infection or inflammation\n• Stress\n• Exercise\n• Certain medications\n• Blood disorders" :
                "• Immune system problems\n• Bone marrow issues\n• Certain medications\n• Viral infections\n• Autoimmune disorders"
        case "RBC", "Red Blood Cells":
            return result.status == .high ?
                "• Dehydration\n• Lung disease\n• High altitude\n• Smoking\n• Heart disease" :
                "• Anemia\n• Blood loss\n• Nutritional deficiencies\n• Bone marrow problems\n• Chronic diseases"
        case "HGB", "Hemoglobin":
            return result.status == .high ?
                "• Dehydration\n• Lung disease\n• High altitude\n• Smoking\n• Heart disease" :
                "• Anemia\n• Iron deficiency\n• Blood loss\n• Nutritional deficiencies\n• Chronic diseases"
        case "HCT", "Hematocrit":
            return result.status == .high ?
                "• Dehydration\n• Lung disease\n• High altitude\n• Smoking\n• Heart disease" :
                "• Anemia\n• Blood loss\n• Nutritional deficiencies\n• Bone marrow problems\n• Chronic diseases"
        case "PLT", "Platelets":
            return result.status == .high ?
                "• Inflammation\n• Infection\n• Blood disorders\n• Certain medications\n• Cancer" :
                "• Bleeding disorders\n• Bone marrow problems\n• Certain medications\n• Autoimmune disorders\n• Viral infections"
        case "GLU", "Glucose":
            return result.status == .high ?
                "• Diabetes\n• Stress\n• Certain medications\n• Pancreatic problems\n• Hormonal disorders" :
                "• Hypoglycemia\n• Excessive insulin\n• Liver disease\n• Hormonal disorders\n• Certain medications"
        case "BUN", "Blood Urea Nitrogen":
            return result.status == .high ?
                "• Kidney disease\n• Dehydration\n• Heart failure\n• High protein diet\n• Certain medications" :
                "• Liver disease\n• Malnutrition\n• Low protein diet\n• Overhydration\n• Certain medications"
        case "CRE", "Creatinine":
            return result.status == .high ?
                "• Kidney disease\n• Dehydration\n• Muscle injury\n• Certain medications\n• Heart failure" :
                "• Muscle loss\n• Malnutrition\n• Liver disease\n• Certain medications\n• Pregnancy"
        case "NA", "Sodium":
            return result.status == .high ?
                "• Dehydration\n• Kidney problems\n• Hormonal disorders\n• Certain medications\n• Diabetes" :
                "• Overhydration\n• Heart failure\n• Liver disease\n• Hormonal disorders\n• Certain medications"
        case "K", "Potassium":
            return result.status == .high ?
                "• Kidney disease\n• Certain medications\n• Acidosis\n• Tissue injury\n• Hormonal disorders" :
                "• Diarrhea\n• Vomiting\n• Certain medications\n• Hormonal disorders\n• Malnutrition"
        case "CL", "Chloride":
            return result.status == .high ?
                "• Dehydration\n• Kidney problems\n• Acidosis\n• Certain medications\n• Hormonal disorders" :
                "• Overhydration\n• Alkalosis\n• Certain medications\n• Hormonal disorders\n• Vomiting"
        case "CO2", "Carbon Dioxide":
            return result.status == .high ?
                "• Lung disease\n• Metabolic alkalosis\n• Certain medications\n• Hormonal disorders\n• Vomiting" :
                "• Metabolic acidosis\n• Kidney disease\n• Diabetes\n• Certain medications\n• Diarrhea"
        case "CA", "Calcium":
            return result.status == .high ?
                "• Parathyroid disorders\n• Cancer\n• Certain medications\n• Bone disorders\n• Kidney disease" :
                "• Vitamin D deficiency\n• Parathyroid disorders\n• Kidney disease\n• Malnutrition\n• Certain medications"
        default:
            return "Please consult your healthcare provider for a detailed explanation of your specific results."
        }
    }
} 
