import Foundation
import PDFKit
import Vision
import SwiftUI
import VisionKit

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
        print("=== PDF Import Debug ===")
        print("Starting PDF extraction from: \(url)")
        isProcessing = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            let document = PDFDocument(url: url)
            guard let document = document else {
                print("Failed to create PDF document from URL")
                DispatchQueue.main.async {
                    self.errorMessage = "Could not open PDF document"
                    self.isProcessing = false
                }
                return
            }
            
            print("PDF document created successfully with \(document.pageCount) pages")
            var fullText = ""
            for i in 0..<document.pageCount {
                if let page = document.page(at: i) {
                    print("Processing page \(i + 1)")
                    
                    // Method 1: Try direct string extraction
                    if let pageContent = page.string, !pageContent.isEmpty {
                        print("Page \(i+1): Direct text extraction successful (\(pageContent.count) characters)")
                        fullText += pageContent + "\n"
                    } else {
                        print("Page \(i+1): Direct text extraction failed, trying alternative methods")
                        
                        // Method 2: Try using PDFPage's attributedString
                        if let attributedString = page.attributedString {
                            let pageContent = attributedString.string
                            if !pageContent.isEmpty {
                                print("Page \(i+1): AttributedString extraction successful (\(pageContent.count) characters)")
                                fullText += pageContent + "\n"
                            }
                        }
                        
                        // Method 3: Try OCR for scanned pages
                        if fullText.isEmpty {
                            print("Page \(i+1): Attempting OCR extraction...")
                            let pageImage = page.thumbnail(of: CGSize(width: 1000, height: 1000), for: .mediaBox)
                            print("Page \(i+1): Page image generated for OCR (\(pageImage.size.width) x \(pageImage.size.height))")
                            
                            // Perform OCR on the page image
                            self.performOCR(on: pageImage) { ocrText in
                                if !ocrText.isEmpty {
                                    print("Page \(i+1): OCR successful - extracted \(ocrText.count) characters")
                                    DispatchQueue.main.async {
                                        self.extractedText += ocrText + "\n"
                                        print("Updated extractedText length: \(self.extractedText.count)")
                                        self.parseLabResults(from: self.extractedText)
                                        self.isProcessing = false
                                    }
                                } else {
                                    print("Page \(i+1): OCR failed - no text found")
                                    DispatchQueue.main.async {
                                        self.isProcessing = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Check if we need to wait for OCR
            let needsOCR = fullText.isEmpty
            
            if !needsOCR {
                // We have direct text, parse immediately
                print("Total extracted text length: \(fullText.count)")
                print("First 200 characters: \(String(fullText.prefix(200)))")
                
                DispatchQueue.main.async {
                    self.extractedText = fullText
                    self.parseLabResults(from: fullText)
                    print("Parsed \(self.parsedResults.count) test results")
                    self.isProcessing = false
                }
            } else {
                // We're using OCR, wait for completion handlers
                print("Using OCR extraction - waiting for completion...")
                // The OCR completion handlers will handle parsing and setting isProcessing = false
            }
        }
    }
    
    /// Performs OCR on a UIImage to extract text
    /// - Parameters:
    ///   - image: UIImage to perform OCR on
    ///   - completion: Callback with extracted text
    private func performOCR(on image: UIImage, completion: @escaping (String) -> Void) {
        guard let cgImage = image.cgImage else {
            print("OCR: Failed to get CGImage from UIImage")
            completion("")
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("OCR: Error during text recognition: \(error)")
                completion("")
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                print("OCR: No text observations found")
                completion("")
                return
            }
            
            let extractedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            print("OCR: Extracted \(extractedText.count) characters from image")
            completion(extractedText)
        }
        
        // Configure OCR request for better accuracy
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("OCR: Failed to perform OCR request: \(error)")
            completion("")
        }
    }
    
    /// Parses extracted text to find lab results
    /// - Parameter text: Raw text extracted from PDF
    private func parseLabResults(from text: String) {
        print("=== Parsing Lab Results ===")
        let lines = text.components(separatedBy: .newlines)
        print("Total lines to parse: \(lines.count)")
        
        // Debug: Show first few lines to understand the format
        print("=== Sample Text Lines ===")
        for (index, line) in lines.prefix(15).enumerated() {
            print("Line \(index + 1): '\(line)'")
        }
        print("=== End Sample Lines ===")
        
        // Look for lab results section markers
        var labResultsStartIndex = -1
        for (index, line) in lines.enumerated() {
            let lowerLine = line.lowercased()
            if lowerLine.contains("test results") || 
               lowerLine.contains("laboratory results") || 
               lowerLine.contains("lab results") ||
               lowerLine.contains("results:") ||
               lowerLine.contains("values:") {
                labResultsStartIndex = index
                print("=== Found Lab Results Section at Line \(index + 1) ===")
                break
            }
        }
        
        // If no specific section found, start from middle of document
        if labResultsStartIndex == -1 {
            labResultsStartIndex = max(0, lines.count / 3)
            print("=== No specific section found, starting from line \(labResultsStartIndex + 1) ===")
        }
        
        // Show lines around the lab results section
        let startIndex = max(0, labResultsStartIndex - 2)
        let endIndex = min(lines.count, labResultsStartIndex + 8)
        print("=== Lab Results Section Preview ===")
        for index in startIndex..<endIndex {
            print("Line \(index + 1): '\(lines[index])'")
        }
        print("=== End Lab Results Preview ===")
        
        var results: [TestResult] = []
        
        // Parse from the lab results section onwards
        var index = labResultsStartIndex
        while index < lines.count {
            let line = lines[index]
            
            // Try to parse as a single line first
            if let result = parseLabLine(line) {
                print("Line \(index + 1): Found single-line result - \(result.name): \(result.value) \(result.unit)")
                results.append(result)
                index += 1
            } else {
                // Try to parse as multi-line format (Date, Test Name, Results)
                if let multiLineResult = parseMultiLineLabResult(lines: lines, startIndex: index) {
                    print("Lines \(index + 1)-\(index + multiLineResult.lineCount): Found multi-line result - \(multiLineResult.result.name): \(multiLineResult.result.value) \(multiLineResult.result.unit)")
                    results.append(multiLineResult.result)
                    index += multiLineResult.lineCount
                } else {
                    // Try to combine with adjacent lines
                    if let combinedResult = tryCombineAdjacentLines(lines: lines, currentIndex: index) {
                        print("Lines \(index + 1)-\(index + 2): Found combined result - \(combinedResult.name): \(combinedResult.value) \(combinedResult.unit)")
                        results.append(combinedResult)
                        index += 2 // Skip both lines since we used them
                    } else {
                        // No result found, move to next line
                        index += 1
                    }
                }
            }
        }
        
        print("Total results parsed: \(results.count)")
        parsedResults = results
    }
    
    /// Parses multi-line lab results where date, test name, and results are on separate lines
    /// - Parameters:
    ///   - lines: All lines from the PDF
    ///   - startIndex: Starting index to look for multi-line results
    /// - Returns: TestResult if found, nil otherwise
    private func parseMultiLineLabResult(lines: [String], startIndex: Int) -> (result: TestResult, lineCount: Int)? {
        guard startIndex + 2 < lines.count else { return nil }
        
        let line1 = lines[startIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let line2 = lines[startIndex + 1].trimmingCharacters(in: .whitespacesAndNewlines)
        let line3 = lines[startIndex + 2].trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("    Trying multi-line parse:")
        print("      Line 1 (Date): '\(line1)'")
        print("      Line 2 (Test): '\(line2)'")
        print("      Line 3 (Value): '\(line3)'")
        
        // Check if line 1 looks like a date
        let datePattern = "(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4})|(\\d{4}[/-]\\d{1,2}[/-]\\d{1,2})"
        let isDateLine = (try? NSRegularExpression(pattern: datePattern, options: []))?.firstMatch(in: line1, options: [], range: NSRange(line1.startIndex..., in: line1)) != nil
        
        // Check if line 2 looks like a test name (contains letters, not just numbers)
        let testNamePattern = "[A-Za-z]"
        let isTestNameLine = (try? NSRegularExpression(pattern: testNamePattern, options: []))?.firstMatch(in: line2, options: [], range: NSRange(line2.startIndex..., in: line2)) != nil
        
        // Check if line 3 contains a numeric value
        let valuePattern = "([\\d\\.]+)\\s*([a-zA-Z/%]+)"
        let valueMatch = (try? NSRegularExpression(pattern: valuePattern, options: []))?.firstMatch(in: line3, options: [], range: NSRange(line3.startIndex..., in: line3))
        
        if isDateLine && isTestNameLine && valueMatch != nil {
            // Extract the value and unit from line 3
            guard let match = valueMatch,
                  let valueRange = Range(match.range(at: 1), in: line3),
                  let unitRange = Range(match.range(at: 2), in: line3) else {
                return nil
            }
            
            let valueString = String(line3[valueRange])
            let unit = String(line3[unitRange]).trimmingCharacters(in: .whitespaces)
            
            guard let value = Double(valueString) else { return nil }
            
            // Clean and validate the test name
            let cleanedName = cleanTestName(line2)
            guard isValidTestName(cleanedName) else {
                print("    Invalid test name in multi-line format: '\(cleanedName)'")
                return nil
            }
            
            let result = TestResult(
                name: cleanedName,
                value: value,
                unit: unit,
                referenceRange: "N/A",
                explanation: "Imported from PDF lab report - Date: \(line1)"
            )
            
            return (result: result, lineCount: 3)
        }
        
        return nil
    }
    
    /// Parses individual lines to extract lab values
    /// - Parameter line: Single line of text from the PDF
    /// - Returns: TestResult if a lab value is found, nil otherwise
    private func parseLabLine(_ line: String) -> TestResult? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedLine.isEmpty { return nil }

        print("=== Parsing Line: '\(trimmedLine)' ===")

        // Improved lab result patterns - ordered from most specific to most general
        let patterns = [
            // Pattern 1: Date Name LongSpace Data (for your specific PDF format)
            "(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4})\\s+([A-Za-z\\s\\-]+)\\s{2,}([\\d\\.]+)\\s*([a-zA-Z/%]+)",
            // Pattern 2: Date Name LongSpace Data (alternative date formats)
            "(\\d{4}[/-]\\d{1,2}[/-]\\d{1,2})\\s+([A-Za-z\\s\\-]+)\\s{2,}([\\d\\.]+)\\s*([a-zA-Z/%]+)",
            // Pattern 3: Standard format with reference range: Test Name: Value Unit (Reference Range)
            "([A-Za-z\\s\\-]+):\\s*([\\d\\.]+)\\s*([a-zA-Z/%]+)\\s*\\(([\\d\\.\\-\\s]+)\\)",
            // Pattern 4: Standard format without reference range: Test Name: Value Unit
            "([A-Za-z\\s\\-]+):\\s*([\\d\\.]+)\\s*([a-zA-Z/%]+)",
            // Pattern 5: Pattern with flag: Test Name: Value Unit [H/L]
            "([A-Za-z\\s\\-]+):\\s*([\\d\\.]+)\\s*([a-zA-Z/%]+)\\s*\\[([HL])\\]",
            // Pattern 6: Pattern with inequality: Test Name: <Value Unit
            "([A-Za-z\\s\\-]+):\\s*([<>≤≥])\\s*([\\d\\.]+)\\s*([a-zA-Z/%]+)",
            // Pattern 7: Simple format: TestName Value Unit (most flexible)
            "([A-Za-z\\s\\-]+)\\s+([\\d\\.]+)\\s*([a-zA-Z/%]+)",
            // Pattern 8: TestName with decimal: TestName Value.Unit (for cases like "TestName 12.5mg/dL")
            "([A-Za-z\\s\\-]+)\\s+([\\d\\.]+)\\.([a-zA-Z/%]+)",
            // Pattern 9: Very flexible: Any text followed by number and unit
            "([A-Za-z\\s\\-]+)\\s+([\\d\\.]+)\\s*([a-zA-Z/%]+)",
            // Pattern 10: Just a test name (might be followed by value on next line)
            "^([A-Za-z\\s\\-]+)$",
            // Pattern 11: Just a value and unit (might be preceded by test name on previous line)
            "^([\\d\\.]+)\\s*([a-zA-Z/%]+)$"
        ]

        // Try patterns in order, but be more intelligent about which one to use
        for (index, pattern) in patterns.enumerated() {
            print("  Trying pattern \(index + 1): \(pattern)")
            
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: trimmedLine, options: [], range: NSRange(trimmedLine.startIndex..., in: trimmedLine))

                for match in matches {
                    print("    Pattern \(index + 1) matched! Ranges: \(match.numberOfRanges)")
                    
                    // Skip pattern 6 (just test names) if we have a better match
                    if index == 5 && match.numberOfRanges == 2 {
                        print("    Skipping test-name-only pattern, looking for better match")
                        continue
                    }
                    
                    // Debug: Show what each capture group contains
                    for groupIndex in 1..<match.numberOfRanges {
                        if let range = Range(match.range(at: groupIndex), in: trimmedLine) {
                            let capturedText = String(trimmedLine[range])
                            print("      Group \(groupIndex): '\(capturedText)'")
                        }
                    }
                    
                    if let result = createTestResult(from: match, in: trimmedLine, pattern: pattern) {
                        print("    Successfully created TestResult: \(result.name)")
                        return result
                    } else {
                        print("    Failed to create TestResult from match")
                    }
                }
            } else {
                print("    Failed to create regex for pattern \(index + 1)")
            }
        }

        // Try specialized parsing for your specific PDF format: Date Name LongSpace Data
        if let specializedResult = parseDateNameLongSpaceData(from: trimmedLine) {
            print("    Created specialized result: \(specializedResult.name)")
            return specializedResult
        }

        // If no patterns matched, try to extract any numeric value with context
        if let fallbackResult = extractFallbackResult(from: trimmedLine) {
            print("    Created fallback result: \(fallbackResult.name)")
            return fallbackResult
        }

        print("  No patterns matched this line")
        return nil
    }
    
    /// Fallback extraction method for lines that don't match standard patterns
    private func extractFallbackResult(from line: String) -> TestResult? {
        // Look for any number in the line
        let numberPattern = "([\\d\\.]+)"
        guard let regex = try? NSRegularExpression(pattern: numberPattern, options: []) else { return nil }
        
        let matches = regex.matches(in: line, options: [], range: NSRange(line.startIndex..., in: line))
        guard let firstMatch = matches.first else { return nil }
        
        // Extract the number
        guard let valueRange = Range(firstMatch.range(at: 1), in: line) else { return nil }
        let valueString = String(line[valueRange])
        guard let value = Double(valueString) else { return nil }
        
        // Try to extract test name from before the number
        let beforeNumber = String(line[..<valueRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let afterNumber = String(line[valueRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        
        // Determine test name and unit
        var testName = beforeNumber
        var unit = "N/A"
        
        // If we have text after the number, it might be the unit
        if !afterNumber.isEmpty {
            // Check if afterNumber looks like a unit
            let unitPattern = "^([a-zA-Z/%]+)$"
            if let unitRegex = try? NSRegularExpression(pattern: unitPattern, options: []) {
                if unitRegex.firstMatch(in: afterNumber, options: [], range: NSRange(afterNumber.startIndex..., in: afterNumber)) != nil {
                    unit = afterNumber
                } else {
                    // If it's not a unit, it might be part of the test name
                    testName = beforeNumber + " " + afterNumber
                }
            }
        }
        
        // Clean up test name
        testName = testName.trimmingCharacters(in: .whitespaces)
        if testName.isEmpty {
            testName = "Unknown Test"
        }
        
        // Clean and validate the test name
        let cleanedName = cleanTestName(testName)
        guard isValidTestName(cleanedName) else {
            print("    Fallback: Invalid test name: '\(cleanedName)'")
            return nil
        }
        
        return TestResult(
            name: cleanedName,
            value: value,
            unit: unit,
            referenceRange: "N/A",
            explanation: "Imported from PDF lab report (fallback parsing)"
        )
    }
    
    /// Creates a TestResult from regex match
    /// - Parameters:
    ///   - match: Regex match result
    ///   - line: Original line text
    ///   - pattern: Pattern that matched
    /// - Returns: TestResult object
    private func createTestResult(from match: NSTextCheckingResult, in line: String, pattern: String) -> TestResult? {
        print("    Creating TestResult from pattern: \(pattern)")
        print("    Match ranges: \(match.numberOfRanges)")

        // Handle different pattern types
        if pattern.contains("Date Name LongSpace Data") {
            // Pattern: Date Name LongSpace Data (for your specific PDF format)
            guard match.numberOfRanges >= 5 else { return nil }
            
            guard let dateRange = Range(match.range(at: 1), in: line),
                  let nameRange = Range(match.range(at: 2), in: line),
                  let valueRange = Range(match.range(at: 3), in: line),
                  let unitRange = Range(match.range(at: 4), in: line) else {
                return nil
            }
            
            let dateString = String(line[dateRange])
            let name = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
            let valueString = String(line[valueRange])
            let unit = String(line[unitRange]).trimmingCharacters(in: .whitespaces)
            
            guard let value = Double(valueString) else { return nil }
            
            // Clean and validate the test name
            let cleanedName = cleanTestName(name)
            guard isValidTestName(cleanedName) else {
                print("    Invalid test name in Date Name LongSpace Data format: '\(cleanedName)'")
                return nil
            }
            
            return TestResult(
                name: cleanedName,
                value: value,
                unit: unit,
                referenceRange: "N/A",
                explanation: "Imported from PDF lab report - Date: \(dateString)"
            )
            
        } else if pattern.contains("Date TestName Value Unit") {
            // Pattern: Date TestName Value Unit
            guard match.numberOfRanges >= 5 else { return nil }
            
            guard let dateRange = Range(match.range(at: 1), in: line),
                  let nameRange = Range(match.range(at: 2), in: line),
                  let valueRange = Range(match.range(at: 3), in: line),
                  let unitRange = Range(match.range(at: 4), in: line) else {
                return nil
            }
            
            let dateString = String(line[dateRange])
            let name = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
            let valueString = String(line[valueRange])
            let unit = String(line[unitRange]).trimmingCharacters(in: .whitespaces)
            
            guard let value = Double(valueString) else { return nil }
            
            // Clean and validate the test name
            let cleanedName = cleanTestName(name)
            guard isValidTestName(cleanedName) else {
                print("    Invalid test name: '\(cleanedName)'")
                return nil
            }
            
            return TestResult(
                name: cleanedName,
                value: value,
                unit: unit,
                referenceRange: "N/A",
                explanation: "Imported from PDF lab report - Date: \(dateString)"
            )
            
        } else if pattern.contains("TestName Value Unit") || pattern.contains("([A-Za-z\\s\\-]+)\\s+([\\d\\.]+)\\s*([a-zA-Z/%]+)") {
            // Pattern: TestName Value Unit (most flexible patterns)
            guard match.numberOfRanges >= 4 else { return nil }
            
            guard let nameRange = Range(match.range(at: 1), in: line),
                  let valueRange = Range(match.range(at: 2), in: line),
                  let unitRange = Range(match.range(at: 3), in: line) else {
                return nil
            }
            
            let name = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
            let valueString = String(line[valueRange])
            let unit = String(line[unitRange]).trimmingCharacters(in: .whitespaces)
            
            guard let value = Double(valueString) else { return nil }
            
            // Clean and validate the test name
            let cleanedName = cleanTestName(name)
            guard isValidTestName(cleanedName) else {
                print("    Invalid test name: '\(cleanedName)'")
                return nil
            }
            
            return TestResult(
                name: cleanedName,
                value: value,
                unit: unit,
                referenceRange: "N/A",
                explanation: "Imported from PDF lab report"
            )
            
        } else if pattern.contains("TestName with decimal") {
            // Pattern: TestName Value.Unit (for cases like "TestName 12.5mg/dL")
            guard match.numberOfRanges >= 4 else { return nil }
            
            guard let nameRange = Range(match.range(at: 1), in: line),
                  let valueRange = Range(match.range(at: 2), in: line),
                  let unitRange = Range(match.range(at: 3), in: line) else {
                return nil
            }
            
            let name = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
            let valueString = String(line[valueRange])
            let unit = String(line[unitRange]).trimmingCharacters(in: .whitespaces)
            
            guard let value = Double(valueString) else { return nil }
            
            // Clean and validate the test name
            let cleanedName = cleanTestName(name)
            guard isValidTestName(cleanedName) else {
                print("    Invalid test name: '\(cleanedName)'")
                return nil
            }
            
            return TestResult(
                name: cleanedName,
                value: value,
                unit: unit,
                referenceRange: "N/A",
                explanation: "Imported from PDF lab report (decimal format)"
            )
            
        } else {
            // Original patterns for standard format with colons
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

            // Clean and validate the test name
            let cleanedName = cleanTestName(name)
            guard isValidTestName(cleanedName) else {
                print("    Invalid test name: '\(cleanedName)'")
                return nil
            }

            return TestResult(
                name: cleanedName,
                value: value,
                unit: unit,
                referenceRange: referenceRange,
                explanation: explanation
            )
        }
    }
    
    /// Attempts to combine information from adjacent lines to create a complete test result
    /// - Parameters:
    ///   - lines: All lines from the PDF
    ///   - currentIndex: Current line index
    /// - Returns: TestResult if can be combined, nil otherwise
    private func tryCombineAdjacentLines(lines: [String], currentIndex: Int) -> TestResult? {
        guard currentIndex + 1 < lines.count else { return nil }
        
        let currentLine = lines[currentIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let nextLine = lines[currentIndex + 1].trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if current line is just a test name and next line has a value
        let testNamePattern = "^([A-Za-z\\s\\-]+)$"
        let valuePattern = "^([\\d\\.]+)\\s*([a-zA-Z/%]+)$"
        
        let isTestName = (try? NSRegularExpression(pattern: testNamePattern, options: []))?.firstMatch(in: currentLine, options: [], range: NSRange(currentLine.startIndex..., in: currentLine)) != nil
        let valueMatch = (try? NSRegularExpression(pattern: valuePattern, options: []))?.firstMatch(in: nextLine, options: [], range: NSRange(nextLine.startIndex..., in: nextLine))
        
        if isTestName && valueMatch != nil {
            guard let match = valueMatch,
                  let valueRange = Range(match.range(at: 1), in: nextLine),
                  let unitRange = Range(match.range(at: 2), in: nextLine) else {
                return nil
            }
            
            let valueString = String(nextLine[valueRange])
            let unit = String(nextLine[unitRange]).trimmingCharacters(in: .whitespaces)
            
            guard let value = Double(valueString) else { return nil }
            
            // Clean and validate the test name
            let cleanedName = cleanTestName(currentLine)
            guard isValidTestName(cleanedName) else {
                print("    Invalid test name when combining lines: '\(cleanedName)'")
                return nil
            }
            
            let result = TestResult(
                name: cleanedName,
                value: value,
                unit: unit,
                referenceRange: "N/A",
                explanation: "Imported from PDF lab report (combined from adjacent lines)"
            )
            
            print("    Successfully combined adjacent lines: '\(cleanedName)' = \(value) \(unit)")
            return result
        }
        
        return nil
    }
    
    /// Specialized parsing for Date Name LongSpace Data format
    /// This handles the specific format: Date + Space + Name + Space + LongSpace + Data
    /// - Parameter line: Single line of text from the PDF
    /// - Returns: TestResult if found, nil otherwise
    private func parseDateNameLongSpaceData(from line: String) -> TestResult? {
        print("    Trying specialized Date Name LongSpace Data parsing")
        
        // Look for date patterns at the beginning
        let datePatterns = [
            "(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4})",  // MM/DD/YYYY or MM-DD-YYYY
            "(\\d{4}[/-]\\d{1,2}[/-]\\d{1,2})"     // YYYY/MM/DD or YYYY-MM-DD
        ]
        
        var dateString = ""
        var dateRange: Range<String.Index>?
        
        // Find the date at the beginning
        for datePattern in datePatterns {
            if let regex = try? NSRegularExpression(pattern: datePattern, options: []) {
                if let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) {
                    if let range = Range(match.range(at: 1), in: line) {
                        dateString = String(line[range])
                        dateRange = range
                        print("      Found date: '\(dateString)'")
                        break
                    }
                }
            }
        }
        
        guard let dateRange = dateRange else {
            print("      No date found at beginning of line")
            return nil
        }
        
        // Extract the text after the date (Name + LongSpace + Data)
        let afterDate = String(line[dateRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        print("      Text after date: '\(afterDate)'")
        
        // Look for the last numeric value and unit in the line
        let valueUnitPattern = "([\\d\\.]+)\\s*([a-zA-Z/%]+)$"
        guard let valueRegex = try? NSRegularExpression(pattern: valueUnitPattern, options: []) else {
            return nil
        }
        
        guard let valueMatch = valueRegex.firstMatch(in: afterDate, options: [], range: NSRange(afterDate.startIndex..., in: afterDate)) else {
            print("      No value/unit found at end of line")
            return nil
        }
        
        guard let valueRange = Range(valueMatch.range(at: 1), in: afterDate),
              let unitRange = Range(valueMatch.range(at: 2), in: afterDate) else {
            return nil
        }
        
        let valueString = String(afterDate[valueRange])
        let unit = String(afterDate[unitRange]).trimmingCharacters(in: .whitespaces)
        
        guard let value = Double(valueString) else {
            print("      Could not convert value to number: '\(valueString)'")
            return nil
        }
        
        // Extract the test name (everything between date and value, excluding the long space)
        let beforeValue = String(afterDate[..<valueRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        print("      Test name (before value): '\(beforeValue)'")
        
        // Clean and validate the test name
        let cleanedName = cleanTestName(beforeValue)
        guard isValidTestName(cleanedName) else {
            print("      Invalid test name: '\(cleanedName)'")
            return nil
        }
        
        let result = TestResult(
            name: cleanedName,
            value: value,
            unit: unit,
            referenceRange: "N/A",
            explanation: "Imported from PDF lab report - Date: \(dateString)"
        )
        
        print("      Successfully created specialized result: \(cleanedName) = \(value) \(unit)")
        return result
    }
    
    /// Clears all extracted data
    func clearData() {
        extractedText = ""
        parsedResults = []
        errorMessage = nil
    }
    
    /// Cleans up test names by removing extra whitespace and formatting
    private func cleanTestName(_ name: String) -> String {
        var cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove multiple spaces
        while cleanedName.contains("  ") {
            cleanedName = cleanedName.replacingOccurrences(of: "  ", with: " ")
        }
        
        // Remove common unwanted characters
        cleanedName = cleanedName.replacingOccurrences(of: "\t", with: " ")
        cleanedName = cleanedName.replacingOccurrences(of: "\n", with: " ")
        cleanedName = cleanedName.replacingOccurrences(of: "\r", with: " ")
        
        // Clean up again after replacements
        cleanedName = cleanedName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleanedName
    }
    
    /// Validates if a test name looks reasonable
    private func isValidTestName(_ name: String) -> Bool {
        let cleanedName = cleanTestName(name)
        
        // Test name should be at least 2 characters and contain letters
        guard cleanedName.count >= 2 else { return false }
        
        // Should contain at least some letters
        let letterPattern = "[A-Za-z]"
        guard let regex = try? NSRegularExpression(pattern: letterPattern, options: []) else { return false }
        let matches = regex.matches(in: cleanedName, options: [], range: NSRange(cleanedName.startIndex..., in: cleanedName))
        
        return !matches.isEmpty
    }
}
