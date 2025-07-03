//
//  StaticDataCacheManagerUnitTests.swift
//  FamilyMenuPlannerTests
//
//  Created by Critical Test Review on 28.01.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

class StaticDataCacheManagerUnitTests: XCTestCase {
    var cacheManager: StaticDataCacheManager!
    var testStack: TestCoreDataStack!
    var context: NSManagedObjectContext!
    var testDataFactory: TestDataFactory!
    
    override func setUp() {
        super.setUp()
        testStack = TestCoreDataStack.shared
        context = testStack.viewContext
        testDataFactory = TestDataFactory(context: context)
        
        // Clean up any existing data
        cleanUpTestData()
        
        // Create static data cache manager with test context
        cacheManager = StaticDataCacheManager.createTestInstance()
        cacheManager.initialize(with: context)
    }
    
    override func tearDown() {
        cleanUpTestData()
        cacheManager = nil
        testDataFactory = nil
        context = nil
        testStack = nil
        super.tearDown()
    }
    
    private func cleanUpTestData() {
        testDataFactory?.cleanUpTestData()
    }
    
    // MARK: - Test Initialization
    
    func testInitialization() {
        let manager = StaticDataCacheManager.createTestInstance()
        XCTAssertNotNil(manager, "Should create test instance")
        
        manager.initialize(with: context)
        
        // Should be able to call get methods without crash
        XCTAssertNotNil(manager.getUnits())
        XCTAssertNotNil(manager.getMealTypes())
        XCTAssertNotNil(manager.getDishCategories())
        
        manager.cleanupSync()
    }
    
    // MARK: - Test Units Caching
    
    func testGetUnitsEmptyDatabase() {
        let units = cacheManager.getUnits()
        XCTAssertEqual(units.count, 0, "Should return empty array for empty database")
    }
    
    func testGetUnitsWithData() {
        // Create test units
        _ = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        _ = testDataFactory.createUnit(name: "pcs", sortOrder: 2)
        
        // Clear cache to force reload
        cacheManager.invalidateCacheSync()
        
        let units = cacheManager.getUnits()
        XCTAssertEqual(units.count, 2, "Should return 2 units")
        
        // Verify order
        XCTAssertEqual(units[0].name, "kg")
        XCTAssertEqual(units[1].name, "pcs")
    }
    
    func testGetUnitsLazyLoading() {
        // Create test unit
        _ = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        
        // Create fresh cache manager without preload
        let freshManager = StaticDataCacheManager.createTestInstance()
        freshManager.initialize(with: context)
        
        // First call should load data
        let units = freshManager.getUnits()
        XCTAssertEqual(units.count, 1, "Should load units on first access")
        XCTAssertEqual(units.first?.name, "kg")
        
        freshManager.cleanupSync()
    }
    
    func testGetUnitsCaching() {
        // Create test unit
        _ = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        cacheManager.invalidateCacheSync()
        
        // First call
        _ = cacheManager.getUnits()
        
        // Add another unit directly to context (bypassing cache)
        _ = testDataFactory.createUnit(name: "pcs", sortOrder: 2)
        
        // Second call should return cached data (not including new unit)
        let units2 = cacheManager.getUnits()
        XCTAssertEqual(units2.count, 1, "Should return cached data without new unit")
    }
    
    // MARK: - Test MealTypes Caching
    
    func testGetMealTypesEmptyDatabase() {
        let mealTypes = cacheManager.getMealTypes()
        XCTAssertEqual(mealTypes.count, 0, "Should return empty array for empty database")
    }
    
    func testGetMealTypesWithData() {
        // Create test meal types
        _ = testDataFactory.createMealType(name: "Breakfast", sortOrder: 1)
        _ = testDataFactory.createMealType(name: "Lunch", sortOrder: 2)
        
        // Clear cache to force reload
        cacheManager.invalidateCacheSync()
        
        let mealTypes = cacheManager.getMealTypes()
        XCTAssertEqual(mealTypes.count, 2, "Should return 2 meal types")
        
        // Verify order
        XCTAssertEqual(mealTypes[0].name, "Breakfast")
        XCTAssertEqual(mealTypes[1].name, "Lunch")
    }
    
    // MARK: - Test DishCategories Caching
    
    func testGetDishCategoriesEmptyDatabase() {
        let categories = cacheManager.getDishCategories()
        XCTAssertEqual(categories.count, 0, "Should return empty array for empty database")
    }
    
    func testGetDishCategoriesWithData() {
        // Create test categories
        _ = testDataFactory.createDishCategory(name: "Main Course", sortOrder: 1)
        _ = testDataFactory.createDishCategory(name: "Dessert", sortOrder: 2)
        
        // Clear cache to force reload
        cacheManager.invalidateCacheSync()
        
        let categories = cacheManager.getDishCategories()
        XCTAssertEqual(categories.count, 2, "Should return 2 categories")
        
        // Verify order
        XCTAssertEqual(categories[0].name, "Main Course")
        XCTAssertEqual(categories[1].name, "Dessert")
    }
    
    // MARK: - Test Cache Invalidation
    
