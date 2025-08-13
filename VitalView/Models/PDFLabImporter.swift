import Foundation
import PDFKit
import Vision
import SwiftUI

/// PDF Lab Results Importer
/// Extracts lab data from PDF reports and converts them to TestResult objects
class PDFLabImporter: ObservableObject {
    @Published var extractedText = ""
    @Published var parsedResults: [TestResult] = []
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    /// Extracts text from a PDF file
    /// - Parameter url: URL to the PDF file
    func extractTextFromPDF(url: URL) {
        isProcessing = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let document = PDFDocument(url: url)
                guard let document = document else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Could not open PDF document"
                        self.isProcessing = false
                    }
                    return
                }
                
                var fullText = ""
                for i in 0..<document.pageCount {
                    if let page = document.page(at: i) {
                        if let pageContent = page.string {
                            fullText += pageContent + "\n"
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.extractedText = fullText
                    self.parseLabResults(from: fullText)
                    self.isProcessing = false
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Error processing PDF: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }
    
    /// Parses extracted text to find lab results
    /// - Parameter text: Raw text extracted from PDF
    private func parseLabResults(from text: String) {
        let lines = text.components(separatedBy: .newlines)
        var results: [TestResult] = []
        
        for line in lines {
            if let result = parseLabLine(line) {
                results.append(result)
            }
        }
        
        parsedResults = results
    }
    
    /// Parses individual lines to extract lab values
    /// - Parameter line: Single line of text from the PDF
    /// - Returns: TestResult if a lab value is found, nil otherwise
    private func parseLabLine(_ line: String) -> TestResult? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedLine.isEmpty { return nil }
        
        // Common lab result patterns
        let patterns = [
            // Basic pattern: Test Name: Value Unit (Reference Range)
            "([A-Za-z\\s]+):\\s*([\\d\\.]+)\\s*([a-zA-Z/%]+)\\s*\\(([\\d\\.\\-]+)\\)",
            // Pattern without reference range: Test Name: Value Unit
            "([A-Za-z\\s]+):\\s*([\\d\\.]+)\\s*([a-zA-Z/%]+)",
            // Pattern with flag: Test Name: Value Unit [H/L]
            "([A-Za-z\\s]+):\\s*([\\d\\.]+)\\s*([a-zA-Z/%]+)\\s*\\[([HL])\\]",
            // Pattern with inequality: Test Name: <Value Unit
            "([A-Za-z\\s]+):\\s*([<>≤≥])\\s*([\\d\\.]+)\\s*([a-zA-Z/%]+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: trimmedLine, options: [], range: NSRange(trimmedLine.startIndex..., in: trimmedLine))
                
                for match in matches {
                    if let result = createTestResult(from: match, in: trimmedLine, pattern: pattern) {
                        return result
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Creates a TestResult from regex match
    /// - Parameters:
    ///   - match: Regex match result
    ///   - line: Original line text
    ///   - pattern: Pattern that matched
    /// - Returns: TestResult object
    private func createTestResult(from match: NSTextCheckingResult, in line: String, pattern: String) -> TestResult? {
        let nsString = line as NSString
        
        // Extract test name
        guard let nameRange = Range(match.range(at: 1), in: line),
              let name = String(line[nameRange]).trimmingCharacters(in: .whitespaces) as String? else {
            return nil
        }
        
        // Extract value
        guard let valueRange = Range(match.range(at: 2), in: line),
              let valueString = String(line[valueRange]) as String?,
              let value = Double(valueString) else {
            return nil
        }
        
        // Extract unit
        guard let unitRange = Range(match.range(at: 3), in: line),
              let unit = String(line[unitRange]).trimmingCharacters(in: .whitespaces) as String? else {
            return nil
        }
        
        // Extract reference range if available
        var referenceRange = "N/A"
        var explanation = "Imported from PDF lab report"
        
        if pattern.contains("Reference Range") && match.numberOfRanges > 4 {
            if let refRange = Range(match.range(at: 4), in: line) {
                referenceRange = String(line[refRange]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Add flag information if available
        if pattern.contains("Flag") && match.numberOfRanges > 4 {
            if let flagRange = Range(match.range(at: 4), in: line) {
                let flag = String(line[flagRange])
                explanation += " [Flag: \(flag)]"
            }
        }
        
        // Handle inequality patterns
        if pattern.contains("Inequality") && match.numberOfRanges > 3 {
            if let inequalityRange = Range(match.range(at: 2), in: line) {
                let inequality = String(line[inequalityRange])
                explanation += " [\(inequality)]"
            }
        }
        
        return TestResult(
            name: name,
            value: value,
            unit: unit,
            referenceRange: referenceRange,
            explanation: explanation
        )
    }
    
    /// Clears all extracted data
    func clearData() {
        extractedText = ""
        parsedResults = []
        errorMessage = nil
    }
}
