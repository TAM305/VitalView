import SwiftUI
import CoreData
import HealthKit

/// The main entry point for the VitalView blood work analyzer application.
///
/// This app provides comprehensive health monitoring capabilities by integrating with HealthKit
/// to track and analyze various health metrics including heart rate, blood pressure, oxygen saturation,
/// and other vital signs. It allows users to input blood test results, track trends over time,
/// and receive insights about their health data.
///
/// ## Key Features
/// - **HealthKit Integration**: Seamlessly connects with Apple Health to read vital signs
/// - **Blood Test Tracking**: Manual entry and management of blood test results
/// - **Trend Analysis**: Visual representation of health metrics over time
/// - **Privacy-First**: Local data storage with optional HealthKit synchronization
/// - **Comprehensive Metrics**: Supports multiple health indicators and blood markers
///
/// ## HealthKit Permissions
/// The app requests access to the following health data types:
/// - Heart rate and heart rate variability
/// - Blood pressure (systolic and diastolic)
/// - Oxygen saturation
/// - Body temperature
/// - Respiratory rate
/// - Electrocardiogram data
///
/// ## Data Management
/// - Uses Core Data for local persistence
/// - Implements proper data validation and error handling
/// - Supports data export and backup functionality
///
/// - Author: VitalView Development Team
/// - Version: 1.0
/// - Copyright: © 2025 VitalView. All rights reserved.
@main
struct BloodWorkAnalyzer: App {
    /// The persistence controller that manages Core Data operations.
    ///
    /// This controller provides a shared instance for managing the app's data model,
    /// including blood test results, user preferences, and health metrics.
    private let persistenceController: PersistenceController = {
        let controller = PersistenceController.shared
        return controller
    }()
    
    /// The HealthKit store for accessing health data.
    ///
    /// This store is used to request authorization and read health data from Apple Health.
    /// It's initialized when the app starts and handles all HealthKit interactions.
    private let healthStore = HKHealthStore()
    
    /// Initializes the app and requests necessary HealthKit permissions.
    ///
    /// This initializer sets up the app's core functionality by:
    /// 1. Checking if HealthKit is available on the device
    /// 2. Requesting HealthKit authorization for required data types
    /// 3. Setting up the persistence controller
    /// 4. Configuring the app's environment
    ///
    /// The authorization request includes access to:
    /// - Heart rate and heart rate variability
    /// - Blood pressure measurements
    /// - Oxygen saturation levels
    /// - Body temperature readings
    /// - Respiratory rate data
    /// - Electrocardiogram recordings
    init() {
        // Check if HealthKit is available on this device
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
        // Request HealthKit authorization when the app launches
        var typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .bodyTemperature)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        ]
        
        // Add basal body temperature if available
        if let basalTemperatureType = HKObjectType.quantityType(forIdentifier: .basalBodyTemperature) {
            typesToRead.insert(basalTemperatureType)
        }
        
        // Add ECG type if available (iOS 14+)
        if #available(iOS 14.0, *) {
            typesToRead.insert(HKObjectType.electrocardiogramType())
        }
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("HealthKit authorization granted successfully")
                } else {
                    print("HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
    
    /// The main scene configuration for the app.
    ///
    /// This scene sets up the primary window group and configures the app's
    /// environment with the necessary Core Data context and other dependencies.
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
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
