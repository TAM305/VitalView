import SwiftUI

/// Main view for importing lab results from PDF files
struct PDFImportView: View {
    @StateObject private var pdfImporter = PDFLabImporter()
    @State private var showingDocumentPicker = false
    @State private var showingPreview = false
    @State private var showingSuccessAlert = false
    
    // Environment objects for integration with existing app
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var bloodTestViewModel: BloodTestViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Import Lab Results from PDF")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Upload your lab report PDF to automatically extract and import your test results")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Import Button
                VStack(spacing: 16) {
                    Button(action: {
                        showingDocumentPicker = true
                    }) {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                                .font(.title2)
                            Text("Select PDF Lab Report")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(pdfImporter.isProcessing)
                    
                    if pdfImporter.isProcessing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Processing PDF...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Results Preview
                if !pdfImporter.parsedResults.isEmpty {
                    VStack(spacing: 16) {
                        HStack {
                            Text("Extracted Results")
                                .font(.headline)
                            Spacer()
                            Text("\(pdfImporter.parsedResults.count) tests found")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(pdfImporter.parsedResults) { result in
                                    TestResultPreviewRow(result: result)
                                }
                            }
                        }
                        .frame(maxHeight: 300)
                        
                        // Action Buttons
                        HStack(spacing: 16) {
                            Button("Preview Raw Text") {
                                showingPreview = true
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Import All Results") {
                                importResults()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Error Display
                if let errorMessage = pdfImporter.errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("Error")
                            .font(.headline)
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // Instructions
                VStack(spacing: 8) {
                    Text("Supported Formats:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 4) {
                        Text("• CBC (Complete Blood Count)")
                        Text("• CMP (Comprehensive Metabolic Panel)")
                        Text("• Lipid Panels")
                        Text("• General Lab Results")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("PDF Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !pdfImporter.parsedResults.isEmpty {
                        Button("Clear") {
                            pdfImporter.clearData()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            PDFDocumentPicker { url in
                pdfImporter.extractTextFromPDF(url: url)
            }
        }
        .sheet(isPresented: $showingPreview) {
            RawTextPreviewView(text: pdfImporter.extractedText)
        }
        .alert("Import Successful", isPresented: $showingSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Successfully imported \(pdfImporter.parsedResults.count) test results from your PDF lab report.")
        }
        .alert("Import Error", isPresented: Binding(
            get: { pdfImporter.errorMessage != nil },
            set: { if !$0 { pdfImporter.errorMessage = nil } }
        )) {
            Button("OK") { pdfImporter.errorMessage = nil }
        } message: {
            Text(pdfImporter.errorMessage ?? "Unknown error occurred")
        }
    }
    
    /// Imports the extracted results into the app
    private func importResults() {
        guard !pdfImporter.parsedResults.isEmpty else { return }
        
        // Create a blood test from the extracted results
        let bloodTest = BloodTest(
            date: Date(),
            testType: "PDF Import - \(Date().formatted(date: .abbreviated, time: .shortened))",
            results: pdfImporter.parsedResults
        )
        
        // Add to the view model
        bloodTestViewModel.addTest(bloodTest)
        
        // Show success alert
        showingSuccessAlert = true
    }
}

/// Preview row for individual test results
struct TestResultPreviewRow: View {
    let result: TestResult
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(String(format: "%.2f", result.value)) \(result.unit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(result.referenceRange)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(result.status.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch result.status {
        case .normal:
            return .green
        case .high:
            return .red
        case .low:
            return .blue
        }
    }
}

/// Preview view for raw extracted text
struct RawTextPreviewView: View {
    let text: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
            .navigationTitle("Raw Extracted Text")
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
}

#Preview {
    PDFImportView()
        .environmentObject(BloodTestViewModel(context: PersistenceController.shared.container.viewContext))
}
