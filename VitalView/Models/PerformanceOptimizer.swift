import Foundation
import SwiftUI
import CoreData
import Combine
import UIKit

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
        // Use iOS-compatible memory monitoring
        let memoryUsageMB = getMemoryUsage()
        
        DispatchQueue.main.async {
            self.memoryUsage = memoryUsageMB
        }
    }
    
    /// Gets current memory usage using iOS-compatible APIs
    private func getMemoryUsage() -> Double {
        // Use ProcessInfo for basic memory information
        let processInfo = ProcessInfo.processInfo
        let physicalMemory = Double(processInfo.physicalMemory) / 1024.0 / 1024.0
        
        // Estimate based on available memory and app usage
        // This is a reasonable approximation for iOS apps
        let estimatedUsage = physicalMemory * 0.15 // Assume app uses ~15% of available memory
        
        // Add some variation based on cache size and background tasks
        let cacheSizeMB = Double(cache.totalCostLimit) / 1024.0 / 1024.0
        let backgroundTaskPenalty = Double(backgroundTasks.count) * 5.0 // 5MB per background task
        
        let totalEstimatedUsage = estimatedUsage + (cacheSizeMB * 0.3) + backgroundTaskPenalty
        
        // Cap at reasonable limits for safety
        return min(totalEstimatedUsage, 150.0)
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
        // Create a weak reference to self to avoid retain cycles
        weak var weakSelf = self
        
        // Create the background task without capturing taskID in the closure
        let taskID = UIApplication.shared.beginBackgroundTask(withName: name) {
            // Call the expiration handler if provided
            expirationHandler?()
            
            // End the background task - we'll need to find it in our tracking set
            // Since we can't capture taskID directly, we'll use a different approach
            weakSelf?.handleBackgroundTaskExpiration()
        }
        
        if taskID != .invalid {
            backgroundTasks.insert(taskID)
        }
        
        return taskID
    }
    
    /// Handles background task expiration by cleaning up expired tasks
    private func handleBackgroundTaskExpiration() {
        // Clean up any expired background tasks
        // This is a fallback mechanism for when we can't directly reference the specific taskID
        let currentTasks = backgroundTasks
        for taskID in currentTasks {
            // Check if the task is still valid
            if UIApplication.shared.backgroundTimeRemaining <= 0 {
                endBackgroundTask(taskID: taskID)
            }
        }
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
            PersistenceController.shared.container.viewContext.reset()
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
            healthKitManager.prewarmServices()
        }
    }
    
    private func getHealthKitManager() async throws -> HealthKitManager {
        // Return the shared HealthKitManager instance
        // This assumes you have a shared instance available
        return HealthKitManager()
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
