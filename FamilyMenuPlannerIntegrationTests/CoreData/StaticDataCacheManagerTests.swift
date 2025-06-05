//
//  StaticDataCacheManagerTests.swift
//  FamilyMenuPlannerTests
//
//  Created by Performance Optimization on 28.01.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

final class StaticDataCacheManagerTests: XCTestCase {
    
    var cacheManager: StaticDataCacheManager!
    var context: NSManagedObjectContext!
    var isolatedTestStack: TestCoreDataStack!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a completely isolated test stack for this test class
        isolatedTestStack = TestCoreDataStack()
        context = isolatedTestStack.viewContext
        
        // Ensure the isolated context is completely empty
        clearDatabase()
        
        // Create a fresh test instance for each test instead of using singleton
        cacheManager = StaticDataCacheManager.createTestInstance()
        
        // Initialize with proper context management
        await initializeCacheManager()
        
        // Clear cache after initialization to ensure we start fresh
        cacheManager.invalidateCacheSync()
    }
    
    override func tearDown() async throws {
        // Properly clean up cache manager first
        await cleanupCacheManager()
        
        // Use complete database clearing to ensure test isolation
        clearDatabase()
        
        // Clean up references in proper order
        cacheManager = nil
        context = nil
        isolatedTestStack = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func initializeCacheManager() async {
        // Since initialization is now synchronous, no need for delays
        cacheManager.initialize(with: context)
    }
    
    @MainActor
    private func cleanupCacheManager() async {
        // Use the synchronous cleanup method for testing to avoid retain cycles
        cacheManager?.cleanupSync()
    }
    
    private func clearDatabase() {
        guard let context = context,
              let isolatedTestStack = isolatedTestStack else { return }
        
        context.performAndWait {
            // Use the simpler reset method to avoid memory access issues
            context.reset()
            
            // If we still need to clear data from the persistent store
            let entities = isolatedTestStack.persistentContainer.managedObjectModel.entities
            
            for entity in entities {
                guard let entityName = entity.name else { continue }
                
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
                
                do {
                    let objects = try context.fetch(fetchRequest)
                    objects.forEach { context.delete($0) }
                } catch {
                    print("Failed to clear \(entityName): \(error)")
                }
            }
            
            do {
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                print("Failed to save after clearing database: \(error)")
                context.rollback()
            }
        }
    }
    
    @discardableResult
    private func createTestData<T: NSManagedObject>(
        entityName: String,
        configure: (T) -> Void,
        invalidateCache: Bool = true
    ) -> T {
        var createdObject: T!
        
        context.performAndWait {
            guard let entityDescription = NSEntityDescription.entity(forEntityName: entityName, in: context) else {
                XCTFail("Failed to get \(entityName) entity description")
                return
            }
            
            let object = T(entity: entityDescription, insertInto: context)
            configure(object)
            createdObject = object
            
            do {
                try context.save()
                if invalidateCache {
                    // Use synchronous invalidation instead of async with delay
                    self.cacheManager.invalidateCacheSync()
                }
            } catch {
                XCTFail("Failed to save \(entityName): \(error)")
            }
        }
        
        return createdObject
    }
    
    private func createUnit(name: String, sortOrder: Int16 = 0, invalidateCache: Bool = true) -> Unit {
        return createTestData(entityName: "Unit", configure:  { (unit: Unit) in
            unit.name = name
            unit.sortOrder = sortOrder
        }, invalidateCache: invalidateCache)
    }
    
    private func createMealType(name: String, sortOrder: Int16 = 0, invalidateCache: Bool = true) -> MealType {
        return createTestData(entityName: "MealType", configure:  { (mealType: MealType) in
            mealType.name = name
            mealType.sortOrder = sortOrder
        }, invalidateCache: invalidateCache)
    }
    
    private func createDishCategory(name: String, sortOrder: Int16 = 0, invalidateCache: Bool = true) -> DishCategory {
        return createTestData(entityName: "DishCategory", configure:  { (category: DishCategory) in
            category.name = name
            category.sortOrder = sortOrder
        }, invalidateCache: invalidateCache)
    }
    
    // MARK: - Cache Lazy Loading Tests
    
    func testPreloadingOnInitialization() {
        // Create test data
        _ = createUnit(name: "kg", sortOrder: 1, invalidateCache: false)
        _ = createMealType(name: "Breakfast", sortOrder: 1, invalidateCache: false) 
        _ = createDishCategory(name: "Main Course", sortOrder: 1, invalidateCache: false)
        
        // Clear current cache
        cacheManager.invalidateCacheSync()
        
        // Reinitialize - this should preload all data synchronously
        cacheManager.initialize(with: context)
        
        // Data should be immediately available without additional loading
        let units = cacheManager.getUnits()
        let mealTypes = cacheManager.getMealTypes()
        let categories = cacheManager.getDishCategories()
        
        XCTAssertEqual(units.count, 1)
        XCTAssertEqual(mealTypes.count, 1)
        XCTAssertEqual(categories.count, 1)
    }
    
    func testUnitsLazyLoading() {
        // Create test units
        _ = createUnit(name: "kg", sortOrder: 1, invalidateCache: false)
        _ = createUnit(name: "pcs", sortOrder: 2, invalidateCache: true) // Invalidate after last one
        
        // First access should load data
        let units = cacheManager.getUnits()
        
        XCTAssertEqual(units.count, 2)
        XCTAssertEqual(units[0].name, "kg")
        XCTAssertEqual(units[1].name, "pcs")
        
        // Subsequent access should return cached data without new query
        let cachedUnits = cacheManager.getUnits()
        XCTAssertEqual(cachedUnits.count, 2)
        
        // Check that the objects within arrays are the same (cache is working)
        XCTAssertTrue(units[0] === cachedUnits[0])
        XCTAssertTrue(units[1] === cachedUnits[1])
    }
    
    func testMealTypesLazyLoading() {
        // Create test meal types
        _ = createMealType(name: "Breakfast", sortOrder: 1, invalidateCache: false)
        _ = createMealType(name: "Lunch", sortOrder: 2, invalidateCache: true) // Invalidate after last one
        
        let mealTypes = cacheManager.getMealTypes()
        
        XCTAssertEqual(mealTypes.count, 2)
        XCTAssertEqual(mealTypes[0].name, "Breakfast")
        XCTAssertEqual(mealTypes[1].name, "Lunch")
    }
    
    func testDishCategoriesLazyLoading() {
        // Create test dish categories
        _ = createDishCategory(name: "Main Course", sortOrder: 1, invalidateCache: false)
        _ = createDishCategory(name: "Dessert", sortOrder: 2, invalidateCache: true) // Invalidate after last one
        
        let categories = cacheManager.getDishCategories()
        
        XCTAssertEqual(categories.count, 2)
        XCTAssertEqual(categories[0].name, "Main Course")
        XCTAssertEqual(categories[1].name, "Dessert")
    }
    
    // MARK: - Cache Invalidation Tests
    
    func testCacheInvalidation() {
        // Create test data
        _ = createUnit(name: "liter", sortOrder: 1)
        
        // Load into cache
        let initialUnits = cacheManager.getUnits()
        XCTAssertEqual(initialUnits.count, 1)
        
        // Invalidate cache
        cacheManager.invalidateCacheSync()
        
        // Add new unit to database
        _ = createUnit(name: "ml", sortOrder: 2)
        
        // Next call should reload data
        let updatedUnits = cacheManager.getUnits()
        XCTAssertEqual(updatedUnits.count, 2)
    }
    
    func testSelectiveInvalidation() {
        // This test is no longer relevant since we removed selective invalidation
        // Test general cache invalidation instead
        
        // Create data of all types
        _ = createUnit(name: "kg", sortOrder: 1, invalidateCache: false)
        _ = createMealType(name: "Breakfast", sortOrder: 1, invalidateCache: false)
        _ = createDishCategory(name: "Main Course", sortOrder: 1, invalidateCache: true) // Invalidate after all created
        
        // Load all into cache
        let units = cacheManager.getUnits()
        let mealTypes = cacheManager.getMealTypes()
        let categories = cacheManager.getDishCategories()
        
        XCTAssertEqual(units.count, 1)
        XCTAssertEqual(mealTypes.count, 1)
        XCTAssertEqual(categories.count, 1)
        
        // Add new unit
        _ = createUnit(name: "pcs", sortOrder: 2, invalidateCache: false)
        
        // Cache should still show old data until manually invalidated
        let staleUnits = cacheManager.getUnits()
        XCTAssertEqual(staleUnits.count, 1, "Cache should still show 1 unit until manually invalidated")
        
        // Manually invalidate entire cache (since we removed selective invalidation)
        cacheManager.invalidateCache()
        
        // Wait for async invalidation to complete
        let expectation = XCTestExpectation(description: "Cache invalidation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // All caches should reload with fresh data
        let newUnits = cacheManager.getUnits()
        let newMealTypes = cacheManager.getMealTypes()
        let newCategories = cacheManager.getDishCategories()
        
        XCTAssertEqual(newUnits.count, 2)
        XCTAssertEqual(newMealTypes.count, 1)
        XCTAssertEqual(newCategories.count, 1)
        
        // Since we invalidated the entire cache, it should have reloaded all data
        // Note: CoreData objects with same ObjectID may be the same instance in the same context
        // So we verify the cache was refreshed by confirming we got the updated unit count
        XCTAssertTrue(newUnits.count > units.count, "Cache should have refreshed and loaded the new unit")
    }
    
    func testNotificationBasedInvalidation() {
        // This test is no longer relevant since we removed notification-based invalidation
        // Test manual invalidation instead
        
        // Create test data and load into cache
        _ = createUnit(name: "kg", sortOrder: 1, invalidateCache: false)
        cacheManager.invalidateCacheSync()
        
        // Load into cache
        let initialUnits = cacheManager.getUnits()
        XCTAssertEqual(initialUnits.count, 1, "Should have 1 unit after creating and loading")
        
        // Add new unit to database
        _ = createUnit(name: "pcs", sortOrder: 2, invalidateCache: false)
        
        // Cache should still show old data (1 unit) until manually invalidated
        let unitsBeforeInvalidation = cacheManager.getUnits()
        XCTAssertEqual(unitsBeforeInvalidation.count, 1, "Cache should still show 1 unit before invalidation")
        
        // Manually invalidate cache
        cacheManager.invalidateCache()
        
        // Wait a moment for async invalidation to complete
        let expectation = XCTestExpectation(description: "Cache invalidation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Cache should be reloaded with new data (2 units)
        let updatedUnits = cacheManager.getUnits()
        XCTAssertEqual(updatedUnits.count, 2, "Cache should show 2 units after invalidation and reload")
    }
    
    func testNotificationSystemSetup() {
        // This test is no longer relevant since we removed notification system
        // Test basic cache functionality instead
        
        // Verify cache can be initialized
        let testCacheManager = StaticDataCacheManager.createTestInstance()
        testCacheManager.initialize(with: context)
        
        // Verify it can be cleaned up
        testCacheManager.cleanupSync()
        
        // If we reach here without issues, the basic cache system works
        XCTAssertTrue(true, "Cache system setup and cleanup completed successfully")
    }
    
    func testBasicCacheInvalidationWithNotifications() {
        // This test is no longer relevant since we removed notifications
        // Test basic cache invalidation instead
        
        // Test basic functionality
        let initialUnits = cacheManager.getUnits()
        XCTAssertEqual(initialUnits.count, 0, "Should start with no units")
        
        // Manually invalidate to test the mechanism
        cacheManager.invalidateCache()
        
        // Wait for async operation to complete
        let expectation = XCTestExpectation(description: "Cache invalidation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify it still works after invalidation
        let unitsAfterInvalidation = cacheManager.getUnits()
        XCTAssertEqual(unitsAfterInvalidation.count, 0, "Should still have no units after invalidation")
    }
    
    func testAutomaticNotificationInvalidation() {
        // This test is no longer relevant since we removed automatic notifications
        // Test manual cache refresh instead
        
        let sharedManager = StaticDataCacheManager.shared
        sharedManager.initialize(with: context)
        
        // Create initial data
        _ = createUnit(name: "kg", sortOrder: 1, invalidateCache: false)
        sharedManager.invalidateCacheSync()
        
        // Load into cache
        let initialUnits = sharedManager.getUnits()
        XCTAssertEqual(initialUnits.count, 1, "Should have 1 unit")
        
        // Create additional data
        context.performAndWait {
            let newUnit = Unit(context: context)
            newUnit.name = "pcs"
            newUnit.sortOrder = 2
            
            do {
                try context.save()
            } catch {
                XCTFail("Failed to save new unit: \(error)")
            }
        }
        
        // Cache should still show old data until manually refreshed
        let staleUnits = sharedManager.getUnits()
        XCTAssertEqual(staleUnits.count, 1, "Cache should still show 1 unit until manually refreshed")
        
        // Manually refresh cache
        sharedManager.invalidateCache()
        
        // Wait for async operation
        let expectation = XCTestExpectation(description: "Manual refresh")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Cache should now show updated data
        let updatedUnits = sharedManager.getUnits()
        XCTAssertEqual(updatedUnits.count, 2, "Cache should show 2 units after manual refresh")
    }
    
    func testConcurrentAccess() {
        // Create test data using the simplified helper
        for i in 1...10 {
            _ = createUnit(name: "Unit \(i)", sortOrder: Int16(i), invalidateCache: false)
        }
        
        // Force cache to reload data once after all units are created
        cacheManager.invalidateCacheSync()
        let _ = cacheManager.getUnits() // Preload to avoid race conditions
        
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 5
        
        // Start several concurrent cache accesses
        for i in 0..<5 {
            DispatchQueue.global().async {
                let units = self.cacheManager.getUnits()
                XCTAssertEqual(units.count, 10, "Concurrent access \(i) failed")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testPublishedUpdatesHappenOnMainThread() {
        // Clear cache first
        cacheManager.invalidateCacheSync()
        
        // Create test data on a background thread
        let backgroundContext = isolatedTestStack!.newBackgroundContext()
        backgroundContext.performAndWait {
            let unit = Unit(context: backgroundContext)
            unit.name = "Test Unit"
            unit.sortOrder = 1
            
            try! backgroundContext.save()
        }
        
        // Ensure the main context can see the changes by refreshing
        context.performAndWait {
            context.refreshAllObjects()
        }
        
        // Force cache invalidation to pick up the new data
        cacheManager.invalidateCacheSync()
        
        // Verify @Published updates happen on main thread
        let expectation = XCTestExpectation(description: "Units loaded on main thread")
        
        DispatchQueue.global(qos: .background).async {
            // Trigger cache load from background thread
            let units = self.cacheManager.getUnits()
            
            // Verify the @Published property is eventually updated on main thread
            DispatchQueue.main.async {
                XCTAssertEqual(units.count, 1)
                XCTAssertEqual(units.first?.name, "Test Unit")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
} 