    func testInvalidateCache() {
        // Create initial data
        _ = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        cacheManager.invalidateCacheSync()
        
        // Load into cache
        let initialUnits = cacheManager.getUnits()
        XCTAssertEqual(initialUnits.count, 1)
        
        // Add more data
        _ = testDataFactory.createUnit(name: "pcs", sortOrder: 2)
        
        // Cache should still show old data
        let cachedUnits = cacheManager.getUnits()
        XCTAssertEqual(cachedUnits.count, 1, "Cache should show old data")
        
        // Invalidate cache
        cacheManager.invalidateCacheSync()
        
        // Now should show updated data
        let updatedUnits = cacheManager.getUnits()
        XCTAssertEqual(updatedUnits.count, 2, "Should show updated data after invalidation")
    }
    
    func testInvalidateCacheAsync() {
        // Create initial data
        _ = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        cacheManager.invalidateCacheSync()
        
        // Load into cache
        let initialUnits = cacheManager.getUnits()
        XCTAssertEqual(initialUnits.count, 1)
        
        // Add more data
        _ = testDataFactory.createUnit(name: "pcs", sortOrder: 2)
        
        // Async invalidation with completion callback
        let expectation = expectation(description: "Cache invalidated")
        cacheManager.invalidateCache {
            let updatedUnits = self.cacheManager.getUnits()
            XCTAssertEqual(updatedUnits.count, 2, "Should show updated data after async invalidation")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Test Cleanup
    
    func testCleanup() {
        // Create data and load into cache
        _ = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        cacheManager.invalidateCacheSync()
        let _ = cacheManager.getUnits()
        
        // Cleanup
        cacheManager.cleanupSync()
        
        // Should be able to call cleanup multiple times without crash
        cacheManager.cleanupSync()
        
        // After cleanup, context is nil so reinitialize to use it again
        cacheManager.initialize(with: context)
        
        // Now should be able to get data (will reload)
        let units = cacheManager.getUnits()
        XCTAssertEqual(units.count, 1, "Should still work after cleanup and reinitialization")
    }
    
    // MARK: - Test Thread Safety
    
    func testConcurrentAccess() {
        // Create test data
        _ = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        _ = testDataFactory.createMealType(name: "Breakfast", sortOrder: 1)
        cacheManager.invalidateCacheSync()
        
        let expectation = expectation(description: "Concurrent access completed")
        expectation.expectedFulfillmentCount = 3
        
        // Access cache from multiple threads
        DispatchQueue.global().async {
            let units = self.cacheManager.getUnits()
            XCTAssertGreaterThanOrEqual(units.count, 0)
            expectation.fulfill()
        }
        
        DispatchQueue.global().async {
            let mealTypes = self.cacheManager.getMealTypes()
            XCTAssertGreaterThanOrEqual(mealTypes.count, 0)
            expectation.fulfill()
        }
        
        DispatchQueue.global().async {
            let categories = self.cacheManager.getDishCategories()
            XCTAssertGreaterThanOrEqual(categories.count, 0)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testConcurrentInvalidation() {
        // Create test data
        _ = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        cacheManager.invalidateCacheSync()
        
        let expectation = expectation(description: "Concurrent invalidation completed")
        expectation.expectedFulfillmentCount = 2
        
        // Invalidate from multiple threads with completion callbacks
        DispatchQueue.global().async {
            self.cacheManager.invalidateCache {
                expectation.fulfill()
            }
        }
        
        DispatchQueue.global().async {
            self.cacheManager.invalidateCache {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Should still work after concurrent invalidation
        let units = cacheManager.getUnits()
        XCTAssertGreaterThanOrEqual(units.count, 0)
    }
    
    // MARK: - Test Error Handling
    
    func testInvalidContextHandling() {
        let manager = StaticDataCacheManager.createTestInstance()
        
        // Don't initialize with context, or initialize with nil context equivalent
        // Should handle gracefully without crashing
        XCTAssertNoThrow(manager.getUnits())
        XCTAssertNoThrow(manager.getMealTypes())
        XCTAssertNoThrow(manager.getDishCategories())
        
        manager.cleanupSync()
    }
    
    func testMultipleInitialization() {
        // Should handle multiple initialization calls gracefully
        cacheManager.initialize(with: context)
        cacheManager.initialize(with: context)
        cacheManager.initialize(with: context)
        
        // Should still work normally
        let units = cacheManager.getUnits()
        XCTAssertGreaterThanOrEqual(units.count, 0)
    }
    
    /// Verifies that concurrent access to getUnits does not crash and results in a single coherent dataset.
    func testConcurrentGetUnitsThreadSafety() {
        // Seed test data
        _ = testDataFactory.createUnit(name: "g")
        _ = testDataFactory.createUnit(name: "kg")
        _ = testDataFactory.createUnit(name: "pcs")

        // Use a fresh cache instance to avoid interference with other tests in this class.
        let cache = StaticDataCacheManager.createTestInstance()
        cache.initialize(with: context)

        let iterations = 20
        let group = DispatchGroup()
        let concurrentQueue = DispatchQueue(label: "concurrentTestQueue", attributes: .concurrent)

        for _ in 0..<iterations {
            group.enter()
            concurrentQueue.async {
                _ = cache.getUnits()
                group.leave()
            }
        }

        // Also call once on the main thread to simulate UI usage
        _ = cache.getUnits()

        // Wait for all background calls to complete
        let result = group.wait(timeout: .now() + 5)
        XCTAssertEqual(result, .success, "Background calls did not finish in time, potential deadlock detected")

        // Ensure we still have the seeded data and nothing unexpected happened
        let units = cache.getUnits()
        XCTAssertEqual(units.count, 3)
    }
} 
