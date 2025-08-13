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
                                    // Try to parse date + test name + value (common OCR pattern)
                if let dateTestValueResult = parseDateTestNameValue(lines: lines, currentIndex: index) {
                    print("Lines \(index + 1)-\(index + 2): Found date + test name + value - \(dateTestValueResult.name): \(dateTestValueResult.value) \(dateTestValueResult.unit)")
                    results.append(dateTestValueResult)
                    index += 2 // Skip both lines since we used them
                } else if let testValueResult = parseTestNameValuePair(lines: lines, currentIndex: index) {
                    print("Lines \(index + 1)-\(index + 2): Found test name + value pair - \(testValueResult.name): \(testValueResult.value) \(testValueResult.unit)")
                    results.append(testValueResult)
                    index += 2 // Skip both lines since we used them
                } else {
                        // Try to combine fragmented lines (especially useful for OCR output)
                        if let fragmentedResult = combineFragmentedLines(lines: lines, currentIndex: index) {
                            print("Lines \(index + 1)-\(index + 3): Found fragmented result - \(fragmentedResult.name): \(fragmentedResult.value) \(fragmentedResult.unit)")
                            results.append(fragmentedResult)
                            index += 3 // Skip all three lines since we used them
                        } else {
                            // Try to combine with adjacent lines (legacy method)
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
        
        if isDateLine && isTestNameLine {
            print("      Date and test name lines confirmed, analyzing line 3 for value/unit")
            
            // Enhanced value extraction from line 3
            var value: Double?
            var unit = "N/A"
            
            // Try multiple patterns to extract value and unit from line 3
            let valuePatterns = [
                "([\\d\\.]+)\\s*([a-zA-Z/%]+)",           // Standard: 12.5 mg/dL
                "([\\d\\.]+)\\s*([a-zA-Z/%]+)\\s*([A-Za-z\\s]+)", // With additional text: 12.5 mg/dL NEUTROPHILS
                "([\\d\\.]+)\\s*([a-zA-Z/%]+)\\s*([\\d\\.]+)",     // Range: 12.5 mg/dL 4.5-11.0
                "([\\d\\.]+)\\s*([a-zA-Z/%]+)\\s*([<>≤≥]\\s*[\\d\\.]+)", // With flag: 12.5 mg/dL > 11.0
                "([\\d\\.]+)\\s*([a-zA-Z/%]+)\\s*([HL])",          // With H/L flag: 12.5 mg/dL H
                "([\\d\\.]+)\\s*([a-zA-Z/%]+)\\s*([A-Za-z]+)",     // With text: 12.5 mg/dL HIGH
                "([\\d\\.]+)\\s*([a-zA-Z/%]+)",                    // Just value and unit
                "([\\d\\.]+)"                                       // Just value
            ]
            
            for (patternIndex, pattern) in valuePatterns.enumerated() {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    if let match = regex.firstMatch(in: line3, options: [], range: NSRange(line3.startIndex..., in: line3)) {
                        print("      Pattern \(patternIndex) matched line 3: '\(pattern)'")
                        
                        // Extract value (always first capture group)
                        if let valueRange = Range(match.range(at: 1), in: line3) {
                            let valueString = String(line3[valueRange])
                            print("        Extracted value: '\(valueString)'")
                            
                            if let extractedValue = Double(valueString) {
                                value = extractedValue
                                
                                // Extract unit if available (second capture group)
                                if match.numberOfRanges >= 3 {
                                    if let unitRange = Range(match.range(at: 2), in: line3) {
                                        let extractedUnit = String(line3[unitRange]).trimmingCharacters(in: .whitespaces)
                                        if !extractedUnit.isEmpty {
                                            unit = extractedUnit
                                            print("        Extracted unit: '\(unit)'")
                                        }
                                    }
                                }
                                
                                print("        Successfully extracted: \(value!) \(unit)")
                                break
                            } else {
                                print("        Could not convert '\(valueString)' to number")
                            }
                        }
                    }
                }
            }
            
            // If we still don't have a value, try to extract any number from line 3
            if value == nil {
                print("      No pattern matched, trying to extract any number from line 3")
                let numberPattern = "([\\d\\.]+)"
                if let regex = try? NSRegularExpression(pattern: numberPattern, options: []) {
                    if let match = regex.firstMatch(in: line3, options: [], range: NSRange(line3.startIndex..., in: line3)) {
                        if let valueRange = Range(match.range(at: 1), in: line3) {
                            let valueString = String(line3[valueRange])
                            print("        Found number: '\(valueString)'")
                            value = Double(valueString)
                            
                            // Try to extract unit from after the number
                            let afterNumber = String(line3[valueRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                            if !afterNumber.isEmpty {
                                let unitPattern = "^([a-zA-Z/%]+)"
                                if let unitRegex = try? NSRegularExpression(pattern: unitPattern, options: []) {
                                    if let unitMatch = unitRegex.firstMatch(in: afterNumber, options: [], range: NSRange(afterNumber.startIndex..., in: afterNumber)) {
                                        if let unitRange = Range(unitMatch.range(at: 1), in: afterNumber) {
                                            unit = String(afterNumber[unitRange])
                                            print("        Extracted unit from after number: '\(unit)'")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            guard let extractedValue = value else {
                print("      Could not extract any numeric value from line 3")
                return nil
            }
            
            // Clean and validate the test name
            let cleanedName = cleanTestName(line2)
            guard isValidTestName(cleanedName) else {
                print("    Invalid test name in multi-line format: '\(cleanedName)'")
                return nil
            }
            
            let result = TestResult(
                name: cleanedName,
                value: extractedValue,
                unit: unit,
                referenceRange: "N/A",
                explanation: "Imported from PDF lab report - Date: \(line1)"
            )
            
            print("    Successfully created multi-line result: \(cleanedName) = \(extractedValue) \(unit)")
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

        // Try specialized parsing for your specific PDF format: Date Name LongSpace Data
        if let specializedResult = parseDateNameLongSpaceData(from: trimmedLine) {
            print("    Created specialized result: \(specializedResult.name)")
            return specializedResult
        }

        // Improved lab result patterns - ordered from most specific to most general
        let patterns = [
            // Pattern 0: Date Name LongSpace Data (for your specific PDF format) - very flexible spacing
            "(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4})\\s+([A-Za-z\\s\\-]+)\\s{3,}([\\d\\.]+)\\s*([a-zA-Z/%]+)",
            // Pattern 1: Date Name LongSpace Data (alternative date formats) - very flexible spacing
            "(\\d{4}[/-]\\d{1,2}[/-]\\d{1,2})\\s+([A-Za-z\\s\\-]+)\\s{3,}([\\d\\.]+)\\s*([a-zA-Z/%]+)",
            // Pattern 2: Date Name Data (any spacing between name and data)
            "(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4})\\s+([A-Za-z\\s\\-]+)\\s+([\\d\\.]+)\\s*([a-zA-Z/%]+)",
            // Pattern 3: Date Name Data (alternative date formats, any spacing)
            "(\\d{4}[/-]\\d{1,2}[/-]\\d{1,2})\\s+([A-Za-z\\s\\-]+)\\s+([\\d\\.]+)\\s*([a-zA-Z/%]+)",
            // Pattern 4: Standard format with reference range: Test Name: Value Unit (Reference Range)
            "([A-Za-z\\s\\-]+):\\s*([\\d\\.]+)\\s*([a-zA-Z/%]+)\\s*\\(([\\d\\.\\-\\s]+)\\)",
            // Pattern 5: Standard format without reference range: Test Name: Value Unit
            "([A-Za-z\\s\\-]+):\\s*([\\d\\.]+)\\s*([a-zA-Z/%]+)",
            // Pattern 6: Pattern with flag: Test Name: Value Unit [H/L]
            "([A-Za-z\\s\\-]+):\\s*([\\d\\.]+)\\s*([a-zA-Z/%]+)\\s*\\[([HL])\\]",
            // Pattern 7: Pattern with inequality: Test Name: <Value Unit
            "([A-Za-z\\s\\-]+):\\s*([<>≤≥])\\s*([\\d\\.]+)\\s*([a-zA-Z/%]+)",
            // Pattern 8: Simple format: TestName Value Unit (most flexible)
            "([A-Za-z\\s\\-]+)\\s+([\\d\\.]+)\\s*([a-zA-Z/%]+)",
            // Pattern 9: TestName with decimal: TestName Value.Unit (for cases like "TestName 12.5mg/dL")
            "([A-Za-z\\s\\-]+)\\s+([\\d\\.]+)\\.([a-zA-Z/%]+)",
            // Pattern 10: Very flexible: Any text followed by number and unit
            "([A-Za-z\\s\\-]+)\\s+([\\d\\.]+)\\s*([a-zA-Z/%]+)",
            // Pattern 11: Just a test name (might be followed by value on next line)
            "^([A-Za-z\\s\\-]+)$",
            // Pattern 12: Just a value and unit (might be preceded by test name on previous line)
            "^([\\d\\.]+)\\s*([a-zA-Z/%]+)$"
        ]

        // Try patterns in order, but be more intelligent about which one to use
        for (index, pattern) in patterns.enumerated() {
            print("  Trying pattern \(index): \(pattern)")
            
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: trimmedLine, options: [], range: NSRange(trimmedLine.startIndex..., in: trimmedLine))

                for match in matches {
                    print("    Pattern \(index) matched! Ranges: \(match.numberOfRanges)")
                    print("    Pattern description: \(getPatternDescription(for: index))")
                    
                    // Skip pattern 11 (just test names) if we have a better match
                    if index == 11 && match.numberOfRanges == 2 {
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
                    
                    if let result = createTestResult(from: match, in: trimmedLine, pattern: pattern, patternIndex: index) {
                        print("    Successfully created TestResult: \(result.name)")
                        return result
                    } else {
                        print("    Failed to create TestResult from match")
                    }
                }
            } else {
                print("    Failed to create regex for pattern \(index)")
            }
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
        print("    Using fallback extraction for line: '\(line)'")
        
        // Look for any number in the line
        let numberPattern = "([\\d\\.]+)"
        guard let regex = try? NSRegularExpression(pattern: numberPattern, options: []) else { return nil }
        
        let matches = regex.matches(in: line, options: [], range: NSRange(line.startIndex..., in: line))
        guard let firstMatch = matches.first else { return nil }
        
        // Extract the number
        guard let valueRange = Range(firstMatch.range(at: 1), in: line) else { return nil }
        let valueString = String(line[valueRange])
        guard let value = Double(valueString) else { return nil }
        
        print("    Fallback: Found value \(value) at position \(valueRange)")
        
        // Try to extract test name from before the number
        let beforeNumber = String(line[..<valueRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let afterNumber = String(line[valueRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        
        print("    Fallback: Text before number: '\(beforeNumber)'")
        print("    Fallback: Text after number: '\(afterNumber)'")
        
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
                    print("    Fallback: Extracted unit: '\(unit)'")
                } else {
                    // If it's not a unit, it might be part of the test name
                    testName = beforeNumber + " " + afterNumber
                    print("    Fallback: Combined text as test name: '\(testName)'")
                }
            }
        }
        
        // Clean up test name
        testName = testName.trimmingCharacters(in: .whitespaces)
        
        // Only use "Unknown Test" if we really have no text at all
        if testName.isEmpty {
            // Check if the line contains any letters that might be a test name
            let letterPattern = "[A-Za-z]+"
            if let letterRegex = try? NSRegularExpression(pattern: letterPattern, options: []) {
                if let letterMatch = letterRegex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) {
                    if let letterRange = Range(letterMatch.range(at: 0), in: line) {
                        testName = String(line[letterRange])
                        print("    Fallback: Extracted test name from letters: '\(testName)'")
                    }
                }
            }
            
            // If still no test name, use a more descriptive placeholder
            if testName.isEmpty {
                testName = "Lab Test"
                print("    Fallback: Using generic test name: '\(testName)'")
            }
        }
        
        // Clean and validate the test name
        let cleanedName = cleanTestName(testName)
        guard isValidTestName(cleanedName) else {
            print("    Fallback: Invalid test name: '\(cleanedName)'")
            return nil
        }
        
        print("    Fallback: Successfully created result: \(cleanedName) = \(value) \(unit)")
        
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
    ///   - patternIndex: Index of the pattern in the patterns array
    /// - Returns: TestResult object
    private func createTestResult(from match: NSTextCheckingResult, in line: String, pattern: String, patternIndex: Int) -> TestResult? {
        print("    Creating TestResult from pattern: \(pattern)")
        print("    Match ranges: \(match.numberOfRanges)")
        
        print("    Pattern index: \(patternIndex) - \(getPatternDescription(for: patternIndex))")
        
        // Handle different pattern types based on their index and expected capture groups
        switch patternIndex {
        case 0, 1:
            // Patterns 0-1: Date Name LongSpace Data (4 capture groups: date, name, value, unit)
            guard match.numberOfRanges >= 5 else { 
                print("    Date Name LongSpace Data pattern needs 5 groups, got \(match.numberOfRanges)")
                return nil 
            }
            
            guard let dateRange = Range(match.range(at: 1), in: line),
                  let nameRange = Range(match.range(at: 2), in: line),
                  let valueRange = Range(match.range(at: 3), in: line),
                  let unitRange = Range(match.range(at: 4), in: line) else {
                print("    Failed to extract ranges from Date Name LongSpace Data match")
                return nil
            }
            
            let dateString = String(line[dateRange])
            let name = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
            let valueString = String(line[valueRange])
            let unit = String(line[unitRange]).trimmingCharacters(in: .whitespaces)
            
            print("    Extracted from Date Name LongSpace Data - Date: '\(dateString)', Name: '\(name)', Value: '\(valueString)', Unit: '\(unit)'")
            
            guard let value = Double(valueString) else { 
                print("    Could not convert value to number: '\(valueString)'")
                return nil 
            }
            
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
            
        case 2, 3:
            // Patterns 2-3: Date Name Data (4 capture groups: date, name, value, unit)
            guard match.numberOfRanges >= 5 else { 
                print("    Date Name Data pattern needs 5 groups, got \(match.numberOfRanges)")
                return nil 
            }
            
            guard let dateRange = Range(match.range(at: 1), in: line),
                  let nameRange = Range(match.range(at: 2), in: line),
                  let valueRange = Range(match.range(at: 3), in: line),
                  let unitRange = Range(match.range(at: 4), in: line) else {
                print("    Failed to extract ranges from Date Name Data match")
                return nil
            }
            
            let dateString = String(line[dateRange])
            let name = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
            let valueString = String(line[valueRange])
            let unit = String(line[unitRange]).trimmingCharacters(in: .whitespaces)
            
            print("    Extracted from Date Name Data - Date: '\(dateString)', Name: '\(name)', Value: '\(valueString)', Unit: '\(unit)'")
            
            guard let value = Double(valueString) else { 
                print("    Could not convert value to number: '\(valueString)'")
                return nil 
            }
            
            // Clean and validate the test name
            let cleanedName = cleanTestName(name)
            guard isValidTestName(cleanedName) else {
                print("    Invalid test name in Date Name Data format: '\(cleanedName)'")
                return nil
            }
            
            return TestResult(
                name: cleanedName,
                value: value,
                unit: unit,
                referenceRange: "N/A",
                explanation: "Imported from PDF lab report - Date: \(dateString)"
            )
            
        case 4, 5, 6, 7, 8, 9, 10:
            // Patterns 4-10: TestName Value Unit (3 capture groups: name, value, unit)
            guard match.numberOfRanges >= 4 else { 
                print("    TestName Value Unit pattern needs 4 groups, got \(match.numberOfRanges)")
                return nil 
            }
            
            guard let nameRange = Range(match.range(at: 1), in: line),
                  let valueRange = Range(match.range(at: 2), in: line),
                  let unitRange = Range(match.range(at: 3), in: line) else {
                print("    Failed to extract ranges from TestName Value Unit match")
                return nil
            }
            
            let name = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
            let valueString = String(line[valueRange])
            let unit = String(line[unitRange]).trimmingCharacters(in: .whitespaces)
            
            guard let value = Double(valueString) else { 
                print("    Could not convert value to number: '\(valueString)'")
                return nil 
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
                referenceRange: "N/A",
                explanation: "Imported from PDF lab report (TestName Value Unit format)"
            )
            
        case 11:
            // Pattern 11: Test name only (1 capture group: name)
            guard match.numberOfRanges >= 2 else { 
                print("    Test name only pattern needs 2 groups, got \(match.numberOfRanges)")
                return nil 
            }
            
            guard let nameRange = Range(match.range(at: 1), in: line) else {
                print("    Failed to extract test name from simple pattern")
                return nil
            }
            
            let name = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
            let cleanedName = cleanTestName(name)
            
            guard isValidTestName(cleanedName) else {
                print("    Invalid test name from simple pattern: '\(cleanedName)'")
                return nil
            }
            
            // Return a placeholder result that can be updated later
            return TestResult(
                name: cleanedName,
                value: 0.0,
                unit: "N/A",
                referenceRange: "N/A",
                explanation: "Imported from PDF lab report - test name only (value may be on next line)"
            )
            
        case 12:
            // Pattern 12: Value and unit only (2 capture groups: value, unit)
            guard match.numberOfRanges >= 3 else { 
                print("    Value/Unit only pattern needs 3 groups, got \(match.numberOfRanges)")
                return nil 
            }
            
            guard let valueRange = Range(match.range(at: 1), in: line),
                  let unitRange = Range(match.range(at: 2), in: line) else {
                print("    Failed to extract value/unit from simple pattern")
                return nil
            }
            
            let valueString = String(line[valueRange])
            let unit = String(line[unitRange]).trimmingCharacters(in: .whitespaces)
            
            guard let value = Double(valueString) else {
                print("    Could not convert value to number: '\(valueString)'")
                return nil
            }
            
            return TestResult(
                name: "Unknown Test",
                value: value,
                unit: unit,
                referenceRange: "N/A",
                explanation: "Imported from PDF lab report - value/unit only (test name unknown)"
            )
            
        default:
            // Generic fallback for any other patterns
            print("    Generic fallback for pattern index \(patternIndex)")
            guard match.numberOfRanges >= 3 else {
                print("    Generic fallback needs at least 3 groups, got \(match.numberOfRanges)")
                return nil
            }
            
            // Try to extract name, value, and unit based on available groups
            if match.numberOfRanges >= 4 {
                // We have name, value, unit
                guard let nameRange = Range(match.range(at: 1), in: line),
                      let valueRange = Range(match.range(at: 2), in: line),
                      let unitRange = Range(match.range(at: 3), in: line) else {
                    return nil
                }
                
                let name = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
                let valueString = String(line[valueRange])
                let unit = String(line[unitRange]).trimmingCharacters(in: .whitespaces)
                
                guard let value = Double(valueString) else { return nil }
                
                let cleanedName = cleanTestName(name)
                guard isValidTestName(cleanedName) else { return nil }
                
                return TestResult(
                    name: cleanedName,
                    value: value,
                    unit: unit,
                    referenceRange: "N/A",
                    explanation: "Imported from PDF lab report (generic fallback)"
                )
            } else {
                // We only have 3 groups, assume it's name and value
                guard let nameRange = Range(match.range(at: 1), in: line),
                      let valueRange = Range(match.range(at: 2), in: line) else {
                    return nil
                }
                
                let name = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
                let valueString = String(line[valueRange])
                
                guard let value = Double(valueString) else { return nil }
                
                let cleanedName = cleanTestName(name)
                guard isValidTestName(cleanedName) else { return nil }
                
                return TestResult(
                    name: cleanedName,
                    value: value,
                    unit: "N/A",
                    referenceRange: "N/A",
                    explanation: "Imported from PDF lab report (generic fallback - no unit)"
                )
            }
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
    
    /// Intelligently combines fragmented lines that appear to be parts of a single lab result
    /// This is especially useful for OCR output where single entries get split across multiple lines
    /// - Parameters:
    ///   - lines: All lines from the PDF
    ///   - currentIndex: Current line index
    /// - Returns: TestResult if fragments can be combined, nil otherwise
    private func combineFragmentedLines(lines: [String], currentIndex: Int) -> TestResult? {
        guard currentIndex + 2 < lines.count else { return nil }
        
        let line1 = lines[currentIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let line2 = lines[currentIndex + 1].trimmingCharacters(in: .whitespacesAndNewlines)
        let line3 = lines[currentIndex + 2].trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("    Trying to combine fragmented lines:")
        print("      Line 1: '\(line1)'")
        print("      Line 2: '\(line2)'")
        print("      Line 3: '\(line3)'")
        
        // Pattern 1: Date on line 1, Test name on line 2, Value/Unit on line 3
        if isDateLine(line1) && isTestNameLine(line2) && hasValueUnit(line3) {
            print("      Pattern 1: Date + Test + Value/Unit")
            return createResultFromFragments(date: line1, testName: line2, valueLine: line3)
        }
        
        // Pattern 2: Date + Test name on line 1, Value/Unit on line 2
        if isDateLine(line1) && hasValueUnit(line2) {
            // Extract test name from line 1 after the date
            if let testName = extractTestNameAfterDate(from: line1) {
                print("      Pattern 2: Date+Test + Value/Unit")
                return createResultFromFragments(date: line1, testName: testName, valueLine: line2)
            }
        }
        
        // Pattern 3: Test name on line 1, Value/Unit on line 2
        if isTestNameLine(line1) && hasValueUnit(line2) {
            print("      Pattern 3: Test + Value/Unit (no date)")
            return createResultFromFragments(date: "Unknown", testName: line1, valueLine: line2)
        }
        
        // Pattern 4: Date + Test name on line 1, partial value on line 2, complete value on line 3
        if isDateLine(line1) && isPartialValueLine(line2) && hasValueUnit(line3) {
            if let testName = extractTestNameAfterDate(from: line1) {
                print("      Pattern 4: Date+Test + Partial + Complete Value")
                return createResultFromFragments(date: line1, testName: testName, valueLine: line3)
            }
        }
        
        return nil
    }
    
    /// Helper method to check if a line contains a date
    private func isDateLine(_ line: String) -> Bool {
        let datePattern = "(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4})|(\\d{4}[/-]\\d{1,2}[/-]\\d{1,2})"
        return (try? NSRegularExpression(pattern: datePattern, options: []))?.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) != nil
    }
    
    /// Helper method to check if a line contains a test name
    private func isTestNameLine(_ line: String) -> Bool {
        let testNamePattern = "[A-Za-z]"
        return (try? NSRegularExpression(pattern: testNamePattern, options: []))?.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) != nil
    }
    
    /// Helper method to check if a line contains a value and unit
    private func hasValueUnit(_ line: String) -> Bool {
        let valueUnitPattern = "([\\d\\.]+)\\s*([a-zA-Z/%]+)"
        return (try? NSRegularExpression(pattern: valueUnitPattern, options: []))?.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) != nil
    }
    
    /// Helper method to check if a line contains a partial value (just a number)
    private func isPartialValueLine(_ line: String) -> Bool {
        let partialValuePattern = "^([\\d\\.]+)$"
        return (try? NSRegularExpression(pattern: partialValuePattern, options: []))?.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) != nil
    }
    
    /// Helper method to extract test name from a line that starts with a date
    private func extractTestNameAfterDate(from line: String) -> String? {
        let datePattern = "(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4})|(\\d{4}[/-]\\d{1,2}[/-]\\d{1,2})"
        guard let regex = try? NSRegularExpression(pattern: datePattern, options: []) else { return nil }
        
        if let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) {
            if let range = Range(match.range(at: 0), in: line) {
                let afterDate = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !afterDate.isEmpty {
                    return afterDate
                }
            }
        }
        return nil
    }
    
    /// Helper method to create a TestResult from fragmented lines
    private func createResultFromFragments(date: String, testName: String, valueLine: String) -> TestResult? {
        // Extract value and unit from the value line
        let valueUnitPattern = "([\\d\\.]+)\\s*([a-zA-Z/%]+)"
        guard let regex = try? NSRegularExpression(pattern: valueUnitPattern, options: []) else { return nil }
        
        if let match = regex.firstMatch(in: valueLine, options: [], range: NSRange(valueLine.startIndex..., in: valueLine)) {
            guard let valueRange = Range(match.range(at: 1), in: valueLine),
                  let unitRange = Range(match.range(at: 2), in: valueLine) else {
                return nil
            }
            
            let valueString = String(valueLine[valueRange])
            let unit = String(valueLine[unitRange]).trimmingCharacters(in: .whitespaces)
            
            guard let value = Double(valueString) else { return nil }
            
            // Clean and validate the test name
            let cleanedName = cleanTestName(testName)
            guard isValidTestName(cleanedName) else {
                print("      Invalid test name from fragments: '\(cleanedName)'")
                return nil
            }
            
            let result = TestResult(
                name: cleanedName,
                value: value,
                unit: unit,
                referenceRange: "N/A",
                explanation: "Imported from PDF lab report - Date: \(date) (combined from fragments)"
            )
            
            print("      Successfully created result from fragments: \(cleanedName) = \(value) \(unit)")
            return result
        }
        
        return nil
    }
    
    /// Parses the common OCR pattern: test name on one line, value on the next line
    /// This handles cases like "AST" on line 1, "116.00 H" on line 2
    /// - Parameters:
    ///   - lines: All lines from the PDF
    ///   - currentIndex: Current line index
    /// - Returns: TestResult if found, nil otherwise
    private func parseTestNameValuePair(lines: [String], currentIndex: Int) -> TestResult? {
        guard currentIndex + 1 < lines.count else { return nil }
        
        let testNameLine = lines[currentIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let valueLine = lines[currentIndex + 1].trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("    Trying to parse test name/value pair:")
        print("      Test name line: '\(testNameLine)'")
        print("      Value line: '\(valueLine)'")
        
        // Check if first line looks like a test name (contains letters, not just numbers or dates)
        let testNamePattern = "^[A-Za-z\\s\\-]+$"
        let isTestName = (try? NSRegularExpression(pattern: testNamePattern, options: []))?.firstMatch(in: testNameLine, options: [], range: NSRange(testNameLine.startIndex..., in: testNameLine)) != nil
        
        // Check if second line contains a numeric value
        let hasNumericValue = (try? NSRegularExpression(pattern: "([\\d\\.]+)", options: []))?.firstMatch(in: valueLine, options: [], range: NSRange(valueLine.startIndex..., in: valueLine)) != nil
        
        if isTestName && hasNumericValue {
            print("      Confirmed test name + value pattern")
            
            // Extract the numeric value and any unit/flag
            var value: Double?
            var unit = "N/A"
            var flag = ""
            
            // Try to extract value and unit from the value line
            let valueUnitPatterns = [
                "([\\d\\.]+)\\s*([a-zA-Z/%]+)\\s*([HL#\\$])",  // Value + Unit + Flag (H, L, #, $)
                "([\\d\\.]+)\\s*([a-zA-Z/%]+)",                 // Value + Unit
                "([\\d\\.]+)\\s*([HL#\\$])",                     // Value + Flag only
                "([\\d\\.]+)"                                    // Just value
            ]
            
            for pattern in valueUnitPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    if let match = regex.firstMatch(in: valueLine, options: [], range: NSRange(valueLine.startIndex..., in: valueLine)) {
                        guard let valueRange = Range(match.range(at: 1), in: valueLine) else { continue }
                        let valueString = String(valueLine[valueRange])
                        
                        if let extractedValue = Double(valueString) {
                            value = extractedValue
                            
                            // Extract unit if available
                            if match.numberOfRanges >= 3 {
                                if let unitRange = Range(match.range(at: 2), in: valueLine) {
                                    let extractedUnit = String(valueLine[unitRange]).trimmingCharacters(in: .whitespaces)
                                    if !extractedUnit.isEmpty {
                                        unit = extractedUnit
                                    }
                                }
                            }
                            
                            // Extract flag if available
                            if match.numberOfRanges >= 4 {
                                if let flagRange = Range(match.range(at: 3), in: valueLine) {
                                    let extractedFlag = String(valueLine[flagRange]).trimmingCharacters(in: .whitespaces)
                                    if !extractedFlag.isEmpty {
                                        flag = extractedFlag
                                    }
                                }
                            }
                            
                            print("      Extracted: Value=\(extractedValue), Unit=\(unit), Flag=\(flag)")
                            break
                        }
                    }
                }
            }
            
            // If we still don't have a value, try to extract any number
            if value == nil {
                let numberPattern = "([\\d\\.]+)"
                if let regex = try? NSRegularExpression(pattern: numberPattern, options: []) {
                    if let match = regex.firstMatch(in: valueLine, options: [], range: NSRange(valueLine.startIndex..., in: valueLine)) {
                        if let valueRange = Range(match.range(at: 1), in: valueLine) {
                            let valueString = String(valueLine[valueRange])
                            value = Double(valueString)
                            print("      Extracted just value: \(valueString)")
                        }
                    }
                }
            }
            
            guard let extractedValue = value else {
                print("      Could not extract numeric value")
                return nil
            }
            
            // Clean and validate the test name
            let cleanedName = cleanTestName(testNameLine)
            guard isValidTestName(cleanedName) else {
                print("      Invalid test name: '\(cleanedName)'")
                return nil
            }
            
            // Create explanation with flag if present
            var explanation = "Imported from PDF lab report (test name + value pair)"
            if !flag.isEmpty {
                explanation += " - Flag: \(flag)"
            }
            
            let result = TestResult(
                name: cleanedName,
                value: extractedValue,
                unit: unit,
                referenceRange: "N/A",
                explanation: explanation
            )
            
            print("      Successfully created test name/value pair result: \(cleanedName) = \(extractedValue) \(unit)")
            return result
        }
        
        return nil
    }
    
    /// Parses the pattern: date + test name on one line, value on the next line
    /// This handles cases like "05/01/2025 ALT" on line 1, "31.00" on line 2
    /// - Parameters:
    ///   - lines: All lines from the PDF
    ///   - currentIndex: Current line index
    /// - Returns: TestResult if found, nil otherwise
    private func parseDateTestNameValue(lines: [String], currentIndex: Int) -> TestResult? {
        guard currentIndex + 1 < lines.count else { return nil }
        
        let dateTestLine = lines[currentIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let valueLine = lines[currentIndex + 1].trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("    Trying to parse date + test name + value:")
        print("      Date+Test line: '\(dateTestLine)'")
        print("      Value line: '\(valueLine)'")
        
        // Check if first line contains a date followed by a test name
        let dateTestPattern = "(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4})\\s+([A-Za-z\\s\\-]+)"
        guard let regex = try? NSRegularExpression(pattern: dateTestPattern, options: []) else { return nil }
        
        if let match = regex.firstMatch(in: dateTestLine, options: [], range: NSRange(dateTestLine.startIndex..., in: dateTestLine)) {
            guard let dateRange = Range(match.range(at: 1), in: dateTestLine),
                  let testNameRange = Range(match.range(at: 2), in: dateTestLine) else {
                return nil
            }
            
            let dateString = String(dateTestLine[dateRange])
            let testName = String(dateTestLine[testNameRange]).trimmingCharacters(in: .whitespaces)
            
            print("      Extracted date: '\(dateString)', test name: '\(testName)'")
            
            // Check if second line contains a numeric value
            let hasNumericValue = (try? NSRegularExpression(pattern: "([\\d\\.]+)", options: []))?.firstMatch(in: valueLine, options: [], range: NSRange(valueLine.startIndex..., in: valueLine)) != nil
            
            if hasNumericValue {
                print("      Confirmed date + test name + value pattern")
                
                // Extract the numeric value and any unit/flag
                var value: Double?
                var unit = "N/A"
                var flag = ""
                
                // Try to extract value and unit from the value line
                let valueUnitPatterns = [
                    "([\\d\\.]+)\\s*([a-zA-Z/%]+)\\s*([HL#\\$])",  // Value + Unit + Flag (H, L, #, $)
                    "([\\d\\.]+)\\s*([a-zA-Z/%]+)",                 // Value + Unit
                    "([\\d\\.]+)\\s*([HL#\\$])",                     // Value + Flag only
                    "([\\d\\.]+)"                                    // Just value
                ]
                
                for pattern in valueUnitPatterns {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                        if let match = regex.firstMatch(in: valueLine, options: [], range: NSRange(valueLine.startIndex..., in: valueLine)) {
                            guard let valueRange = Range(match.range(at: 1), in: valueLine) else { continue }
                            let valueString = String(valueLine[valueRange])
                            
                            if let extractedValue = Double(valueString) {
                                value = extractedValue
                                
                                // Extract unit if available
                                if match.numberOfRanges >= 3 {
                                    if let unitRange = Range(match.range(at: 2), in: valueLine) {
                                        let extractedUnit = String(valueLine[unitRange]).trimmingCharacters(in: .whitespaces)
                                        if !extractedUnit.isEmpty {
                                            unit = extractedUnit
                                        }
                                    }
                                }
                                
                                // Extract flag if available
                                if match.numberOfRanges >= 4 {
                                    if let flagRange = Range(match.range(at: 3), in: valueLine) {
                                        let extractedFlag = String(valueLine[flagRange]).trimmingCharacters(in: .whitespaces)
                                        if !extractedFlag.isEmpty {
                                            flag = extractedFlag
                                        }
                                    }
                                }
                                
                                print("      Extracted: Value=\(extractedValue), Unit=\(unit), Flag=\(flag)")
                                break
                            }
                        }
                    }
                }
                
                // If we still don't have a value, try to extract any number
                if value == nil {
                    let numberPattern = "([\\d\\.]+)"
                    if let regex = try? NSRegularExpression(pattern: numberPattern, options: []) {
                        if let match = regex.firstMatch(in: valueLine, options: [], range: NSRange(valueLine.startIndex..., in: valueLine)) {
                            if let valueRange = Range(match.range(at: 1), in: valueLine) {
                                let valueString = String(valueLine[valueRange])
                                value = Double(valueString)
                                print("      Extracted just value: \(valueString)")
                            }
                        }
                    }
                }
                
                guard let extractedValue = value else {
                    print("      Could not extract numeric value")
                    return nil
                }
                
                // Clean and validate the test name
                let cleanedName = cleanTestName(testName)
                guard isValidTestName(cleanedName) else {
                    print("      Invalid test name: '\(cleanedName)'")
                    return nil
                }
                
                // Create explanation with flag if present
                var explanation = "Imported from PDF lab report - Date: \(dateString) (date + test name + value)"
                if !flag.isEmpty {
                    explanation += " - Flag: \(flag)"
                }
                
                let result = TestResult(
                    name: cleanedName,
                    value: extractedValue,
                    unit: unit,
                    referenceRange: "N/A",
                    explanation: explanation
                )
                
                print("      Successfully created date + test name + value result: \(cleanedName) = \(extractedValue) \(unit)")
                return result
            }
        }
        
        return nil
    }
    
    /// Specialized parsing for Date Name LongSpace Data format
    /// This handles the specific format: Date + Space + Name + LongSpace + Data
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
        
        // If text after date is empty or very short, this line is incomplete
        if afterDate.isEmpty || afterDate.count < 3 {
            print("      Text after date is too short or empty, line appears incomplete")
            return nil
        }
        
        // Try to find the "long space" that separates name from data
        // Look for 3 or more consecutive spaces
        let longSpacePattern = "\\s{3,}"
        if let longSpaceRegex = try? NSRegularExpression(pattern: longSpacePattern, options: []) {
            if let longSpaceMatch = longSpaceRegex.firstMatch(in: afterDate, options: [], range: NSRange(afterDate.startIndex..., in: afterDate)) {
                // Found the long space, split on it
                let longSpaceRange = longSpaceMatch.range(at: 0)
                if let range = Range(longSpaceRange, in: afterDate) {
                    let beforeLongSpace = String(afterDate[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                    let afterLongSpace = String(afterDate[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    
                    print("      Found long space - Before: '\(beforeLongSpace)', After: '\(afterLongSpace)'")
                    
                    // Extract test name from before the long space
                    let testName = beforeLongSpace
                    
                    // Try to extract value and unit from after the long space
                    let valueUnitPattern = "([\\d\\.]+)\\s*([a-zA-Z/%]+)"
                    if let valueUnitRegex = try? NSRegularExpression(pattern: valueUnitPattern, options: []) {
                        if let valueUnitMatch = valueUnitRegex.firstMatch(in: afterLongSpace, options: [], range: NSRange(afterLongSpace.startIndex..., in: afterLongSpace)) {
                            guard let valueRange = Range(valueUnitMatch.range(at: 1), in: afterLongSpace),
                                  let unitRange = Range(valueUnitMatch.range(at: 2), in: afterLongSpace) else {
                                print("      Failed to extract value/unit ranges")
                                return nil
                            }
                            
                            let valueString = String(afterLongSpace[valueRange])
                            let unit = String(afterLongSpace[unitRange]).trimmingCharacters(in: .whitespaces)
                            
                            print("      Extracted - Name: '\(testName)', Value: '\(valueString)', Unit: '\(unit)'")
                            
                            guard let value = Double(valueString) else {
                                print("      Could not convert value to number: '\(valueString)'")
                                return nil
                            }
                            
                            // Clean and validate the test name
                            let cleanedName = cleanTestName(testName)
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
                    }
                }
            }
        }
        
        // Fallback: If no long space found, try more flexible patterns
        print("      No long space found, trying flexible patterns")
        let valueUnitPatterns = [
            "([A-Za-z\\s\\-]+)\\s{2,}([\\d\\.]+)\\s*([a-zA-Z/%]+)",  // Name + 2+ spaces + Value + Unit
            "([A-Za-z\\s\\-]+)\\s+([\\d\\.]+)\\s*([a-zA-Z/%]+)",     // Name + Space + Value + Unit
            "([A-Za-z\\s\\-]+)([\\d\\.]+)\\s*([a-zA-Z/%]+)"          // Name + Value + Unit (no space)
        ]
        
        var testName = ""
        var valueString = ""
        var unit = ""
        
        for pattern in valueUnitPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                if let match = regex.firstMatch(in: afterDate, options: [], range: NSRange(afterDate.startIndex..., in: afterDate)) {
                    guard let nameRange = Range(match.range(at: 1), in: afterDate),
                          let valRange = Range(match.range(at: 2), in: afterDate),
                          let unitRange = Range(match.range(at: 3), in: afterDate) else {
                        continue
                    }
                    
                    testName = String(afterDate[nameRange]).trimmingCharacters(in: .whitespaces)
                    valueString = String(afterDate[valRange])
                    unit = String(afterDate[unitRange]).trimmingCharacters(in: .whitespaces)
                    
                    print("      Fallback pattern '\(pattern)' matched - Name: '\(testName)', Value: '\(valueString)', Unit: '\(unit)'")
                    break
                }
            }
        }
        
        guard !testName.isEmpty && !valueString.isEmpty else {
            print("      Could not extract test name, value, or unit from fallback patterns")
            return nil
        }
        
        guard let value = Double(valueString) else {
            print("      Could not convert value to number: '\(valueString)'")
            return nil
        }
        
        // Clean and validate the test name
        let cleanedName = cleanTestName(testName)
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
        
        print("      Successfully created specialized result (fallback): \(cleanedName) = \(value) \(unit)")
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
    
    /// Returns a description of the regex pattern for debugging
    private func getPatternDescription(for index: Int) -> String {
        switch index {
        case 0: return "Date Name LongSpace Data (MM/DD/YYYY format)"
        case 1: return "Date Name LongSpace Data (YYYY/MM/DD format)"
        case 2: return "Date Name Data (MM/DD/YYYY format, any spacing)"
        case 3: return "Date Name Data (YYYY/MM/DD format, any spacing)"
        case 4: return "Test Name: Value Unit (Reference Range)"
        case 5: return "Test Name: Value Unit"
        case 6: return "Test Name: Value Unit [Flag]"
        case 7: return "Test Name: <Value Unit"
        case 8: return "TestName Value Unit"
        case 9: return "TestName Value.Unit"
        case 10: return "TestName Value Unit (flexible)"
        case 11: return "Test Name Only (no value/unit)"
        case 12: return "Value Unit Only (no test name)"
        default: return "Unknown Pattern"
        }
    }
}
