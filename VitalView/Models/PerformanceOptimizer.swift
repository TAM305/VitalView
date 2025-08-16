import Foundation
import SwiftUI
import CoreData
import Combine

/// Performance optimization utility for the VitalVu app
///
/// This class provides centralized performance management including:
/// - Memory optimization
/// - Background task coordination
/// - Cache management
/// - Performance monitoring
class PerformanceOptimizer: ObservableObject {
    static let shared = PerformanceOptimizer()
    
    // MARK: - Properties
    @Published var memoryUsage: Double = 0.0
    @Published var isOptimizing = false
    
    private var backgroundTasks: Set<UIBackgroundTaskIdentifier> = []
    private var cache: NSCache<NSString, AnyObject> = NSCache()
    private var performanceTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        setupPerformanceMonitoring()
        setupCacheConfiguration()
    }
    
    // MARK: - Performance Monitoring
    
    private func setupPerformanceMonitoring() {
        // Monitor memory usage every 30 seconds
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.updateMemoryUsage()
        }
        
        // Monitor app lifecycle for optimization opportunities
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.optimizeForBackground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.optimizeForForeground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
    }
    
    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self(),
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryUsageMB = Double(info.resident_size) / 1024.0 / 1024.0
            DispatchQueue.main.async {
                self.memoryUsage = memoryUsageMB
            }
        }
    }
    
    // MARK: - Cache Management
    
    private func setupCacheConfiguration() {
        cache.countLimit = 100 // Maximum number of cached objects
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit
        
        // Clear cache when memory is low
        cache.evictsObjectsWithDiscardedContent = true
    }
    
    /// Caches an object with a key
    func cacheObject<T: AnyObject>(_ object: T, forKey key: String) {
        cache.setObject(object, forKey: key as NSString)
    }
    
    /// Retrieves a cached object
    func getCachedObject<T: AnyObject>(forKey key: String) -> T? {
        return cache.object(forKey: key as NSString) as? T
    }
    
    /// Clears all cached objects
    func clearCache() {
        cache.removeAllObjects()
    }
    
    // MARK: - Background Task Management
    
    func beginBackgroundTask(name: String, expirationHandler: (() -> Void)? = nil) -> UIBackgroundTaskIdentifier {
        let taskID = UIApplication.shared.beginBackgroundTask(withName: name) {
            expirationHandler?()
            self.endBackgroundTask(taskID: taskID)
        }
        
        if taskID != .invalid {
            backgroundTasks.insert(taskID)
        }
        
        return taskID
    }
    
    func endBackgroundTask(taskID: UIBackgroundTaskIdentifier) {
        if backgroundTasks.contains(taskID) {
            UIApplication.shared.endBackgroundTask(taskID)
            backgroundTasks.remove(taskID)
        }
    }
    
    func endAllBackgroundTasks() {
        backgroundTasks.forEach { taskID in
            UIApplication.shared.endBackgroundTask(taskID)
        }
        backgroundTasks.removeAll()
    }
    
    // MARK: - App Lifecycle Optimization
    
    private func optimizeForBackground() {
        isOptimizing = true
        
        // Clear non-essential caches
        clearCache()
        
        // Save Core Data context
        PersistenceController.shared.save()
        
        // End background tasks
        endAllBackgroundTasks()
        
        isOptimizing = false
    }
    
    private func optimizeForForeground() {
        isOptimizing = true
        
        // Refresh performance monitoring
        updateMemoryUsage()
        
        // Pre-warm essential services
        Task {
            await prewarmServices()
        }
        
        isOptimizing = false
    }
    
    private func handleMemoryWarning() {
        // Clear all caches
        clearCache()
        
        // Reset Core Data context if needed
        if memoryUsage > 100.0 { // If using more than 100MB
            PersistenceController.shared.resetViewContext()
        }
    }
    
    // MARK: - Service Pre-warming
    
    private func prewarmServices() async {
        // Pre-warm Core Data
        await MainActor.run {
            _ = PersistenceController.shared.container.viewContext
        }
        
        // Pre-warm HealthKit if available
        if let healthKitManager = try? await getHealthKitManager() {
            await healthKitManager.prewarmHealthKit()
        }
    }
    
    private func getHealthKitManager() async throws -> HealthKitManager {
        // This would need to be implemented based on your app's architecture
        // For now, returning a placeholder
        throw NSError(domain: "PerformanceOptimizer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])
    }
    
    // MARK: - Performance Metrics
    
    /// Returns current performance metrics
    func getPerformanceMetrics() -> PerformanceMetrics {
        return PerformanceMetrics(
            memoryUsageMB: memoryUsage,
            cacheSize: cache.totalCostLimit,
            activeBackgroundTasks: backgroundTasks.count,
            isOptimizing: isOptimizing
        )
    }
    
    // MARK: - Cleanup
    
    deinit {
        performanceTimer?.invalidate()
        endAllBackgroundTasks()
        cancellables.removeAll()
    }
}

// MARK: - Performance Metrics

struct PerformanceMetrics {
    let memoryUsageMB: Double
    let cacheSize: Int
    let activeBackgroundTasks: Int
    let isOptimizing: Bool
    
    var memoryUsageFormatted: String {
        return String(format: "%.1f MB", memoryUsageMB)
    }
    
    var cacheSizeFormatted: String {
        let sizeMB = Double(cacheSize) / 1024.0 / 1024.0
        return String(format: "%.1f MB", sizeMB)
    }
}

// MARK: - View Modifier for Performance

struct PerformanceOptimized: ViewModifier {
    @StateObject private var optimizer = PerformanceOptimizer.shared
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                // Trigger optimization when view appears
                if optimizer.memoryUsage > 80.0 {
                    optimizer.clearCache()
                }
            }
            .onDisappear {
                // Clean up when view disappears
                if optimizer.memoryUsage > 100.0 {
                    optimizer.clearCache()
                }
            }
    }
}

extension View {
    /// Applies performance optimization to the view
    func performanceOptimized() -> some View {
        modifier(PerformanceOptimized())
    }
}
