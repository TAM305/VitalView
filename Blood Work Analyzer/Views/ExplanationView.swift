import SwiftUI

// Import the models


struct ExplanationView: View {
    let result: TestResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(result.explanation)
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
    
    private func getSpecificExplanation(for result: TestResult) -> String {
        switch result.name {
        case "WBC":
            return result.status == .high ? 
                "• Infection or inflammation\n• Stress\n• Exercise" :
                "• Immune system problems\n• Bone marrow issues\n• Certain medications"
        case "RBC":
            return result.status == .high ?
                "• Dehydration\n• Lung disease\n• High altitude" :
                "• Anemia\n• Blood loss\n• Nutritional deficiencies"
        default:
            return "Please consult your healthcare provider for a detailed explanation."
        }
    }
} 
