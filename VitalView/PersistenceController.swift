import CoreData
import LocalAuthentication
import SwiftUI

public class PersistenceController: ObservableObject {
    public static let shared = PersistenceController()
    private static var isAuthenticated = false
    
    public let container: NSPersistentContainer
    
    // MARK: - Performance Optimization
    private var backgroundContext: NSManagedObjectContext?
    private let saveQueue = DispatchQueue(label: "com.vitalview.persistence.save", qos: .userInitiated)
    
    public init() {
        container = NSPersistentContainer(name: "BloodWorkData")
        
        // Configure for local storage with file protection
        let description = NSPersistentStoreDescription()
        description.type = NSSQLiteStoreType
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        
        // Performance optimizations
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Enable file protection with better error handling
        if let storeURL = description.url {
            do {
                try FileManager.default.setAttributes(
                    [.protectionKey: FileProtectionType.complete],
                    ofItemAtPath: storeURL.path
                )
            } catch {
                print("Warning: Could not set file protection attributes: \(error.localizedDescription)")
                // Continue without file protection rather than failing
            }
        }
        
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data error: \(error.localizedDescription)")
                // Try to recover by deleting the store and recreating it
                if let storeURL = description.url {
                    do {
                        try FileManager.default.removeItem(at: storeURL)
                        print("Removed corrupted store, will recreate on next launch")
                    } catch {
                        print("Could not remove corrupted store: \(error.localizedDescription)")
                    }
                }
                // Don't use fatalError in production - just log the error
                print("Core Data store could not be loaded. App may not function properly.")
            } else {
                print("Core Data store loaded successfully")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Performance optimizations
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.shouldDeleteInaccessibleFaults = true
        
        // Setup background context for heavy operations
        setupBackgroundContext()
    }
    
    // MARK: - Background Context Setup
    
    private func setupBackgroundContext() {
        backgroundContext = container.newBackgroundContext()
        backgroundContext?.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        backgroundContext?.automaticallyMergesChangesFromParent = true
    }
    
    // MARK: - Optimized Save Operations
    
    public func save() {
        guard Self.isAuthenticated else {
            print("Authentication required to save data")
            return
        }
        
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context: \(error)")
                // Try to save on background context if main context fails
                saveOnBackgroundContext()
            }
        }
    }
    
    /// Saves data on background context for better performance
    private func saveOnBackgroundContext() {
        guard let backgroundContext = backgroundContext else { return }
        
        saveQueue.async {
            if backgroundContext.hasChanges {
                do {
                    try backgroundContext.save()
                    print("Successfully saved on background context")
                } catch {
                    print("Error saving on background context: \(error)")
                }
            }
        }
    }
    
    /// Performs heavy operations on background context
    public func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        guard let backgroundContext = backgroundContext else {
            throw NSError(domain: "PersistenceController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Background context not available"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    let result = try block(backgroundContext)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Authentication
    
    public func authenticate(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, 
                                 localizedReason: "Access your blood test records") { success, _ in
                DispatchQueue.main.async {
                    Self.isAuthenticated = success
                    completion(success)
                }
            }
        } else {
            completion(false)
        }
    }
    
    // MARK: - Data Management
    
    public func deleteAllData() {
        guard Self.isAuthenticated else {
            print("Authentication required to delete data")
            return
        }
        
        Task {
            do {
                try await performBackgroundTask { context in
                    // Delete all test entities
                    let testFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "BloodTestEntity")
                    let testDeleteRequest = NSBatchDeleteRequest(fetchRequest: testFetchRequest)
                    
                    try context.execute(testDeleteRequest)
                    try context.save()
                }
                print("Successfully deleted all data")
            } catch {
                print("Error deleting all data: \(error)")
            }
        }
    }
    
    // MARK: - Memory Management
    
    /// Cleans up memory when app goes to background
    public func cleanupMemory() {
        container.viewContext.refreshAllObjects()
        backgroundContext?.refreshAllObjects()
    }
    
    /// Resets the view context to free memory
    public func resetViewContext() {
        container.viewContext.reset()
    }
} 
