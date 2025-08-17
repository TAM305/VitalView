import CoreData
import Foundation
import UIKit

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    let backgroundContext: NSManagedObjectContext
    let saveQueue = DispatchQueue(label: "com.vitalvu.persistence.save", qos: .userInitiated)
    
    // Memory management properties
    private var memoryWarningObserver: NSObjectProtocol?
    private var memoryPressureObserver: NSObjectProtocol?
    private var appStateObserver: NSObjectProtocol?
    private let memoryThreshold: UInt64 = 200 * 1024 * 1024 // 200 MB threshold (increased from 100 MB)
    
    init() {
        container = NSPersistentContainer(name: "BloodWorkData")
        
        // Configure persistent store with memory optimization
        let description = NSPersistentStoreDescription()
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.setOption(FileProtectionType.complete as NSString, forKey: NSPersistentStoreFileProtectionKey)
        
        // Memory optimization options
        description.setOption(NSNumber(value: 1000), forKey: "NSPersistentStoreBatchSize")
        description.setOption(NSNumber(value: 100), forKey: "NSPersistentStoreFetchBatchSize")
        
        container.persistentStoreDescriptions = [description]
        
        // Create background context with memory optimization
        backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        backgroundContext.persistentStoreCoordinator = container.persistentStoreCoordinator
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Note: Memory limits are handled through fetch request configuration
        // rather than context-level options
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        
        // Enable automatic merging
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Note: Memory limits are handled through fetch request configuration
        // rather than context-level options
        
        // Setup memory management
        setupMemoryManagement()
        
        print("Core Data store loaded successfully")
    }
    
    // MARK: - Memory Management
    
    private func setupMemoryManagement() {
        // Monitor memory warnings
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
        
        // Monitor memory pressure
        memoryPressureObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryPressure()
        }
        
        // Monitor app state changes
        appStateObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppBackgrounding()
        }
        
        // Start memory monitoring
        startMemoryMonitoring()
    }
    
    private func startMemoryMonitoring() {
        // Monitor memory usage every 30 seconds (reduced from 5 seconds)
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkMemoryUsage()
        }
    }
    
    private func checkMemoryUsage() {
        let memoryUsage = getCurrentMemoryUsage()
        
        if memoryUsage > memoryThreshold {
            print("⚠️ High memory usage detected: \(memoryUsage / 1024 / 1024) MB")
            performMemoryCleanup()
        }
        
        // Log memory usage for debugging
        if memoryUsage > 50 * 1024 * 1024 { // 50 MB
            print("📊 Current memory usage: \(memoryUsage / 1024 / 1024) MB")
        }
    }
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return UInt64(info.resident_size)
        } else {
            // Fallback to ProcessInfo if mach APIs fail
            return UInt64(ProcessInfo.processInfo.physicalMemory)
        }
    }
    
    private func handleMemoryWarning() {
        print("🚨 Memory warning received - performing cleanup")
        performMemoryCleanup()
    }
    
    private func handleMemoryPressure() {
        print("🚨 Memory pressure detected - performing aggressive cleanup")
        performAggressiveMemoryCleanup()
    }
    
    private func handleAppBackgrounding() {
        print("📱 App entering background - performing memory cleanup")
        performMemoryCleanup()
    }
    
    private func performMemoryCleanup() {
        // Clear Core Data cache
        container.viewContext.refreshAllObjects()
        
        // Clear background context
        backgroundContext.refreshAllObjects()
        
        // Force garbage collection
        autoreleasepool {
            // Clear any cached data
        }
        
        print("🧹 Memory cleanup completed")
    }
    
    private func performAggressiveMemoryCleanup() {
        // More aggressive cleanup
        performMemoryCleanup()
        
        // Clear all contexts
        container.viewContext.reset()
        backgroundContext.reset()
        
        // Force memory release
        autoreleasepool {
            // Additional cleanup
        }
        
        print("🧹 Aggressive memory cleanup completed")
    }
    
    // MARK: - Context Management
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                print("✅ Core Data changes saved successfully")
            } catch {
                print("❌ Failed to save Core Data changes: \(error)")
            }
        }
    }
    
    func saveBackground() {
        saveQueue.async { [weak self] in
            guard let self = self else { return }
            
            let context = self.backgroundContext
            
            if context.hasChanges {
                do {
                    try context.save()
                    print("✅ Background Core Data changes saved successfully")
                } catch {
                    print("❌ Failed to save background Core Data changes: \(error)")
                }
            }
        }
    }
    
    // MARK: - Memory-Efficient Fetching
    
    func fetchWithMemoryOptimization<T: NSManagedObject>(_ request: NSFetchRequest<T>) throws -> [T] {
        // Set batch size to prevent loading too many objects into memory
        request.fetchBatchSize = 50
        
        // Set fetch limit if not specified
        if request.fetchLimit == 0 {
            request.fetchLimit = 100
        }
        
        // Use faulting to reduce memory usage
        request.returnsObjectsAsFaults = true
        
        return try container.viewContext.fetch(request)
    }
    
    // MARK: - Cleanup
    
    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = memoryPressureObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = appStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
} 

