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
    
    private weak var context: NSManagedObjectContext?
    private var cancellables = Set<AnyCancellable>()
    private let cacheQueue = DispatchQueue(label: "com.familymenuplanner.cache", attributes: .concurrent)
    
    // Logging
    private static let logger = Logger(subsystem: "com.familymenuplanner", category: "StaticDataCache")
    
    // Testing support
    private var notificationsEnabled = true
    private let isTestInstance: Bool
    
    private init(isTestInstance: Bool = false) {
        self.isTestInstance = isTestInstance
        setupRemoteChangeNotifications()
    }
    
    /// Internal initializer for testing
    internal init(enableNotifications: Bool) {
        self.notificationsEnabled = enableNotifications
        self.isTestInstance = true
        if enableNotifications {
            setupRemoteChangeNotifications()
        }
    }
    
    /// Create a test instance that doesn't use singleton pattern
    static func createTestInstance() -> StaticDataCacheManager {
        return StaticDataCacheManager(enableNotifications: false)
    }
    
    // MARK: - Public Interface
    
    /// Initialize cache with CoreData context
    func initialize(with context: NSManagedObjectContext) {
        self.context = context
        
        cacheQueue.async(flags: .barrier) {
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
    
    /// Force reload all data
    func invalidateCache() {
        cacheQueue.async(flags: .barrier) {
            self.clearAllCache()
        }
    }
    
    /// Invalidate cache synchronously for testing purposes
    func invalidateCacheSync() {
        clearAllCache()
    }
    
    /// Disable notifications for testing
    func disableNotifications() {
        notificationsEnabled = false
        stopListeningForChanges()
    }
    
    /// Enable notifications for production
    func enableNotifications() {
        notificationsEnabled = true
        startListeningForChanges()
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
        // Use async only if not already on main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.units = []
                self.mealTypes = []
                self.dishCategories = []
            }
        }
    }
    
    /// Invalidate specific data type - internal for testing
    internal func invalidateUnits() {
        cacheQueue.async(flags: .barrier) {
            // Update local state immediately for synchronous access
            self.isUnitsLoaded = false
            self.units = []
            
            // Update @Published properties on main thread for optimal UI performance
            if !Thread.isMainThread {
                DispatchQueue.main.async {
                    self.units = []
                }
            }
        }
    }
    
    internal func invalidateMealTypes() {
        cacheQueue.async(flags: .barrier) {
            // Update local state immediately for synchronous access
            self.isMealTypesLoaded = false
            self.mealTypes = []
            
            // Update @Published properties on main thread for optimal UI performance
            if !Thread.isMainThread {
                DispatchQueue.main.async {
                    self.mealTypes = []
                }
            }
        }
    }
    
    internal func invalidateDishCategories() {
        cacheQueue.async(flags: .barrier) {
            // Update local state immediately for synchronous access
            self.isDishCategoriesLoaded = false
            self.dishCategories = []
            
            // Update @Published properties on main thread for optimal UI performance
            if !Thread.isMainThread {
                DispatchQueue.main.async {
                    self.dishCategories = []
                }
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
        
        do {
            let fetchedUnits = try context.fetch(fetchRequest)
            
            // Update local state immediately for synchronous access
            self.units = fetchedUnits
            self.isUnitsLoaded = true
            
            // Update @Published properties on main thread for optimal UI performance
            // Use async only if not already on main thread
            if Thread.isMainThread {
                // Already on main thread, no need to dispatch
            } else {
                DispatchQueue.main.async {
                    self.units = fetchedUnits
                }
            }
            
            if !isTestInstance {
                Self.logger.info("Units cached: \(fetchedUnits.count) items")
            } else {
                print("✅ Units cached: \(fetchedUnits.count) items")
            }
        } catch {
            Self.logger.error("Error loading units for cache: \(error.localizedDescription)")
            // Handle error immediately for synchronous access
            self.units = []
            self.isUnitsLoaded = false
            
            // Update @Published properties on main thread as well
            if !Thread.isMainThread {
                DispatchQueue.main.async {
                    self.units = []
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
        
        do {
            let fetchedMealTypes = try context.fetch(fetchRequest)
            
            // Update local state immediately for synchronous access
            self.mealTypes = fetchedMealTypes
            self.isMealTypesLoaded = true
            
            // Update @Published properties on main thread for optimal UI performance
            // Use async only if not already on main thread
            if Thread.isMainThread {
                // Already on main thread, no need to dispatch
            } else {
                DispatchQueue.main.async {
                    self.mealTypes = fetchedMealTypes
                }
            }
            
            if !isTestInstance {
                Self.logger.info("MealTypes cached: \(fetchedMealTypes.count) items")
            } else {
                print("✅ MealTypes cached: \(fetchedMealTypes.count) items")
            }
        } catch {
            Self.logger.error("Error loading meal types for cache: \(error.localizedDescription)")
            // Handle error immediately for synchronous access
            self.mealTypes = []
            self.isMealTypesLoaded = false
            
            // Update @Published properties on main thread as well
            if !Thread.isMainThread {
                DispatchQueue.main.async {
                    self.mealTypes = []
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
        
        do {
            let fetchedCategories = try context.fetch(fetchRequest)
            
            // Update local state immediately for synchronous access
            self.dishCategories = fetchedCategories
            self.isDishCategoriesLoaded = true
            
            // Update @Published properties on main thread for optimal UI performance
            // Use async only if not already on main thread
            if Thread.isMainThread {
                // Already on main thread, no need to dispatch
            } else {
                DispatchQueue.main.async {
                    self.dishCategories = fetchedCategories
                }
            }
            
            if !isTestInstance {
                Self.logger.info("DishCategories cached: \(fetchedCategories.count) items")
            } else {
                print("✅ DishCategories cached: \(fetchedCategories.count) items")
            }
        } catch {
            Self.logger.error("Error loading dish categories for cache: \(error.localizedDescription)")
            // Handle error immediately for synchronous access
            self.dishCategories = []
            self.isDishCategoriesLoaded = false
            
            // Update @Published properties on main thread as well
            if !Thread.isMainThread {
                DispatchQueue.main.async {
                    self.dishCategories = []
                }
            }
        }
    }
    
    private func setupRemoteChangeNotifications() {
        // Only set up notifications if they are enabled
        if notificationsEnabled {
            startListeningForChanges()
        }
    }
    
    private func startListeningForChanges() {
        // Clear existing subscriptions first
        cancellables.removeAll()
        
        // Listen for CoreData changes for automatic cache invalidation
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] notification in
                self?.handleCoreDataChanges(notification)
            }
            .store(in: &cancellables)
    }
    
    private func stopListeningForChanges() {
        cancellables.removeAll()
    }
    
    private func handleCoreDataChanges(_ notification: Notification) {
        // Skip processing if notifications are disabled (for testing)
        guard notificationsEnabled else { return }
        
        guard let userInfo = notification.userInfo else { return }
        
        // Safely extract changed entity names to avoid collection mutation errors
        var changedEntityNames = Set<String>()
        
        // Process each type of change separately to avoid enumeration conflicts
        let changeKeys = [NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey]
        
        for key in changeKeys {
            if let objects = userInfo[key] as? Set<NSManagedObject> {
                // Create a copy to avoid mutation during enumeration
                let objectsCopy = Array(objects)
                for object in objectsCopy {
                    if let entityName = object.entity.name {
                        changedEntityNames.insert(entityName)
                    }
                }
            }
        }
        
        // Invalidate caches based on changed entity types
        if changedEntityNames.contains("Unit") {
            invalidateUnits()
        }
        
        if changedEntityNames.contains("MealType") {
            invalidateMealTypes()
        }
        
        if changedEntityNames.contains("DishCategory") {
            invalidateDishCategories()
        }
    }
    
    deinit {
        stopListeningForChanges()
    }
} 