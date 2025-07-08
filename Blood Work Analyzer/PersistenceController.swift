import CoreData
import LocalAuthentication

public struct PersistenceController {
    public static let shared = PersistenceController()
    private static var isAuthenticated = false
    
    public let container: NSPersistentContainer
    
    public init() {
        container = NSPersistentContainer(name: "BloodWorkData")
        
        // Configure for local storage with file protection
        let description = NSPersistentStoreDescription()
        description.type = NSSQLiteStoreType
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        
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
    }
    
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
            }
        }
    }
    
    public func deleteAllData() {
        guard Self.isAuthenticated else {
            print("Authentication required to delete data")
            return
        }
        
        let context = container.viewContext
        
        // Delete all test entities
        let testFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "BloodTestEntity")
        let testDeleteRequest = NSBatchDeleteRequest(fetchRequest: testFetchRequest)
        
        do {
            try context.execute(testDeleteRequest)
            try context.save()
        } catch {
            print("Error deleting all data: \(error)")
        }
    }
} 
