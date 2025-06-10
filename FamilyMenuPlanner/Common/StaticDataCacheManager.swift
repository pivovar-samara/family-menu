//
//  StaticDataCacheManager.swift
//  FamilyMenuPlanner
//
//  Created by Performance Optimization on 28.01.25.
//

import CoreData
import Combine
import os

/// Cache manager for static reference data
/// Prevents multiple loads of unchanging data from CoreData
final class StaticDataCacheManager: ObservableObject {
    
    static let shared = StaticDataCacheManager()
    
    // MARK: - Cached Data
    
    @Published private(set) var units: [Unit] = []
    @Published private(set) var mealTypes: [MealType] = []
    @Published private(set) var dishCategories: [DishCategory] = []
    
    // MARK: - Cache State
    
    private var isUnitsLoaded = false
    private var isMealTypesLoaded = false
    private var isDishCategoriesLoaded = false
    
    // Use strong reference to prevent context deallocation during operations
    private var context: NSManagedObjectContext?
    // Use serial queue for thread safety
    private let cacheQueue = DispatchQueue(label: "com.familymenuplanner.cache", qos: .utility)
    
    // Logging
    private static let logger = Logger(subsystem: "com.familymenuplanner", category: "StaticDataCache")
    
    // Testing support
    private let isTestInstance: Bool
    
    private init(isTestInstance: Bool = false) {
        self.isTestInstance = isTestInstance
    }
    
    /// Create a test instance that doesn't use singleton pattern
    static func createTestInstance() -> StaticDataCacheManager {
        return StaticDataCacheManager(isTestInstance: true)
    }
    
    // MARK: - Public Interface
    
    /// Initialize cache with CoreData context
    func initialize(with context: NSManagedObjectContext) {
        // Aggressive UI test detection for real devices
        let isUITest = ProcessInfo.processInfo.environment["UI_TESTS"] != nil ||
                      ProcessInfo.processInfo.arguments.contains("-UITests") ||
                      ProcessInfo.processInfo.arguments.contains("-XCTest") ||
                      ProcessInfo.processInfo.arguments.contains("-InMemoryStore") ||
                      ProcessInfo.processInfo.environment["TESTING_ENVIRONMENT"] != nil ||
                      ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                      ProcessInfo.processInfo.environment["DISABLE_CLOUDKIT"] != nil
        
        // For UI tests, especially on real devices, skip all heavy initialization
        if isUITest {
            Self.logger.info("UI test detected - skipping static data preloading for faster launch")
            self.context = context
            // Don't preload anything - use lazy loading only
            return
        }
        
        // Store strong reference to context
        self.context = context
        
        // Only preload for production app launches
        cacheQueue.sync {
            // Preload all static data to ensure immediate availability
            self.preloadAllData()
        }
    }
    
    /// Get units (with lazy loading)
    func getUnits() -> [Unit] {
        return cacheQueue.sync {
            if !isUnitsLoaded {
                loadUnits()
            }
            return units
        }
    }
    
    /// Get meal types (with lazy loading)
    func getMealTypes() -> [MealType] {
        return cacheQueue.sync {
            if !isMealTypesLoaded {
                loadMealTypes()
            }
            return mealTypes
        }
    }
    
    /// Get dish categories (with lazy loading)
    func getDishCategories() -> [DishCategory] {
        return cacheQueue.sync {
            if !isDishCategoriesLoaded {
                loadDishCategories()
            }
            return dishCategories
        }
    }
    
    /// Force reload all data (useful for development/testing)
    func invalidateCache(completion: (() -> Void)? = nil) {
        cacheQueue.async {
            self.clearAllCache()
            self.preloadAllData()
            
            // Call completion on main thread if provided
            if let completion = completion {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }
    
    /// Invalidate cache synchronously for testing purposes
    func invalidateCacheSync() {
        cacheQueue.sync {
            clearAllCache()
            preloadAllData()
        }
    }
    
    /// Cleanup method for proper resource deallocation
    func cleanup() {
        let cleanupGroup = DispatchGroup()
        
        cleanupGroup.enter()
        cacheQueue.async {
            // Clear all cached data
            self.clearAllCache()
            
            // Release context reference
            self.context = nil
            
            cleanupGroup.leave()
        }
        
        // Wait for cleanup to complete, but with a timeout to prevent hanging
        _ = cleanupGroup.wait(timeout: .now() + 1.0)
    }
    
    /// Synchronous cleanup for testing
    func cleanupSync() {
        cacheQueue.sync {
            clearAllCache()
            context = nil
        }
    }
    
    // MARK: - Private Methods
    
    /// Preload all static data synchronously
    private func preloadAllData() {
        guard context != nil else { return }
        
        if !isUnitsLoaded {
            loadUnits()
        }
        if !isMealTypesLoaded {
            loadMealTypes()
        }
        if !isDishCategoriesLoaded {
            loadDishCategories()
        }
    }
    
    private func clearAllCache() {
        // Update local state immediately for synchronous access
        isUnitsLoaded = false
        isMealTypesLoaded = false
        isDishCategoriesLoaded = false
        
        units = []
        mealTypes = []
        dishCategories = []
        
        // Update @Published properties on main thread for optimal UI performance
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.units = []
                self?.mealTypes = []
                self?.dishCategories = []
            }
        }
    }
    
