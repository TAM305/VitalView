import SwiftUI
import CoreData
import UniformTypeIdentifiers
import LocalAuthentication

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SettingsView: View {
    @ObservedObject var viewModel: BloodTestViewModel
    @State private var showingDeleteConfirmation = false
    @State private var showingExportSheet = false
    @State private var showingImportPicker = false
    @State private var exportData: Data?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isAuthenticated = false
    @State private var lastAuthenticationTime: Date?
    @State private var isBiometricAvailable = false
    @State private var showingPasscodeFallback = false
    @State private var showingAboutApp = false
    
    private let authenticationTimeout: TimeInterval = 300 // 5 minutes
    
    // App version information
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        isBiometricAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    private func authenticateWithPasscode(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication,
                                 localizedReason: "Access your blood test records") { success, error in
                DispatchQueue.main.async {
                    if success {
                        lastAuthenticationTime = Date()
                    }
                    completion(success)
                }
            }
        } else {
            if let error = error {
                alertMessage = "Authentication failed: \(error.localizedDescription)"
                showingAlert = true
            }
            completion(false)
        }
    }
    
    private func authenticateUser(completion: @escaping (Bool) -> Void) {
        // Check if we need to re-authenticate
        if let lastAuth = lastAuthenticationTime,
           Date().timeIntervalSince(lastAuth) < authenticationTimeout {
            completion(true)
            return
        }
        
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, 
                                 localizedReason: "Access your blood test records") { success, error in
                DispatchQueue.main.async {
                    if success {
                        lastAuthenticationTime = Date()
                        completion(true)
                    } else {
                        // If biometrics fail, show passcode fallback
                        showingPasscodeFallback = true
                        authenticateWithPasscode(completion: completion)
                    }
                }
            }
        } else {
            // If biometrics aren't available, use passcode
            authenticateWithPasscode(completion: completion)
        }
    }
    
    private func performAuthenticatedAction(_ action: @escaping () -> Void) {
        authenticateUser { success in
            if success {
                action()
            } else {
                showingAlert = true
                alertMessage = "Authentication failed. Please try again."
            }
        }
    }
    
    private func encodeData() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(viewModel.bloodTests)
            print("Successfully encoded \(viewModel.bloodTests.count) blood tests")
            return data
        } catch {
            print("Failed to encode blood tests: \(error)")
            alertMessage = "Failed to export data: \(error.localizedDescription)"
            showingAlert = true
            return nil
        }
    }
    
    private func importData(_ data: Data) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        print("=== Import Debug ===")
        print("Attempting to decode data of size: \(data.count)")
        
        // Try to get a preview of the JSON content
        if let jsonString = String(data: data, encoding: .utf8) {
            let previewLength = min(500, jsonString.count)
            let preview = String(jsonString.prefix(previewLength))
            print("JSON preview (first \(previewLength) characters):")
            print(preview)
            if jsonString.count > previewLength {
                print("... (truncated)")
            }
        }
        
        // First try to decode as enhanced lab results format (most comprehensive)
        do {
            let enhancedResults = try JSONSerialization.jsonObject(with: data, options: [])
            print("Successfully decoded as enhanced lab results format")
            importEnhancedLabResults(enhancedResults)
            return
        } catch {
            print("Failed to decode as enhanced lab results format: \(error)")
        }
        
        // If that fails, try to decode as standard BloodTest format
        do {
            let tests = try decoder.decode([BloodTest].self, from: data)
            print("Successfully decoded as standard BloodTest format: \(tests.count) tests")
            for test in tests {
                viewModel.addTest(test)
            }
            alertMessage = "Data imported successfully"
            return
        } catch {
            print("Failed to decode as standard BloodTest format: \(error)")
        }
        
        // If that fails, try to decode as comprehensive health data format
        do {
            let healthData = try JSONSerialization.jsonObject(with: data, options: [])
            print("Successfully decoded as comprehensive health data format")
            importComprehensiveHealthData(healthData)
            return
        } catch {
            print("Failed to decode as comprehensive health data format: \(error)")
            print("Error details: \(error.localizedDescription)")
            
            // Try to get more specific error information
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("Missing key: \(key.stringValue) at path: \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    print("Type mismatch: expected \(type) at path: \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("Value not found: expected \(type) at path: \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("Data corrupted at path: \(context.codingPath)")
                @unknown default:
                    print("Unknown decoding error")
                }
            }
        }
        
        // If that fails, try to decode as VA lab format
        do {
            let vaLabData = try JSONSerialization.jsonObject(with: data, options: [])
            print("Successfully decoded as VA lab format")
            importVALabData(vaLabData)
            return
        } catch {
            print("Failed to decode as VA lab format: \(error)")
        }
        
        // If that fails, try to decode as simple lab results format
        do {
            let simpleResults = try JSONSerialization.jsonObject(with: data, options: [])
            print("Successfully decoded as simple lab results format")
            importSimpleLabResults(simpleResults)
            return
        } catch {
            print("Failed to decode as simple lab results format: \(error)")
        }
        
        // If that fails, try to decode as comprehensive lab data format
        do {
            let comprehensiveData = try JSONSerialization.jsonObject(with: data, options: [])
            print("Successfully decoded as comprehensive lab data format")
            importComprehensiveLabData(comprehensiveData)
            return
        } catch {
            print("Failed to decode as comprehensive lab data format: \(error)")
        }
        
        // If all fail, show error
        print("Failed to decode data in any format")
        alertMessage = "Failed to import data: Unsupported format"
    }
    
    private func importVALabData(_ vaData: Any) {
        print("=== Starting VA Lab Import ===")
        
        // Since the old data structures no longer exist, we'll use a simplified approach
        // Convert the data to a JSON string and use the new import method
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: vaData, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            let result = viewModel.importLabData(jsonString)
            
            if result.success {
                print("✓ VA Lab data imported successfully")
                alertMessage = "VA Lab data imported successfully!"
            } else {
                print("❌ Failed to import VA Lab data: \(result.errorMessage ?? "Unknown error")")
                alertMessage = "Failed to import VA Lab data: \(result.errorMessage ?? "Unknown error")"
            }
            showingAlert = true
        } catch {
            print("❌ Failed to process VA Lab data: \(error)")
            alertMessage = "Failed to process VA Lab data: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func importComprehensiveHealthData(_ healthData: Any) {
        print("=== Starting Comprehensive Health Data Import ===")
        
        // Since the old data structures no longer exist, we'll use a simplified approach
        // Convert the data to a JSON string and use the new import method
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: healthData, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            let result = viewModel.importLabData(jsonString)
            
            if result.success {
                print("✓ Comprehensive health data imported successfully")
                alertMessage = "Comprehensive health data imported successfully!"
            } else {
                print("❌ Failed to import comprehensive health data: \(result.errorMessage ?? "Unknown error")")
                alertMessage = "Failed to import comprehensive health data: \(result.errorMessage ?? "Unknown error")"
            }
            showingAlert = true
        } catch {
            print("❌ Failed to process comprehensive health data: \(error)")
            alertMessage = "Failed to process comprehensive health data: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func importComprehensiveLabData(_ comprehensiveData: Any) {
        print("=== Starting Comprehensive Lab Data Import ===")
        
        // Since the old data structures no longer exist, we'll use a simplified approach
        // Convert the data to a JSON string and use the new import method
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: comprehensiveData, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            let result = viewModel.importLabData(jsonString)
            
            if result.success {
                print("✓ Lab data imported successfully")
                alertMessage = "Lab data imported successfully!"
            } else {
                print("❌ Failed to import lab data: \(result.errorMessage ?? "Unknown error")")
                alertMessage = "Failed to import lab data: \(result.errorMessage ?? "Unknown error")"
            }
            showingAlert = true
        } catch {
            print("❌ Failed to process comprehensive data: \(error)")
            alertMessage = "Failed to process lab data: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func importSimpleLabResults(_ simpleResults: Any) {
        print("=== Starting Simple Lab Results Import ===")
        
        // Convert the data to a JSON string and use the new import method
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: simpleResults, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            let result = viewModel.importLabData(jsonString)
            
            if result.success {
                print("✓ Lab results imported successfully")
                alertMessage = "Lab results imported successfully!"
            } else {
                print("❌ Failed to import lab results: \(result.errorMessage ?? "Unknown error")")
                alertMessage = "Failed to import lab results: \(result.errorMessage ?? "Unknown error")"
            }
            showingAlert = true
        } catch {
            print("❌ Failed to process simple results: \(error)")
            alertMessage = "Failed to process lab results: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func importEnhancedLabResults(_ enhancedResults: Any) {
        print("=== Starting Enhanced Lab Results Import ===")
        
        // Convert the data to a JSON string and use the new import method
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: enhancedResults, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            let result = viewModel.importLabData(jsonString)
            
            if result.success {
                print("✓ Enhanced lab results imported successfully")
                alertMessage = "Enhanced lab results imported successfully!"
            } else {
                print("❌ Failed to import enhanced lab results: \(result.errorMessage ?? "Unknown error")")
                alertMessage = "Failed to import enhanced lab results: \(result.errorMessage ?? "Unknown error")"
            }
            showingAlert = true
        } catch {
            print("❌ Failed to process enhanced results: \(error)")
            alertMessage = "Failed to process enhanced lab results: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func deleteAllData() {
        for test in viewModel.bloodTests {
            viewModel.deleteTest(test)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    if isBiometricAvailable {
                        Button(action: {
                            performAuthenticatedAction {
                                showingDeleteConfirmation = true
                            }
                        }) {
                            Label("Delete All Data", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                        
                        Button(action: {
                            performAuthenticatedAction {
                                if let data = encodeData() {
                                    exportData = data
                                    showingExportSheet = true
                                }
                            }
                        }) {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: {
                            performAuthenticatedAction {
                                showingImportPicker = true
                            }
                        }) {
                            Label("Import Data", systemImage: "square.and.arrow.down")
                        }
                    } else {
                        Text("Biometric authentication is required for data management")
                            .foregroundColor(.secondary)
                            .font(.footnote)
                    }
                } header: {
                    Text("Data Management")
                }
                
                Section {
                    NavigationLink(destination: PrivacyView()) {
                        Label("Privacy Policy", systemImage: "lock.shield")
                    }
                } header: {
                    Text("Privacy")
                }
                
                Section {
                    Button(action: { showingAboutApp = true }) {
                        Label("About VitalVu", systemImage: "info.circle")
                    }
                    
                    HStack {
                        Label("Version", systemImage: "tag")
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("App Information")
                }
            }
            .navigationTitle("Settings")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                checkBiometricAvailability()
            }
            .alert("Delete All Data", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAllData()
                    viewModel.loadTests()
                }
            } message: {
                Text("Are you sure you want to delete all your blood test data? This action cannot be undone.")
            }
            .alert("Export Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingExportSheet) {
                if let data = exportData {
                    ShareSheet(items: [data])
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("No Data to Export")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("There are no blood tests available to export.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("OK") {
                            showingExportSheet = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .sheet(isPresented: $showingAboutApp) {
                NavigationView {
                    AboutAppView()
                }
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    
                    // Start accessing the security-scoped resource
                    guard url.startAccessingSecurityScopedResource() else {
                        showingAlert = true
                        alertMessage = "Failed to access the selected file"
                        return
                    }
                    
                    defer {
                        // Stop accessing the security-scoped resource when done
                        url.stopAccessingSecurityScopedResource()
                    }
                    
                    do {
                        let data = try Data(contentsOf: url)
                        importData(data)
                        showingAlert = true
                        alertMessage = "Data imported successfully"
                    } catch {
                        showingAlert = true
                        alertMessage = "Failed to import data: \(error.localizedDescription)"
                    }
                    
                case .failure(let error):
                    showingAlert = true
                    alertMessage = "Failed to select file: \(error.localizedDescription)"
                }
            }
            .alert("Import Result", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - About App View
struct AboutAppView: View {
    @Environment(\.dismiss) private var dismiss
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // App Header
                VStack(spacing: 16) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    Text("VitalVu")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your personal health companion")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                
                // App Description
                VStack(alignment: .leading, spacing: 16) {
                    Text("About")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("VitalVu is a comprehensive health monitoring app that helps you track and understand your vital signs and blood test results. The app integrates with Apple HealthKit to provide real-time health metrics and offers detailed analysis of your blood work.")
                        .font(.body)
                        .lineSpacing(4)
                }
                
                // Features
                VStack(alignment: .leading, spacing: 16) {
                    Text("Key Features")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(icon: "heart.fill", title: "Vital Signs Monitoring", description: "Track heart rate, blood pressure, oxygen saturation, and more through HealthKit integration")
                        
                        FeatureRow(icon: "drop.fill", title: "Blood Test Analysis", description: "Enter and analyze blood test results with automatic reference range validation")
                        
                        FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Trend Analysis", description: "Visualize your health data over time with interactive charts and trend analysis")
                        
                        FeatureRow(icon: "lock.shield", title: "Privacy First", description: "All data stored locally with biometric authentication for maximum security")
                        
                        FeatureRow(icon: "square.and.arrow.up", title: "Data Export", description: "Export your health data for backup or sharing with healthcare providers")
                    }
                }
                
                // Technical Information
                VStack(alignment: .leading, spacing: 16) {
                    Text("Technical Information")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(title: "Platform", value: "iOS 15.0+")
                        InfoRow(title: "Framework", value: "SwiftUI")
                        InfoRow(title: "Health Integration", value: "HealthKit")
                        InfoRow(title: "Data Storage", value: "Core Data")
                        InfoRow(title: "Authentication", value: "Local Authentication")
                    }
                }
                
                // Privacy Notice
                VStack(alignment: .leading, spacing: 16) {
                    Text("Privacy & Security")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Your health data is stored locally on your device and is never transmitted to external servers. The app uses Apple's HealthKit framework to access health data only with your explicit permission. All data management features require biometric authentication for added security.")
                        .font(.body)
                        .lineSpacing(4)
                }
                
                // Support
                VStack(alignment: .leading, spacing: 16) {
                    Text("Support")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("For support, feature requests, or bug reports, please contact us through the App Store review system or your preferred support channel.")
                        .font(.body)
                        .lineSpacing(4)
                    
                    // Contact Email
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Contact the Developer")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Button(action: {
                            if let url = URL(string: "mailto:alexthegreat4@icloud.com?subject=VitalVu%20Support%20Request") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(.blue)
                                Text("alexthegreat4@icloud.com")
                                    .foregroundColor(.blue)
                                    .underline()
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text("Email us directly for support, feature requests, comments, or concerns.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                    }
                }
                
                // Website
                VStack(alignment: .leading, spacing: 16) {
                    Text("Website")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Button(action: {
                        if let url = URL(string: "https://vitvu.com/") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.blue)
                            Text("https://vitvu.com/")
                                .foregroundColor(.blue)
                                .underline()
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text("Visit our website to learn more about Vitvu, sign up for beta testing, and stay updated on new features and developments.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
        .navigationTitle("About")
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

// MARK: - Helper Views
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
} 
