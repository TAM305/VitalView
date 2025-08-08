import SwiftUI
import CoreData
import HealthKit

/// The main entry point for the VitalVu health monitoring application.
/// This app provides comprehensive health data visualization and blood test management.
///
/// ## Key Features:
/// - **HealthKit Integration**: Seamlessly connects with Apple Health to read vital signs
/// - **Blood Test Management**: Track and analyze blood test results over time
/// - **Biometric Security**: Face ID/Touch ID protection for sensitive health data
/// - **Data Export/Import**: Backup and restore your health data
/// - **Privacy First**: All data stays on your device, never shared
///
/// ## Technical Architecture:
/// - **SwiftUI**: Modern declarative UI framework
/// - **Core Data**: Local data persistence with encryption
/// - **HealthKit**: Secure health data access
/// - **LocalAuthentication**: Biometric security
/// - **File Protection**: Complete data encryption at rest
///
/// ## Data Flow:
/// 1. **HealthKit** → Reads vital signs (heart rate, blood pressure, etc.)
/// 2. **User Input** → Manual blood test entry with validation
/// 3. **Core Data** → Encrypted local storage
/// 4. **SwiftUI** → Real-time UI updates
/// 5. **Export/Import** → JSON data backup/restore
///
/// ## Security Features:
/// - **File Protection**: Complete encryption for Core Data
/// - **Biometric Auth**: Face ID/Touch ID for data access
/// - **No Network**: All data stays local
/// - **Privacy Policy**: Clear data usage guidelines
///
/// ## App Store Compliance:
/// - **HealthKit**: Proper usage descriptions
/// - **Privacy**: Comprehensive privacy policy
/// - **Encryption**: Standard Apple encryption declaration
/// - **Accessibility**: VoiceOver and Dynamic Type support
@main
struct VitalVuApp: App {
    @StateObject private var persistenceController = PersistenceController.shared
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var showingSplash = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environmentObject(healthKitManager)
                
                if showingSplash {
                    AnimatedSplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                // Show splash for 2.5 seconds then fade out
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showingSplash = false
                    }
                }
            }
        }
    }
}

// MARK: - File Organization
// This file serves as the main entry point for the app
// All types are defined in their respective files:
// - Models/BloodWorkModels.swift: Contains BloodTest, TestResult, and BloodTestViewModel
// - Views/ContentView.swift: Contains the main view and navigation
// - PersistenceController.swift: Contains Core Data setup
// - Views/: Contains all UI components and screens 