    private func loadUnits() {
        guard let context = context else {
            Self.logger.error("Context is nil when loading units")
            return
        }
        
        let fetchRequest: NSFetchRequest<Unit> = Unit.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Unit.sortOrder, ascending: true)]
        
        // Static data is usually small, use smaller batch size
        CoreDataFetchHelper.configureForSmallList(fetchRequest)
        
        // Perform the fetch on the context's queue to ensure thread safety
        context.performAndWait {
            do {
                let freshUnits = try context.fetch(fetchRequest)
                
                // Update local state immediately for synchronous access
                self.units = freshUnits
                self.isUnitsLoaded = true
                
                // Update @Published properties on main thread for optimal UI performance
                if !Thread.isMainThread {
                    DispatchQueue.main.async { [weak self] in
                        self?.units = freshUnits
                    }
                }
                
                if !isTestInstance {
                    Self.logger.info("Units cached: \(freshUnits.count) items")
                }
            } catch {
                Self.logger.error("Error loading units for cache: \(error.localizedDescription)")
                // Handle error immediately for synchronous access
                self.units = []
                self.isUnitsLoaded = false
                
                // Update @Published properties on main thread as well
                if !Thread.isMainThread {
                    DispatchQueue.main.async { [weak self] in
                        self?.units = []
                    }
                }
            }
        }
    }
    
    private func loadMealTypes() {
        guard let context = context else {
            Self.logger.error("Context is nil when loading meal types")
            return
        }
        
        let fetchRequest: NSFetchRequest<MealType> = MealType.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MealType.sortOrder, ascending: true)]
        
        CoreDataFetchHelper.configureForSmallList(fetchRequest)
        
        // Perform the fetch on the context's queue to ensure thread safety
        context.performAndWait {
            do {
                let freshMealTypes = try context.fetch(fetchRequest)
                
                // Update local state immediately for synchronous access
                self.mealTypes = freshMealTypes
                self.isMealTypesLoaded = true
                
                // Update @Published properties on main thread for optimal UI performance
                if !Thread.isMainThread {
                    DispatchQueue.main.async { [weak self] in
                        self?.mealTypes = freshMealTypes
                    }
                }
                
                if !isTestInstance {
                    Self.logger.info("MealTypes cached: \(freshMealTypes.count) items")
                }
            } catch {
                Self.logger.error("Error loading meal types for cache: \(error.localizedDescription)")
                // Handle error immediately for synchronous access
                self.mealTypes = []
                self.isMealTypesLoaded = false
                
                // Update @Published properties on main thread for optimal UI performance
                if !Thread.isMainThread {
                    DispatchQueue.main.async { [weak self] in
                        self?.mealTypes = []
                    }
                }
            }
        }
    }
    
    private func loadDishCategories() {
        guard let context = context else {
            Self.logger.error("Context is nil when loading dish categories")
            return
        }
        
        let fetchRequest: NSFetchRequest<DishCategory> = DishCategory.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \DishCategory.sortOrder, ascending: true)]
        
        CoreDataFetchHelper.configureForSmallList(fetchRequest)
        
        // Perform the fetch on the context's queue to ensure thread safety
        context.performAndWait {
            do {
                let freshCategories = try context.fetch(fetchRequest)
                
                // Update local state immediately for synchronous access
                self.dishCategories = freshCategories
                self.isDishCategoriesLoaded = true
                
                // Update @Published properties on main thread for optimal UI performance
                if !Thread.isMainThread {
                    DispatchQueue.main.async { [weak self] in
                        self?.dishCategories = freshCategories
                    }
                }
                
                if !isTestInstance {
                    Self.logger.info("DishCategories cached: \(freshCategories.count) items")
                }
            } catch {
                Self.logger.error("Error loading dish categories for cache: \(error.localizedDescription)")
                // Handle error immediately for synchronous access
                self.dishCategories = []
                self.isDishCategoriesLoaded = false
                
                // Update @Published properties on main thread for optimal UI performance
                if !Thread.isMainThread {
                    DispatchQueue.main.async { [weak self] in
                        self?.dishCategories = []
                    }
                }
            }
        }
    }
    
    deinit {
        // Clear context reference directly
        context = nil
        
        // Clear cached data directly
        units = []
        mealTypes = []
        dishCategories = []
        isUnitsLoaded = false
        isMealTypesLoaded = false
        isDishCategoriesLoaded = false
    }
} 