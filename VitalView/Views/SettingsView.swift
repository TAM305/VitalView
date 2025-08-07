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
        return try? encoder.encode(viewModel.bloodTests)
    }
    
    private func importData(_ data: Data) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let tests = try? decoder.decode([BloodTest].self, from: data) {
            for test in tests {
                viewModel.addTest(test)
            }
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
                                exportData = encodeData()
                                showingExportSheet = true
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
                        Label("About VitalView", systemImage: "info.circle")
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
            .sheet(isPresented: $showingExportSheet) {
                if let data = exportData {
                    ShareSheet(items: [data])
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
                    
                    Text("VitalView")
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
                    
                    Text("VitalView is a comprehensive health monitoring app that helps you track and understand your vital signs and blood test results. The app integrates with Apple HealthKit to provide real-time health metrics and offers detailed analysis of your blood work.")
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
