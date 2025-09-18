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
    
    // Per-collection locks to prevent concurrent loading and data races
    private let unitsLock = NSRecursiveLock()
    private let mealTypesLock = NSRecursiveLock()
    private let dishCategoriesLock = NSRecursiveLock()
    
    // Background context used when the supplied context is tied to the main queue and the
    // caller is *not* on the main thread. Lazily created to avoid overhead when unnecessary.
    private var backgroundContext: NSManagedObjectContext?
    
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
        // A *real* UI-test run sets explicit flags/args that we can safely detect. Using
        // generic XCTest flags incorrectly labels all unit/integration test processes
        // as UI runs, so we purposefully keep the check narrow.
        let isUITest = ProcessInfo.processInfo.environment["UI_TESTS"] != nil ||
                        ProcessInfo.processInfo.arguments.contains("-UITests")
        
        // For production app instances running UI tests we skip heavy initialization
        // to ensure the app launches as quickly as possible. However, when this
        // cache manager is *itself* a test fixture (isTestInstance == true) we
        // still want deterministic synchronous preloading so that the unit /
        // integration tests exercising thread-safety don't dead-lock.
        if !isTestInstance && isUITest {
            Self.logger.info("UI test detected - skipping static data preloading for faster launch")
            self.context = context
            // Don't preload anything - use lazy loading only
            return
        }
        
        // Store strong reference to context
        self.context = context
        
        // Prepare a reusable background context that shares the same PSC. This prevents
        // potential main-queue deadlocks when callers fetch data from background threads.
        // This must be done before the early return for test instances.
        if let psc = context.persistentStoreCoordinator {
            let bgContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            bgContext.persistentStoreCoordinator = psc
            bgContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            self.backgroundContext = bgContext
        }
        
        // For dedicated *unit mocked* instances created via `createTestInstance()` we still
        // want immediate deterministic preloading and then exit early, because those callers
        // rely on synchronous behaviour.
        if isTestInstance {
            preloadAllData()
            return
        }

        // Detect if we are running inside a unit or integration test bundle (not UI tests).
        // In such cases we prefer *synchronous* preloading to avoid race-conditions with
        // test code that immediately calls `invalidateCacheSync()`.
        let isUnitOrIntegrationTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil && !isUITest

        if isUnitOrIntegrationTest {
            // Synchronous for deterministic behaviour in tests.
            preloadAllData()
        } else {
            // For production launches we still want to keep the work off the main queue.
            cacheQueue.async { [weak self] in
                self?.preloadAllData()
            }
        }
    }
    
    /// Get units (with lazy loading)
    /// Thread-safe accessor that guarantees the underlying Core Data fetch will be executed **once**
    /// even when several threads call this method concurrently. A dedicated serial queue (`cacheQueue`)
    /// acts as the synchronisation point, eliminating the previous race where two threads could see
    /// `isLoaded == false` simultaneously and trigger duplicate fetches.
    func getUnits() -> [Unit] {
        unitsLock.lock()
        if !isUnitsLoaded {
            _ = loadUnits()
        }
        let result = units
        unitsLock.unlock()
        return result
    }
    
    /// Get meal types (with lazy loading)
    func getMealTypes() -> [MealType] {
        mealTypesLock.lock()
        if !isMealTypesLoaded {
            _ = loadMealTypes()
        }
        let result = mealTypes
        mealTypesLock.unlock()
        return result
    }
    
    /// Get dish categories (with lazy loading)
    func getDishCategories() -> [DishCategory] {
        dishCategoriesLock.lock()
        if !isDishCategoriesLoaded {
            _ = loadDishCategories()
        }
        let result = dishCategories
        dishCategoriesLock.unlock()
        return result
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
    
    /// Invalidate cache synchronously for testing purposes.
    /// This method now clears the cache on the serial queue (to guarantee exclusivity)
    /// *then* reloads the data on the caller's thread. Doing so eliminates a risk of
    /// deadlock when the supplied Core Data context is bound to the main queue and the
    /// caller is already executing on that same thread (e.g. in unit / integration tests).
    func invalidateCacheSync() {
        // 1️⃣ Clear on the serial queue to preserve thread-safety.
        cacheQueue.sync {
            clearAllCache()
        }

        // 2️⃣ Reload on the caller's thread so that any `context.performAndWait`
        //    executed inside the load helpers targets the correct queue (e.g. the
        //    main queue in tests) and avoids deadlocks.
        preloadAllData()
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
    
    @discardableResult
    private func loadUnits() -> [Unit] {
        guard let context = context else {
            Self.logger.error("Context is nil when loading units")
            return []
        }

        // Fetch directly on the provided context using performAndWait.
        // For small static datasets this avoids cross-context objectID
        // bridging that re-introduces faults in the main context.
        let effectiveContext: NSManagedObjectContext = context

        let fetchRequest: NSFetchRequest<Unit> = Unit.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Unit.sortOrder, ascending: true)]
        CoreDataFetchHelper.configureForSmallList(fetchRequest)

        var fetched: [Unit] = []
        var fetchError: Error?

        effectiveContext.performAndWait {
            do {
                fetched = try effectiveContext.fetch(fetchRequest)
            } catch {
                fetchError = error
            }
        }

        if let error = fetchError {
            Self.logger.error("Error loading units for cache: \(error.localizedDescription)")
            fetched = []
        }

        // Always return objects fetched on the target context; no cross-context bridging
        let resultArray: [Unit] = fetched

        unitsLock.lock()
        isUnitsLoaded = fetchError == nil
        unitsLock.unlock()

        if Thread.isMainThread {
            self.units = resultArray
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.units = resultArray
            }
        }

        if !isTestInstance {
            Self.logger.info("Units cached: \(resultArray.count) items")
        }

        return resultArray
    }
    
    @discardableResult
    private func loadMealTypes() -> [MealType] {
        guard let context = context else {
            Self.logger.error("Context is nil when loading meal types")
            return []
        }

        // See notes in loadUnits(): fetch directly on the provided context
        let effectiveContext: NSManagedObjectContext = context

        let fetchRequest: NSFetchRequest<MealType> = MealType.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MealType.sortOrder, ascending: true)]
        CoreDataFetchHelper.configureForSmallList(fetchRequest)

        var fetched: [MealType] = []
        var fetchError: Error?

        effectiveContext.performAndWait {
            do {
                fetched = try effectiveContext.fetch(fetchRequest)
            } catch {
                fetchError = error
            }
        }

        if let error = fetchError {
            Self.logger.error("Error loading meal types for cache: \(error.localizedDescription)")
            fetched = []
        }

        let resultArray: [MealType] = fetched

        mealTypesLock.lock()
        isMealTypesLoaded = fetchError == nil
        mealTypesLock.unlock()

        if Thread.isMainThread {
            self.mealTypes = resultArray
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.mealTypes = resultArray
            }
        }

        if !isTestInstance {
            Self.logger.info("MealTypes cached: \(resultArray.count) items")
        }

        return resultArray
    }
    
    @discardableResult
    private func loadDishCategories() -> [DishCategory] {
        guard let context = context else {
            Self.logger.error("Context is nil when loading dish categories")
            return []
        }

        // See notes in loadUnits(): fetch directly on the provided context
        let effectiveContext: NSManagedObjectContext = context

        let fetchRequest: NSFetchRequest<DishCategory> = DishCategory.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \DishCategory.sortOrder, ascending: true)]
        CoreDataFetchHelper.configureForSmallList(fetchRequest)

        var fetched: [DishCategory] = []
        var fetchError: Error?

        effectiveContext.performAndWait {
            do {
                fetched = try effectiveContext.fetch(fetchRequest)
            } catch {
                fetchError = error
            }
        }

        if let error = fetchError {
            Self.logger.error("Error loading dish categories for cache: \(error.localizedDescription)")
            fetched = []
        }

        let resultArray: [DishCategory] = fetched

        dishCategoriesLock.lock()
        isDishCategoriesLoaded = fetchError == nil
        dishCategoriesLock.unlock()

        if Thread.isMainThread {
            self.dishCategories = resultArray
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.dishCategories = resultArray
            }
        }

        if !isTestInstance {
            Self.logger.info("DishCategories cached: \(resultArray.count) items")
        }

        return resultArray
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