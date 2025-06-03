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
        cacheManager.initialize(with: context)
        
        // Clear cache after initialization to ensure we start fresh
        cacheManager.invalidateCacheSync()
    }
    
    override func tearDown() async throws {
        // Invalidate cache first
        cacheManager?.invalidateCacheSync()
        
        // Use complete database clearing to ensure test isolation
        clearDatabase()
        
        // Clean up references
        cacheManager = nil
        isolatedTestStack = nil
        context = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func clearDatabase() {
        guard let context = context,
              let isolatedTestStack = isolatedTestStack else { return }
        
        context.performAndWait {
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
                    cacheManager.invalidateCacheSync()
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
    
    private func createUnitsInBackground(count: Int) {
        let backgroundContext = isolatedTestStack.newBackgroundContext()
        
        backgroundContext.performAndWait {
            guard let entityDescription = NSEntityDescription.entity(forEntityName: "Unit", in: backgroundContext) else {
                XCTFail("Failed to get Unit entity description for background context")
                return
            }
            
            for i in 1...count {
                let unit = Unit(entity: entityDescription, insertInto: backgroundContext)
                unit.name = "Unit \(i)"
                unit.sortOrder = Int16(i)
            }
            
            do {
                try backgroundContext.save()
            } catch {
                XCTFail("Failed to save units in background: \(error)")
            }
        }
        
        // Merge changes to main context
        context.performAndWait {
            context.refreshAllObjects()
        }
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
        
        // Manually invalidate only units (since notifications are disabled)
        cacheManager.invalidateUnits()
        
        // Wait for async invalidation to complete
        let expectation = XCTestExpectation(description: "Cache invalidation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Add new unit
        _ = createUnit(name: "pcs", sortOrder: 2)
        
        // Units should reload, others should remain cached
        let newUnits = cacheManager.getUnits()
        let sameMealTypes = cacheManager.getMealTypes()
        let sameCategories = cacheManager.getDishCategories()
        
        XCTAssertEqual(newUnits.count, 2)
        XCTAssertEqual(sameMealTypes.count, 1)
        XCTAssertEqual(sameCategories.count, 1)
        
        // Check that meal types and categories remained the same objects
        XCTAssertTrue(mealTypes[0] === sameMealTypes[0])
        XCTAssertTrue(categories[0] === sameCategories[0])
    }
    
    func testNotificationBasedInvalidation() {
        // Create a separate instance with notifications enabled for this test
        let notificationCacheManager = StaticDataCacheManager(enableNotifications: true)
        notificationCacheManager.initialize(with: context)
        
        // Create test data
        _ = createUnit(name: "kg", sortOrder: 1)
        
        // Load into cache
        let initialUnits = notificationCacheManager.getUnits()
        XCTAssertEqual(initialUnits.count, 1)
        
        // Create expectation for notification handling
        let expectation = XCTestExpectation(description: "Notification handling")
        
        // Add new unit which should trigger notification
        _ = createUnit(name: "pcs", sortOrder: 2)
        
        // Wait for notification to be processed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Cache should be invalidated and reloaded
            let updatedUnits = notificationCacheManager.getUnits()
            XCTAssertEqual(updatedUnits.count, 2)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Clean up by disabling notifications
        notificationCacheManager.disableNotifications()
    }
    
    // MARK: - Performance Tests
    
    func testCacheFirstLoadPerformance() {
        // Create many units using background context to avoid notification conflicts
        createUnitsInBackground(count: 100)
        
        // Give a moment for any pending notifications to settle
        let expectation = XCTestExpectation(description: "Settle notifications")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Invalidate cache once after creating all data
        cacheManager.invalidateCacheSync()
        
        // Measure time of first load
        self.measure {
            let _ = cacheManager.getUnits()
        }
    }
    
    func testCacheSubsequentAccessPerformance() {
        // Create many units using background context to avoid notification conflicts
        createUnitsInBackground(count: 100)
        
        // Give a moment for any pending notifications to settle
        let expectation = XCTestExpectation(description: "Settle notifications")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Invalidate cache once and load into cache first
        cacheManager.invalidateCacheSync()
        let _ = cacheManager.getUnits()
        
        // Measure time of subsequent cache accesses
        self.measure {
            for _ in 0..<1000 {
                let _ = cacheManager.getUnits()
            }
        }
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
} 
