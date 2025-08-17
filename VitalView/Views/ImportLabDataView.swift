import SwiftUI

struct ImportLabDataView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: BloodTestViewModel
    @State private var jsonInput: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isImporting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Import Lab Results")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Paste your lab results JSON data below. The app will automatically parse and import your CBC and CMP results.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // JSON Input Area
                VStack(alignment: .leading, spacing: 8) {
                    Text("Lab Results JSON")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    TextEditor(text: $jsonInput)
                        .font(.system(.body, design: .monospaced))
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .frame(minHeight: 300)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
                .padding(.horizontal)
                
                // Sample JSON Button
                Button("Load Sample Data") {
                    loadSampleData()
                }
                .font(.body)
                .foregroundColor(.blue)
                .padding(.horizontal)
                
                Spacer()
                
                // Import Button
                Button(action: importData) {
                    HStack {
                        if isImporting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text(isImporting ? "Importing..." : "Import Lab Data")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(jsonInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(jsonInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isImporting)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") {
                        importData()
                    }
                    .disabled(jsonInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isImporting)
                }
            }
        }
        .alert("Import Result", isPresented: $showingAlert) {
            Button("OK") {
                if alertMessage.contains("successfully") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func importData() {
        guard !jsonInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isImporting = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let result = viewModel.importLabData(jsonInput)
            
            isImporting = false
            
            if result.success {
                alertMessage = "Lab data imported successfully! Your CBC results have been added to your records."
            } else {
                alertMessage = result.errorMessage ?? "Failed to import lab data. Please check the JSON format and try again."
            }
            
            showingAlert = true
        }
    }
    
    private func loadSampleData() {
        jsonInput = """
{
  "healthcare_facility": {
    "name": "Miami VA Healthcare System",
    "address": {
      "street": "1201 NW 16th Street",
      "city": "Miami",
      "state": "FL",
      "zip_code": "33125"
    }
  },
  "patient": {
    "name": "Tony Alexander Mateo",
    "address": {
      "street": "8552 NW 8TH ST",
      "city": "MIAMI",
      "state": "FLORIDA",
      "zip_code": "33126"
    }
  },
  "report": {
    "type": "Lab Results Review",
    "description": "This is a review of your test results to help you understand the results and to let you know if any follow up is needed.",
    "date": "05/01/2025"
  },
  "lab_tests": {
    "cbc": {
      "test_name": "CBC (Complete Blood Count)",
      "test_date": "05/01/2025",
      "results": {
        "wbc": {
          "name": "White Blood Cell Count",
          "value": 6.3,
          "units": "K/uL"
        },
        "neutrophils_percent": {
          "name": "Neutrophils Percentage",
          "value": 57.1,
          "units": "%"
        },
        "lymphs_percent": {
          "name": "Lymphocytes Percentage",
          "value": 32.3,
          "units": "%"
        },
        "monos_percent": {
          "name": "Monocytes Percentage",
          "value": 8.2,
          "units": "%"
        },
        "eos_percent": {
          "name": "Eosinophils Percentage",
          "value": 1.3,
          "units": "%"
        },
        "basos_percent": {
          "name": "Basophils Percentage",
          "value": 0.5,
          "units": "%"
        },
        "neutrophils_absolute": {
          "name": "Neutrophils Absolute Count",
          "value": 3.61,
          "units": "K/uL"
        },
        "lymphs_absolute": {
          "name": "Lymphocytes Absolute Count",
          "value": 2,
          "units": "K/uL"
        },
        "monos_absolute": {
          "name": "Monocytes Absolute Count",
          "value": 0.5,
          "units": "K/uL"
        },
        "eos_absolute": {
          "name": "Eosinophils Absolute Count",
          "value": 0.1,
          "units": "K/uL"
        },
        "basos_absolute": {
          "name": "Basophils Absolute Count",
          "value": null,
          "units": "K/uL"
        },
        "rbc": {
          "name": "Red Blood Cell Count",
          "value": 4.93,
          "units": "M/uL"
        },
        "hgb": {
          "name": "Hemoglobin",
          "value": 14.5,
          "units": "g/dL"
        },
        "hct": {
          "name": "Hematocrit",
          "value": 44.6,
          "units": "%"
        },
        "mcv": {
          "name": "Mean Corpuscular Volume",
          "value": 90.5,
          "units": "fL"
        },
        "mch": {
          "name": "Mean Corpuscular Hemoglobin",
          "value": 29.4,
          "units": "pg"
        },
        "mchc": {
          "name": "Mean Corpuscular Hemoglobin Concentration",
          "value": 32.5,
          "units": "g/dL"
        },
        "rdw": {
          "name": "Red Cell Distribution Width",
          "value": 13.6,
          "units": "%"
        },
        "platelet_count": {
          "name": "Platelet Count",
          "value": 220,
          "units": "K/uL"
        },
        "mpv": {
          "name": "Mean Platelet Volume",
          "value": 9.2,
          "units": "fL"
        }
      },
      "interpretation": "Your blood count is normal."
    },
    "cmp": {
      "test_name": "CMP (Metabolism Studies)",
      "test_date": "05/01/2025",
      "results": {
        "glucose": {
          "name": "Glucose",
          "value": 200,
          "units": "mg/dL",
          "flag": "HIGH"
        },
        "urea_nitrogen": {
          "name": "Urea Nitrogen (BUN)",
          "value": 21,
          "units": "mg/dL"
        },
        "creatinine": {
          "name": "Creatinine",
          "value": 1,
          "units": "mg/dL"
        },
        "egfr_creatinine": {
          "name": "eGFR - Creatinine",
          "value": ">90",
          "units": "mL/min/1.73m²"
        },
        "sodium": {
          "name": "Sodium",
          "value": 140,
          "units": "mmol/L"
        },
        "potassium": {
          "name": "Potassium",
          "value": 4.1,
          "units": "mmol/L"
        },
        "chloride": {
          "name": "Chloride",
          "value": 105,
          "units": "mmol/L"
        },
        "co2": {
          "name": "Carbon Dioxide (CO2)",
          "value": 24,
          "units": "mmol/L"
        },
        "anion_gap": {
          "name": "Anion Gap",
          "value": 11,
          "units": "mmol/L"
        },
        "calcium": {
          "name": "Calcium",
          "value": 9.2,
          "units": "mg/dL"
        },
        "total_protein": {
          "name": "Total Protein",
          "value": null,
          "units": "g/dL"
        },
        "albumin": {
          "name": "Albumin",
          "value": 4.3,
          "units": "g/dL"
        },
        "ast": {
          "name": "AST (Aspartate Aminotransferase)",
          "value": 25,
          "units": "U/L"
        }
      }
    }
  }
}
"""
    }
}

#Preview {
    ImportLabDataView(viewModel: BloodTestViewModel(context: PersistenceController.shared.container.viewContext))
}
