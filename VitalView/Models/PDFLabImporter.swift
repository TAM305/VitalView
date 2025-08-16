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
            completion("")
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion("")
                return
            }
            
            // Extract text with bounding boxes for better spatial reconstruction
            let textElements = observations.compactMap { observation -> (String, CGRect)? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                return (candidate.string, observation.boundingBox)
            }
            
            // Sort by vertical position first, then horizontal for same-line elements
            let sortedElements = textElements.sorted { first, second in
                if abs(first.1.minY - second.1.minY) < 0.15 { // Increased tolerance for Y positions
                    return first.1.minX < second.1.minX
                }
                return first.1.minY > second.1.minY // Sort top to bottom
            }
            
            // Reconstruct lines by grouping elements that are horizontally aligned
            var reconstructedLines: [String] = []
            var currentLine: [String] = []
            var lastY: CGFloat = -1
            
            for (text, boundingBox) in sortedElements {
                if lastY == -1 { // First element
                    currentLine.append(text)
                    lastY = boundingBox.minY
                } else if abs(boundingBox.minY - lastY) < 0.08 { // Increased tolerance for line grouping
                    currentLine.append(text)
                } else { // New line
                    if !currentLine.isEmpty {
                        reconstructedLines.append(currentLine.joined(separator: " "))
                    }
                    currentLine = [text]
                    lastY = boundingBox.minY
                }
            }
            if !currentLine.isEmpty { // Add the last line
                reconstructedLines.append(currentLine.joined(separator: " "))
            }
            
            let extractedText = reconstructedLines.joined(separator: "\n")
            print("OCR: Extracted \(extractedText.count) characters from image")
            print("OCR: Reconstructed \(reconstructedLines.count) lines")
            
            // Debug: Print first few reconstructed lines
            for (i, line) in reconstructedLines.prefix(5).enumerated() {
                print("OCR Line \(i + 1): '\(line)'")
            }
            
            completion(extractedText)
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
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
        
        // First, try to reconstruct fragmented lines that might contain complete lab results
        let reconstructedLines = reconstructFragmentedLines(lines)
        print("=== After Reconstruction ===")
        print("Total reconstructed lines: \(reconstructedLines.count)")
        for (index, line) in reconstructedLines.prefix(10).enumerated() {
            print("Reconstructed Line \(index + 1): '\(line)'")
        }
        print("=== End Reconstructed Lines ===")
        
        // Look for lab results section markers
        var labResultsStartIndex = -1
        for (index, line) in reconstructedLines.enumerated() {
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
            labResultsStartIndex = max(0, reconstructedLines.count / 3)
            print("=== No specific section found, starting from line \(labResultsStartIndex + 1) ===")
        }
        
        // Show lines around the lab results section
        let startIndex = max(0, labResultsStartIndex - 2)
        let endIndex = min(reconstructedLines.count, labResultsStartIndex + 8)
        print("=== Lab Results Section Preview ===")
        for index in startIndex..<endIndex {
            print("Line \(index + 1): '\(reconstructedLines[index])'")
        }
        print("=== End Lab Results Preview ===")
        
        var results: [TestResult] = []
        
        // Parse from the lab results section onwards
        var index = labResultsStartIndex
        while index < reconstructedLines.count {
            let line = reconstructedLines[index]
            
            // Try to parse as clean PDF format first (Date + TestName + Value on same line)
            if let result = parseCleanDateTestNameValue(from: line) {
                print("Line \(index + 1): Found clean PDF format result - \(result.name): \(result.value) \(result.unit)")
                results.append(result)
                index += 1
            } else if let result = parseLabLine(line) {
                print("Line \(index + 1): Found single-line result - \(result.name): \(result.value) \(result.unit)")
                results.append(result)
                index += 1
            } else {
                // Try to parse as multi-line format (Date, Test Name, Results)
                if let multiLineResult = parseMultiLineLabResult(lines: reconstructedLines, startIndex: index) {
                    print("Lines \(index + 1)-\(index + multiLineResult.lineCount): Found multi-line result - \(multiLineResult.result.name): \(multiLineResult.result.value) \(multiLineResult.result.unit)")
                    results.append(multiLineResult.result)
                    index += multiLineResult.lineCount
                } else {
                    // Try to parse date + test name + value (common OCR pattern)
                    if let dateTestValueResult = parseDateTestNameValue(lines: reconstructedLines, currentIndex: index) {
                        print("Lines \(index + 1)-\(index + 2): Found date + test name + value - \(dateTestValueResult.name): \(dateTestValueResult.value) \(dateTestValueResult.unit)")
                        results.append(dateTestValueResult)
                        index += 2 // Skip both lines since we used them
                    } else if let testValueResult = parseTestNameValuePair(lines: reconstructedLines, currentIndex: index) {
                        print("Lines \(index + 1)-\(index + 2): Found test name + value pair - \(testValueResult.name): \(testValueResult.value) \(testValueResult.unit)")
                        results.append(testValueResult)
                        index += 2 // Skip both lines since we used them
                    } else {
                        // Try to combine fragmented lines (especially useful for OCR output)
                        if let fragmentedResult = combineFragmentedLines(lines: reconstructedLines, currentIndex: index) {
                            print("Lines \(index + 1)-\(index + 3): Found fragmented result - \(fragmentedResult.name): \(fragmentedResult.value) \(fragmentedResult.unit)")
                            results.append(fragmentedResult)
                            index += 3 // Skip all three lines since we used them
                        } else {
                            // Try to combine with adjacent lines (legacy method)
                            if let combinedResult = tryCombineAdjacentLines(lines: reconstructedLines, currentIndex: index) {
                                print("Lines \(index + 1)-\(index + 2): Found combined result - \(combinedResult.name): \(combinedResult.value) \(combinedResult.unit)")
                                results.append(combinedResult)
                                index += 2 // Skip both lines since we used them
                            } else {
                                // Try complex line parsing for lines with multiple components
                                if let complexResult = parseComplexLine(line) {
                                    print("Line \(index + 1): Found complex line result - \(complexResult.name): \(complexResult.value) \(complexResult.unit)")
                                    results.append(complexResult)
                                    index += 1
                                } else {
                                    // No result found, move to next line
                                    index += 1
                                }
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
                            
                            // Try to extract unit from after the number
                            let afterNumber = String(line3[valueRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                            var extractedUnit = "N/A"
                            if !afterNumber.isEmpty {
                                let unitPattern = "^([a-zA-Z/%]+)"
                                if let unitRegex = try? NSRegularExpression(pattern: unitPattern, options: []) {
                                    if let unitMatch = unitRegex.firstMatch(in: afterNumber, options: [], range: NSRange(afterNumber.startIndex..., in: afterNumber)) {
                                        if let unitRange = Range(unitMatch.range(at: 1), in: afterNumber) {
                                            extractedUnit = String(afterNumber[unitRange])
                                            print("        Extracted unit from after number: '\(extractedUnit)'")
                                        }
                                    }
                                }
                            }
                            
                            // Check if this looks like a date component before accepting it as a lab value
                            if let extractedValue = Double(valueString) {
                                if isDateComponent(extractedValue, extractedUnit) {
                                    print("        Rejected as date component: \(extractedValue) \(extractedUnit)")
                                    return nil
                                }
                                
                                value = extractedValue
                                unit = extractedUnit
                                print("        Successfully extracted: \(extractedValue) \(extractedValue)")
                            } else {
                                print("        Could not convert '\(valueString)' to number")
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
                    
                    // Validate that we have enough capture groups before proceeding
                    let expectedGroups = getExpectedCaptureGroups(for: index)
                    if match.numberOfRanges < expectedGroups {
                        print("    Pattern \(index) needs \(expectedGroups) groups but only has \(match.numberOfRanges), skipping")
                        continue
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
    
    /// Extracts a fallback result when no specific pattern matches
    /// This is a last resort method that tries to extract any meaningful information
    /// - Parameter line: Line of text to extract from
    /// - Returns: TestResult if extraction was successful, nil otherwise
    private func extractFallbackResult(from line: String) -> TestResult? {
        print("    Extracting fallback result from: '\(line)'")
        
        // Skip lines that are clearly not lab results
        let lowerLine = line.lowercased()
        if lowerLine.contains("date") || lowerLine.contains("test") || lowerLine.contains("result") ||
           lowerLine.contains("reference") || lowerLine.contains("range") || lowerLine.contains("normal") {
            print("      Line appears to be a header or label, skipping")
            return nil
        }
        
        // Try to extract any number from the line
        guard let numberMatch = line.range(of: #"\d+\.?\d*"#, options: .regularExpression) else {
            print("      No number found in line")
            return nil
        }
        
        let numberString = String(line[numberMatch])
        guard let value = Double(numberString) else {
            print("      Could not convert '\(numberString)' to number")
            return nil
        }
        
        // Check if this looks like a date component
        let unit = extractUnit(from: line, after: numberMatch)
        if isDateComponent(value, unit) {
            print("      Rejected as date component: \(value) '\(unit)'")
            return nil
        }
        
        // Try to extract a meaningful test name
        var testName = "Lab Test"
        
        // First, try to extract letters that might be a test name
        let letters = line.components(separatedBy: CharacterSet.letters.inverted)
            .filter { $0.count >= 3 && $0.range(of: #"[A-Za-z]{3,}"#, options: .regularExpression) != nil }
            .first ?? ""
        
        if !letters.isEmpty {
            testName = letters.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // Try to find common lab test keywords in the line
            let labTestKeywords = [
                "GLUCOSE", "CHOLESTEROL", "WBC", "RBC", "HEMOGLOBIN", "HEMATOCRIT",
                "PLATELET", "SODIUM", "POTASSIUM", "CHLORIDE", "CO2", "BUN", "CREATININE",
                "CALCIUM", "MAGNESIUM", "PHOSPHORUS", "ALBUMIN", "TOTAL_PROTEIN",
                "BILIRUBIN", "AST", "ALT", "ALKALINE_PHOSPHATASE", "GGT", "LDH",
                "TROPONIN", "CK", "CK_MB", "BNP", "CRP", "ESR", "FERRITIN",
                "VITAMIN_D", "VITAMIN_B12", "FOLATE", "IRON", "TIBC", "TRANSFERRIN",
                "NEUTROPHIL", "LYMPHOCYTE", "MONOCYTE", "EOSINOPHIL", "BASOPHIL",
                "INR", "PTT", "FIBRINOGEN", "D_DIMER", "FOLIC_ACID", "VITAMIN_B6"
            ]
            
            let upperLine = line.uppercased()
            for keyword in labTestKeywords {
                if upperLine.contains(keyword) {
                    testName = keyword.replacingOccurrences(of: "_", with: " ")
                    break
                }
            }
        }
        
        // Clean the test name
        testName = cleanTestName(testName)
        if !isValidTestName(testName) {
            testName = "Lab Test"
        }
        
        // Additional validation: check if the value is reasonable for a lab test
        if value < 0.01 || value > 10000 {
            print("      Value \(value) is outside reasonable lab test range, skipping")
            return nil
        }
        
        // Check if the unit looks like a real lab unit
        let realLabUnits = ["mg/dL", "g/dL", "mEq/L", "mmol/L", "ng/mL", "pg/mL", "U/L", "IU/L", "K/uL", "M/uL", "%", "ratio"]
        let hasRealUnit = realLabUnits.contains { realLabUnits.contains($0) } || unit.isEmpty
        
        if !hasRealUnit && unit.count > 10 {
            print("      Unit '\(unit)' looks like garbage text, skipping")
            return nil
        }
        
        print("      Fallback extraction successful:")
        print("        Test: \(testName)")
        print("        Value: \(value)")
        print("        Unit: \(unit)")
        
        return TestResult(
            name: testName,
            value: value,
            unit: unit,
            referenceRange: "N/A",
            explanation: "Imported from PDF lab report (fallback parsing)"
        )
    }
    
    /// Creates a TestResult from a regex match
    /// - Parameters:
    ///   - match: The regex match result
    ///   - line: The original line of text
    ///   - pattern: The regex pattern used
    ///   - patternIndex: Index of the pattern for context
    /// - Returns: TestResult object
    private func createTestResult(from match: NSTextCheckingResult, in line: String, pattern: String, patternIndex: Int) -> TestResult? {
        print("    Creating TestResult from pattern: \(pattern)")
        print("    Match ranges: \(match.numberOfRanges)")
        
        print("    Pattern index: \(patternIndex) - \(getPatternDescription(for: patternIndex))")
        
        // Validate that we have enough capture groups before proceeding
        let expectedGroups = getExpectedCaptureGroups(for: patternIndex)
        guard match.numberOfRanges >= expectedGroups else {
            print("    Pattern \(patternIndex) needs \(expectedGroups) groups but only has \(match.numberOfRanges)")
            return nil
        }
        
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
                
                guard let value = Double(valueString) else {
                    print("    Could not convert value to number: '\(valueString)'")
                    return nil
                }
                
                let cleanedName = cleanTestName(name)
                guard isValidTestName(cleanedName) else {
                    print("    Invalid test name in generic fallback: '\(cleanedName)'")
                    return nil
                }
                
                return TestResult(
                    name: cleanedName,
                    value: value,
                    unit: unit,
                    referenceRange: "N/A",
                    explanation: "Imported from PDF lab report (generic fallback)"
                )
            } else {
                // We only have value and unit
                guard let valueRange = Range(match.range(at: 1), in: line),
                      let unitRange = Range(match.range(at: 2), in: line) else {
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
                    explanation: "Imported from PDF lab report (generic fallback - value/unit only)"
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
            
            // Check if this looks like a date component before accepting it as a lab value
            if isDateComponent(value, unit) {
                print("      Rejected as date component: \(value) \(unit)")
                return nil
            }
            
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
                            
                            // Check if this looks like a date component before accepting it as a lab value
                            if let extractedValue = Double(valueString) {
                                if isDateComponent(extractedValue, "N/A") {
                                    print("      Rejected as date component: \(extractedValue)")
                                    return nil
                                }
                                
                                value = extractedValue
                                print("      Extracted just value: \(valueString)")
                            }
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
                                
                                // Check if this looks like a date component before accepting it as a lab value
                                if let extractedValue = Double(valueString) {
                                    if isDateComponent(extractedValue, "N/A") {
                                        print("      Rejected as date component: \(extractedValue)")
                                        return nil
                                    }
                                    
                                    value = extractedValue
                                    print("      Extracted just value: \(valueString)")
                                }
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
    
    /// Parses clean PDF format where Date + TestName + Value are on the same line
    /// This is the primary method for the clean PDF format shown in the screenshot
    /// - Parameter line: Single line containing date, test name, and value
    /// - Returns: TestResult if found, nil otherwise
    private func parseCleanDateTestNameValue(from line: String) -> TestResult? {
        print("    Trying clean date-testname-value pattern on: '\(line)'")
        
        // More flexible patterns that handle OCR noise and variations
        let cleanPatterns = [
            // Pattern 0: Date + Test Name + Value with flexible spacing (most common)
            "(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4})\\s+([A-Za-z\\s\\-]+)\\s+([\\d\\.]+)",
            // Pattern 1: Date + Test Name + Value + Unit
            "(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4})\\s+([A-Za-z\\s\\-]+)\\s+([\\d\\.]+)\\s+([a-zA-Z/%]+)",
            // Pattern 2: Date + Test Name + Value + Unit + Flag
            "(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4})\\s+([A-Za-z\\s\\-]+)\\s+([\\d\\.]+)\\s+([a-zA-Z/%]+)\\s*([HL#\\$])?",
            // Pattern 3: Very flexible - any date format with test name and value
            "(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4})\\s*([A-Za-z\\s\\-]+)\\s*([\\d\\.]+)",
            // Pattern 4: Handle OCR noise with extra characters
            "(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4})\\s*([A-Za-z\\s\\-]+)\\s*([\\d\\.]+)\\s*([a-zA-Z/%]+)?",
            // Pattern 5: Alternative date separators: dots, dashes
            "(\\d{1,2}[.-]\\d{1,2}[.-]\\d{2,4})\\s+([A-Za-z\\s\\-]+)\\s+([\\d\\.]+)",
            // Pattern 6: Handle dates with year first format
            "(\\d{4}[/-]\\d{1,2}[/-]\\d{1,2})\\s+([A-Za-z\\s\\-]+)\\s+([\\d\\.]+)",
            // Pattern 7: Handle potential OCR artifacts in dates
            "(\\d{1,2}[./\\-]\\d{1,2}[./\\-]\\d{2,4})\\s+([A-Za-z\\s\\-]+)\\s+([\\d\\.]+)",
            // Pattern 8: Handle cases where OCR might have inserted extra characters
            "(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4})\\s*([^\\d]*[A-Za-z][A-Za-z\\s\\-]*)\\s*([\\d\\.]+)",
            // Pattern 9: Handle very noisy OCR with flexible spacing
            "(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4})\\s*([A-Za-z\\s\\-]+)\\s*([\\d\\.]+)\\s*([^\\d\\s]*)",
            // Pattern 10: Handle dates with single digits and flexible spacing
            "(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4})\\s*([A-Za-z\\s\\-]+)\\s*([\\d\\.]+)",
            // Pattern 11: Handle dates with potential OCR artifacts
            "(\\d{1,2}[./\\-]\\d{1,2}[./\\-]\\d{2,4})\\s*([A-Za-z\\s\\-]+)\\s*([\\d\\.]+)",
            // Pattern 12: Handle dates with year first and flexible spacing
            "(\\d{4}[/-]\\d{1,2}[/-]\\d{1,2})\\s*([A-Za-z\\s\\-]+)\\s*([\\d\\.]+)",
            // Pattern 13: Handle very flexible spacing for noisy OCR
            "(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4})\\s*([A-Za-z\\s\\-]+)\\s*([\\d\\.]+)",
            // Pattern 14: Handle dates with alternative separators and flexible spacing
            "(\\d{1,2}[.-]\\d{1,2}[.-]\\d{2,4})\\s*([A-Za-z\\s\\-]+)\\s*([\\d\\.]+)"
        ]
        
        for (index, pattern) in cleanPatterns.enumerated() {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let regexMatch = regex.firstMatch(in: line, range: NSRange(location: 0, length: line.count)) {
                
                // Ensure we have at least 3 capture groups and the line is not empty
                guard regexMatch.numberOfRanges >= 3, !line.isEmpty else { continue }
                
                let nsString = line as NSString
                let dateRange = regexMatch.range(at: 1)
                let testNameRange = regexMatch.range(at: 2)
                let valueRange = regexMatch.range(at: 3)
                
                // Validate ranges before using them
                guard dateRange.location != NSNotFound && dateRange.location >= 0 && dateRange.length >= 0 && dateRange.location + dateRange.length <= nsString.length,
                      testNameRange.location != NSNotFound && testNameRange.location >= 0 && testNameRange.length >= 0 && testNameRange.location + testNameRange.length <= nsString.length,
                      valueRange.location != NSNotFound && valueRange.location >= 0 && valueRange.length >= 0 && valueRange.location + valueRange.length <= nsString.length else {
                    print("      Pattern \(index) matched but ranges are invalid - dateRange: \(dateRange), testNameRange: \(testNameRange), valueRange: \(valueRange), stringLength: \(nsString.length)")
                    continue
                }
                
                let dateString = nsString.substring(with: dateRange).trimmingCharacters(in: .whitespacesAndNewlines)
                let testName = nsString.substring(with: testNameRange).trimmingCharacters(in: .whitespacesAndNewlines)
                let valueString = nsString.substring(with: valueRange).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Extract unit if available (patterns 1, 2, 4, 9)
                var unit = ""
                if [1, 2, 4, 9].contains(index) && regexMatch.numberOfRanges > 4 {
                    let unitRange = regexMatch.range(at: 4)
                    if unitRange.location != NSNotFound && unitRange.location >= 0 && unitRange.length >= 0 && unitRange.location + unitRange.length <= nsString.length {
                        unit = nsString.substring(with: unitRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                
                // Extract flag if available (pattern 2)
                var flag = ""
                if index == 2 && regexMatch.numberOfRanges > 5 {
                    let flagRange = regexMatch.range(at: 5)
                    if flagRange.location != NSNotFound && flagRange.location >= 0 && flagRange.length >= 0 && flagRange.location + flagRange.length <= nsString.length {
                        flag = nsString.substring(with: flagRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                
                // Validate the extracted data
                guard let value = Double(valueString),
                      !testName.isEmpty,
                      testName.count >= 3 else {
                    print("      Pattern \(index) matched but validation failed")
                    continue
                }
                
                // Check if this looks like a date component being misinterpreted
                if isDateComponent(value, unit) {
                    print("      Rejected as date component: \(value) '\(unit)'")
                    continue
                }
                
                // Clean the test name
                let cleanedTestName = cleanTestName(testName)
                if !isValidTestName(cleanedTestName) {
                    print("      Test name validation failed: '\(cleanedTestName)'")
                    continue
                }
                
                // Additional validation: check if the test name looks like a real lab test
                let hasLabTestKeywords = ["GLUCOSE", "CHOLESTEROL", "WBC", "RBC", "HEMOGLOBIN", "HEMATOCRIT", 
                     "PLATELET", "SODIUM", "POTASSIUM", "CHLORIDE", "CO2", "BUN", "CREATININE",
                     "CALCIUM", "MAGNESIUM", "PHOSPHORUS", "ALBUMIN", "TOTAL_PROTEIN",
                     "BILIRUBIN", "AST", "ALT", "ALKALINE_PHOSPHATASE", "GGT", "LDH",
                     "TROPONIN", "CK", "CK_MB", "BNP", "CRP", "ESR", "FERRITIN",
                     "VITAMIN_D", "VITAMIN_B12", "FOLATE", "IRON", "TIBC", "TRANSFERRIN",
                     "NEUTROPHIL", "LYMPHOCYTE", "MONOCYTE", "EOSINOPHIL", "BASOPHIL",
                     "INR", "PTT", "FIBRINOGEN", "D_DIMER", "FOLIC_ACID", "VITAMIN_B6"].contains { keyword in
                    cleanedTestName.uppercased().contains(keyword)
                }
                
                if !hasLabTestKeywords && cleanedTestName.count < 4 {
                    print("      Test name too short or doesn't contain lab test keywords: '\(cleanedTestName)'")
                    continue
                }
                
                print("      Pattern \(index) matched successfully:")
                print("        Date: \(dateString)")
                print("        Test: \(cleanedTestName)")
                print("        Value: \(value) \(unit) \(flag)")
                
                return TestResult(
                    name: cleanedTestName,
                    value: value,
                    unit: unit,
                    referenceRange: "N/A",
                    explanation: "Imported from PDF lab report - Date: \(dateString) (clean format)"
                )
            }
        }
        
        print("      No clean pattern matched")
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
    
    /// Checks if a value/unit pair likely represents a date component rather than a lab result
    /// - Parameters:
    ///   - value: The numeric value extracted
    ///   - unit: The unit string extracted
    /// - Returns: true if the value/unit pair likely represents a date component
    private func isDateComponent(_ value: Double, _ unit: String) -> Bool {
        // Check if the unit looks like a date separator
        let dateSeparators = ["/", "-", ".", "\\", "|"]
        let isDateSeparator = dateSeparators.contains(unit)
        
        // Check if the value is in a typical date range
        let isTypicalDateValue = (value >= 1 && value <= 31) || (value >= 1900 && value <= 2030)
        
        // Check if the unit is empty or very short (common in date fragments)
        let isShortUnit = unit.count <= 2
        
        // Additional check: if the unit is just a single character that's a date separator
        let isSingleCharDateSeparator = unit.count == 1 && dateSeparators.contains(unit)
        
        // Check for specific date patterns in the unit
        let hasDatePattern = unit.range(of: #"^[/\-\.\\|]$"#, options: .regularExpression) != nil ||
                            unit.range(of: #"^\d{1,2}[/\-\.\\|]\d{1,2}[/\-\.\\|]\d{2,4}$"#, options: .regularExpression) != nil
        
        // Check if the value looks like a month (1-12) or day (1-31) with date-like unit
        let isMonthOrDay = (value >= 1 && value <= 31) && (isDateSeparator || hasDatePattern)
        
        // Check if the unit contains only date-related characters
        let isDateOnlyUnit = unit.range(of: #"^[/\-\.\\|\d]+$"#, options: .regularExpression) != nil && 
                            unit.range(of: #"[a-zA-Z]"#, options: .regularExpression) == nil
        
        // If we have a date separator, typical date value with short unit, or date-only unit, it's likely a date component
        if isDateSeparator || isSingleCharDateSeparator || hasDatePattern || isMonthOrDay || 
           (isTypicalDateValue && isShortUnit && (unit.isEmpty || isDateOnlyUnit)) {
            print("      Detected likely date component: \(value) '\(unit)'")
            return true
        }
        
        return false
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
    
    /// Reconstructs fragmented OCR lines that might contain complete lab results
    /// This is especially useful when OCR breaks up what should be single lines
    /// - Parameter lines: Original lines from OCR
    /// - Returns: Reconstructed lines with better formatting
    private func reconstructFragmentedLines(_ lines: [String]) -> [String] {
        print("=== Reconstructing Fragmented Lines ===")
        var reconstructedLines: [String] = []
        var i = 0
        
        while i < lines.count {
            let currentLine = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if currentLine.isEmpty { i += 1; continue }
            
            let hasDate = currentLine.range(of: #"^\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"#, options: .regularExpression) != nil ||
                          currentLine.range(of: #"^\d{4}[/-]\d{1,2}[/-]\d{1,2}"#, options: .regularExpression) != nil ||
                          currentLine.range(of: #"^\d{1,2}[.-]\d{1,2}[.-]\d{2,4}"#, options: .regularExpression) != nil ||
                          currentLine.range(of: #"^\d{4}[.-]\d{1,2}[.-]\d{1,2}"#, options: .regularExpression) != nil
            let hasTestName = currentLine.range(of: #"[A-Za-z]{3,}"#, options: .regularExpression) != nil
            let hasValue = currentLine.range(of: #"\d+\.?\d*"#, options: .regularExpression) != nil
            
            // Check if this line is just a date fragment (e.g., "05/01/2025" split into parts)
            let isDateFragment = currentLine.range(of: #"^\d{1,2}[/-]?$"#, options: .regularExpression) != nil ||
                                currentLine.range(of: #"^\d{1,2}[.-]?$"#, options: .regularExpression) != nil ||
                                currentLine.range(of: #"^[/-]\d{1,2}[/-]?$"#, options: .regularExpression) != nil ||
                                currentLine.range(of: #"^[.-]\d{1,2}[.-]?$"#, options: .regularExpression) != nil ||
                                currentLine.range(of: #"^\d{4}$"#, options: .regularExpression) != nil
            
            if hasDate && hasTestName && hasValue { // If line already looks complete
                print("  Line \(i + 1): Complete lab result detected")
                reconstructedLines.append(currentLine)
                i += 1
                continue
            }
            
            if isDateFragment { // If this is just a date fragment, try to combine with next lines
                var combinedLine = currentLine
                var nextIndex = i + 1
                var linesUsed = 1
                
                while nextIndex < lines.count && linesUsed < 5 { // Try up to 4 more lines
                    let nextLine = lines[nextIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                    if nextLine.isEmpty { nextIndex += 1; continue }
                    
                    let testCombined = combinedLine + nextLine
                    let combinedHasDate = testCombined.range(of: #"^\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"#, options: .regularExpression) != nil ||
                                          testCombined.range(of: #"^\d{4}[/-]\d{1,2}[/-]\d{1,2}"#, options: .regularExpression) != nil ||
                                          testCombined.range(of: #"^\d{1,2}[.-]\d{1,2}[.-]\d{2,4}"#, options: .regularExpression) != nil ||
                                          testCombined.range(of: #"^\d{4}[.-]\d{1,2}[.-]\d{1,2}"#, options: .regularExpression) != nil
                    let combinedHasTestName = testCombined.range(of: #"[A-Za-z]{3,}"#, options: .regularExpression) != nil
                    let combinedHasValue = testCombined.range(of: #"\d+\.?\d*"#, options: .regularExpression) != nil
                    
                    if combinedHasDate && combinedHasTestName && combinedHasValue {
                        combinedLine = testCombined
                        linesUsed += 1
                        nextIndex += 1
                        print("  Lines \(i + 1)-\(i + linesUsed): Combined date fragments into complete result")
                        break
                    } else if combinedHasDate && (combinedHasTestName || combinedHasValue) {
                        combinedLine = testCombined
                        linesUsed += 1
                        nextIndex += 1
                    } else { break }
                }
                
                if linesUsed > 1 {
                    reconstructedLines.append(combinedLine)
                    i += linesUsed
                    continue
                }
            }
            
            if hasDate && (hasTestName || hasValue) { // If line has date but is incomplete, try combining forward
                var combinedLine = currentLine
                var nextIndex = i + 1
                var linesUsed = 1
                
                while nextIndex < lines.count && linesUsed < 4 { // Try up to 3 more lines
                    let nextLine = lines[nextIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                    if nextLine.isEmpty { nextIndex += 1; continue }
                    
                    // Check if next line is just a unit or flag
                    let isUnitOrFlag = nextLine.range(of: #"^[a-zA-Z/%]+$"#, options: .regularExpression) != nil ||
                                      nextLine.range(of: #"^[HL#\\$]$"#, options: .regularExpression) != nil
                    
                    let testCombined = combinedLine + " " + nextLine
                    let combinedHasDate = testCombined.range(of: #"^\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"#, options: .regularExpression) != nil ||
                                          testCombined.range(of: #"^\d{4}[/-]\d{1,2}[/-]\d{1,2}"#, options: .regularExpression) != nil ||
                                          testCombined.range(of: #"^\d{1,2}[.-]\d{1,2}[.-]\d{2,4}"#, options: .regularExpression) != nil ||
                                          testCombined.range(of: #"^\d{4}[.-]\d{1,2}[.-]\d{1,2}"#, options: .regularExpression) != nil
                    let combinedHasTestName = testCombined.range(of: #"[A-Za-z]{3,}"#, options: .regularExpression) != nil
                    let combinedHasValue = testCombined.range(of: #"\d+\.?\d*"#, options: .regularExpression) != nil
                    
                    if combinedHasDate && combinedHasTestName && combinedHasValue {
                        combinedLine = testCombined
                        linesUsed += 1
                        nextIndex += 1
                        print("  Lines \(i + 1)-\(i + linesUsed): Combined into complete result")
                        break
                    } else if combinedHasDate && (combinedHasTestName || combinedHasValue) {
                        combinedLine = testCombined
                        linesUsed += 1
                        nextIndex += 1
                    } else if isUnitOrFlag { // Always combine units and flags
                        combinedLine = testCombined
                        linesUsed += 1
                        nextIndex += 1
                    } else { break }
                }
                
                reconstructedLines.append(combinedLine)
                i += linesUsed
                continue
            }
            
            if hasTestName && !hasDate && i > 0 { // If line has test name but no date, try combining backward
                let previousLine = reconstructedLines.last ?? ""
                let testCombined = previousLine + " " + currentLine
                let combinedHasDate = testCombined.range(of: #"^\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"#, options: .regularExpression) != nil ||
                                      testCombined.range(of: #"^\d{4}[/-]\d{1,2}[/-]\d{1,2}"#, options: .regularExpression) != nil ||
                                      testCombined.range(of: #"^\d{1,2}[.-]\d{1,2}[.-]\d{2,4}"#, options: .regularExpression) != nil ||
                                      testCombined.range(of: #"^\d{4}[.-]\d{1,2}[.-]\d{1,2}"#, options: .regularExpression) != nil
                let combinedHasTestName = testCombined.range(of: #"[A-Za-z]{3,}"#, options: .regularExpression) != nil
                let combinedHasValue = testCombined.range(of: #"\d+\.?\d*"#, options: .regularExpression) != nil
                
                if combinedHasDate && combinedHasTestName && combinedHasValue {
                    reconstructedLines[reconstructedLines.count - 1] = testCombined
                    print("  Combined with previous line: '\(testCombined)'")
                } else {
                    reconstructedLines.append(currentLine)
                }
            } else { // Keep the line as is
                reconstructedLines.append(currentLine)
            }
            i += 1
        }
        
        print("=== Reconstruction Complete ===")
        print("Original lines: \(lines.count)")
        print("Reconstructed lines: \(reconstructedLines.count)")
        
        // Debug: Show first few reconstructed lines
        for (i, line) in reconstructedLines.prefix(10).enumerated() {
            print("  Reconstructed \(i + 1): '\(line)'")
        }
        
        return reconstructedLines
    }

    /// Helper method to extract unit from text after a number
    private func extractUnit(from line: String, after numberMatch: Range<String.Index>) -> String {
        let afterNumber = String(line[numberMatch.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        if afterNumber.isEmpty {
            return ""
        }
        
        // Look for common unit patterns
        let unitPatterns = [
            #"^([a-zA-Z/%]+)"#,           // Basic units like "mg/dL", "%"
            #"^([a-zA-Z/%]+)\s*[HL#\$]"#, // Units with flags like "mg/dL H", "% L"
            #"^([a-zA-Z/%]+)\s*$"#        // Units at end of line
        ]
        
        for pattern in unitPatterns {
            if let unitMatch = afterNumber.range(of: pattern, options: .regularExpression) {
                let unit = String(afterNumber[unitMatch])
                // Clean up the unit (remove flags, extra spaces)
                let cleanedUnit = unit.replacingOccurrences(of: #"[HL#\$]"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanedUnit.isEmpty {
                    return cleanedUnit
                }
            }
        }
        
        return ""
    }

    /// Helper method to parse date strings into Date objects
    private func parseDate(from dateString: String) -> Date? {
        let dateFormatters = [
            DateFormatter(), // MM/dd/yyyy
            DateFormatter(), // MM-dd-yyyy
            DateFormatter(), // yyyy/MM/dd
            DateFormatter(), // yyyy-MM-dd
            DateFormatter()  // MM.dd.yyyy
        ]
        
        dateFormatters[0].dateFormat = "MM/dd/yyyy"
        dateFormatters[1].dateFormat = "MM-dd-yyyy"
        dateFormatters[2].dateFormat = "yyyy/MM/dd"
        dateFormatters[3].dateFormat = "yyyy-MM-dd"
        dateFormatters[4].dateFormat = "MM.dd.yyyy"
        
        for formatter in dateFormatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }

    /// Parses complex lines that may contain multiple values or are highly fragmented
    /// This method tries to intelligently extract the most likely lab result from complex text
    /// - Parameter line: Complex line that may contain multiple values
    /// - Returns: TestResult if extraction was successful, nil otherwise
    private func parseComplexLine(_ line: String) -> TestResult? {
        print("    Trying complex line parsing on: '\(line)'")
        
        // Split the line into potential components
        let components = line.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        print("      Line has \(components.count) components: \(components)")
        
        // Look for patterns like: [Date] [TestName] [Value] [Unit] [Flag]
        if components.count >= 3 {
            // Try to identify which component is which
            var dateComponent: String?
            var testNameComponent: String?
            var valueComponent: String?
            var unitComponent: String?
            
            for component in components {
                // Check if it's a date
                if dateComponent == nil && component.range(of: #"^\d{1,2}[/-]\d{1,2}[/-]\d{2,4}$"#, options: .regularExpression) != nil {
                    dateComponent = component
                    print("      Identified date component: \(component)")
                    continue
                }
                
                // Check if it's a value
                if valueComponent == nil && component.range(of: #"^\d+\.?\d*$"#, options: .regularExpression) != nil {
                    valueComponent = component
                    print("      Identified value component: \(component)")
                    continue
                }
                
                // Check if it's a unit
                if unitComponent == nil && component.range(of: #"^[a-zA-Z/%]+$"#, options: .regularExpression) != nil {
                    unitComponent = component
                    print("      Identified unit component: \(component)")
                    continue
                }
                
                // Check if it's a flag
                if component.range(of: #"^[HL#\\$]$"#, options: .regularExpression) != nil {
                    print("      Identified flag component: \(component)")
                    continue
                }
                
                // If it's not a date, value, unit, or flag, it's likely the test name
                if testNameComponent == nil && component.count >= 3 {
                    testNameComponent = component
                    print("      Identified test name component: \(component)")
                }
            }
            
            // Validate that we have the essential components
            guard let valueStr = valueComponent,
                  let value = Double(valueStr),
                  let testName = testNameComponent,
                  !testName.isEmpty else {
                print("      Missing essential components for lab result")
                return nil
            }
            
            // Check if this looks like a date component being misinterpreted
            if isDateComponent(value, unitComponent ?? "") {
                print("      Rejected as date component: \(value) '\(unitComponent ?? "")'")
                return nil
            }
            
            // Clean the test name
            let cleanedTestName = cleanTestName(testName)
            if !isValidTestName(cleanedTestName) {
                print("      Test name validation failed: '\(cleanedTestName)'")
                return nil
            }
            
            // Additional validation: check if the test name looks like a real lab test
            let hasLabTestKeywords = ["GLUCOSE", "CHOLESTEROL", "WBC", "RBC", "HEMOGLOBIN", "HEMATOCRIT", 
                     "PLATELET", "SODIUM", "POTASSIUM", "CHLORIDE", "CO2", "BUN", "CREATININE",
                     "CALCIUM", "MAGNESIUM", "PHOSPHORUS", "ALBUMIN", "TOTAL_PROTEIN",
                     "BILIRUBIN", "AST", "ALT", "ALKALINE_PHOSPHATASE", "GGT", "LDH",
                     "TROPONIN", "CK", "CK_MB", "BNP", "CRP", "ESR", "FERRITIN",
                     "VITAMIN_D", "VITAMIN_B12", "FOLATE", "IRON", "TIBC", "TRANSFERRIN",
                     "NEUTROPHIL", "LYMPHOCYTE", "MONOCYTE", "EOSINOPHIL", "BASOPHIL",
                     "INR", "PTT", "FIBRINOGEN", "D_DIMER", "FOLIC_ACID", "VITAMIN_B6"].contains { keyword in
                    cleanedTestName.uppercased().contains(keyword)
                }
            
            if !hasLabTestKeywords && cleanedTestName.count < 4 {
                print("      Test name too short or doesn't contain lab test keywords: '\(cleanedTestName)'")
                return nil
            }
            
            print("      Complex line parsing successful:")
            print("        Date: \(dateComponent ?? "N/A")")
            print("        Test: \(cleanedTestName)")
            print("        Value: \(value)")
            print("        Unit: \(unitComponent ?? "")")
            
            return TestResult(
                name: cleanedTestName,
                value: value,
                unit: unitComponent ?? "",
                referenceRange: "N/A",
                explanation: "Imported from PDF lab report (complex line parsing)"
            )
        }
        
        print("      Complex line parsing failed - insufficient components")
        return nil
    }

    /// Returns the expected number of capture groups for each pattern
    /// - Parameter patternIndex: Index of the pattern
    /// - Returns: Expected number of capture groups (including the full match as group 0)
    private func getExpectedCaptureGroups(for patternIndex: Int) -> Int {
        switch patternIndex {
        case 0, 1: // Date Name LongSpace Data patterns
            return 5 // Full match + date + name + value + unit
        case 2, 3: // Date Name Data patterns
            return 5 // Full match + date + name + value + unit
        case 4: // Test Name: Value Unit (Reference Range)
            return 5 // Full match + name + value + unit + reference range
        case 5, 6, 7: // Test Name: Value Unit patterns
            return 4 // Full match + name + value + unit
        case 8, 9, 10: // TestName Value Unit patterns
            return 4 // Full match + name + value + unit
        case 11: // Test name only
            return 2 // Full match + name
        case 12: // Value and unit only
            return 3 // Full match + value + unit
        default:
            return 4 // Generic fallback: full match + name + value + unit
        }
    }
}
