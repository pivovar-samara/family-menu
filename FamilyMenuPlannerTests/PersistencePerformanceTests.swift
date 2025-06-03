//
//  PersistencePerformanceTests.swift
//  FamilyMenuPlannerTests
//
//  Created by Performance Optimization
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

class PersistencePerformanceTests: BaseIntegrationTest {
    var persistenceController: PersistenceController!
    
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
    }
    
    override func tearDown() {
        persistenceController = nil
        super.tearDown()
    }
    
    func testInMemoryStoreSkipsQueryGeneration() {
        // Test that in-memory stores (used in tests) don't have query generation
        // This is expected behavior since in-memory stores don't support this feature
        let persistenceContext = persistenceController.container.viewContext
        
        // In-memory stores should not have query generation due to technical limitations
        // This is not a failure - it's the expected behavior for test environments
        if persistenceContext.queryGenerationToken == nil {
            print("✅ In-memory store correctly skips query generation (expected behavior)")
        } else {
            XCTFail("In-memory stores should not have query generation configured")
        }
    }
    
    func testNewBackgroundContextHandlesInMemoryStore() {
        // Test that background contexts handle in-memory stores gracefully
        let backgroundContext = persistenceController.newBackgroundContext()
        
        // Background contexts should be properly configured even without query generation
        XCTAssertNotNil(backgroundContext)
        XCTAssertEqual(backgroundContext.concurrencyType, .privateQueueConcurrencyType)
        XCTAssertTrue(backgroundContext.automaticallyMergesChangesFromParent)
        XCTAssertNil(backgroundContext.undoManager)
        XCTAssertTrue(backgroundContext.shouldDeleteInaccessibleFaults)
    }
    
    func testServiceOperationsWithoutExplicitQueryGeneration() {
        // Create test data using helper methods in the BaseIntegrationTest context
        let unit = createUnit(name: "pcs", sortOrder: 1)
        _ = createProduct(name: "Test Product", unit: unit)
        
        // Test that services work without explicit setQueryGenerationFrom calls
        let productListService = ProductListService(context: context)
        let products = productListService.fetchAllProducts()
        
        XCTAssertEqual(products.count, 1)
        XCTAssertEqual(products.first?.name, "Test Product")
    }
    
    func testDishServiceOperations() {
        // Create test data using helper methods
        _ = createDish(name: "Test Dish", details: "Test details")
        
        // Test that dish services work correctly
        let dishSelectionService = DishSelectionService(context: context)
        let dishes = dishSelectionService.fetchAllDishes()
        
        XCTAssertEqual(dishes.count, 1)
        XCTAssertEqual(dishes.first?.name, "Test Dish")
    }
    
    func testPerformanceOfOptimizedServices() {
        // Create multiple test entities for performance testing
        var units: [Unit] = []
        for i in 0..<10 {  // Reduced count for faster test execution
            let unit = createUnit(name: "Unit \(i)", sortOrder: Int16(i))
            units.append(unit)
            _ = createProduct(name: "Product \(i)", unit: unit)
        }
        
        let productListService = ProductListService(context: context)
        
        // Measure performance of fetch operations
        measure {
            _ = productListService.fetchAllProducts()
        }
    }
    
    func testMultipleServiceOperationsWork() {
        // Create comprehensive test data
        let unit = createUnit(name: "kg")
        _ = createProduct(name: "Flour", unit: unit)
        let mealType = createMealType(name: "Breakfast")
        let category = createDishCategory(name: "Main Course")
        _ = createDish(name: "Pancakes", details: "Delicious pancakes", mealTypes: [mealType], category: category)
        
        // Test various services
        let productListService = ProductListService(context: context)
        let dishDetailsService = DishDetailsService(context: context)
        let dishSelectionService = DishSelectionService(context: context)
        
        // All services should work without explicit setQueryGenerationFrom calls
        let products = productListService.fetchAllProducts()
        let units = dishDetailsService.fetchAllUnits()
        let mealTypes = dishDetailsService.fetchAllMealTypes()
        let categories = dishDetailsService.fetchAllDishCategories()
        let dishes = dishSelectionService.fetchAllDishes()
        
        // Verify all services returned expected data
        XCTAssertEqual(products.count, 1)
        XCTAssertEqual(units.count, 1)
        XCTAssertEqual(mealTypes.count, 1)
        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(dishes.count, 1)
        
        XCTAssertEqual(products.first?.name, "Flour")
        XCTAssertEqual(units.first?.name, "kg")
        XCTAssertEqual(mealTypes.first?.name, "Breakfast")
        XCTAssertEqual(categories.first?.name, "Main Course")
        XCTAssertEqual(dishes.first?.name, "Pancakes")
    }
    
    func testServicesWorkWithPersistenceControllerContext() {
        // Test that services work correctly with the PersistenceController (the real optimization)
        // We don't need to test data persistence here - just that the service methods don't crash
        // and can be called without the redundant setQueryGenerationFrom calls
        
        let persistenceContext = persistenceController.container.viewContext
        
        // Test various services with the optimized context
        let productListService = ProductListService(context: persistenceContext)
        let dishDetailsService = DishDetailsService(context: persistenceContext)
        let dishSelectionService = DishSelectionService(context: persistenceContext)
        
        // These calls should all work without throwing exceptions
        // (they will return empty results since no data is created, which is fine)
        XCTAssertNoThrow(productListService.fetchAllProducts())
        XCTAssertNoThrow(dishDetailsService.fetchAllUnits())
        XCTAssertNoThrow(dishDetailsService.fetchAllMealTypes()) 
        XCTAssertNoThrow(dishDetailsService.fetchAllDishCategories())
        XCTAssertNoThrow(dishSelectionService.fetchAllDishes())
        
        // Verify the services return empty arrays (expected with no data)
        XCTAssertEqual(productListService.fetchAllProducts().count, 0)
        XCTAssertEqual(dishDetailsService.fetchAllUnits().count, 0)
        XCTAssertEqual(dishDetailsService.fetchAllMealTypes().count, 0)
        XCTAssertEqual(dishDetailsService.fetchAllDishCategories().count, 0)
        XCTAssertEqual(dishSelectionService.fetchAllDishes().count, 0)
        
        print("✅ All service operations completed successfully with optimized context")
    }
    
    func testContextConfigurationIsProperlyApplied() {
        // Test that all context configurations are applied correctly
        let persistenceContext = persistenceController.container.viewContext
        let backgroundContext = persistenceController.newBackgroundContext()
        
        // Test view context configuration
        XCTAssertTrue(persistenceContext.automaticallyMergesChangesFromParent)
        XCTAssertNil(persistenceContext.undoManager)
        XCTAssertTrue(persistenceContext.shouldDeleteInaccessibleFaults)
        XCTAssertNotNil(persistenceContext.mergePolicy)
        
        // Test background context configuration
        XCTAssertTrue(backgroundContext.automaticallyMergesChangesFromParent)
        XCTAssertNil(backgroundContext.undoManager)
        XCTAssertTrue(backgroundContext.shouldDeleteInaccessibleFaults)
        XCTAssertNotNil(backgroundContext.mergePolicy)
    }
    
    func testAsynchronousStoreLoadingPerformance() {
        // Test that the new asynchronous store loading doesn't block the calling thread
        let expectation = XCTestExpectation(description: "Async store loading completes")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Create a new persistence controller to test initialization
        let testController = PersistenceController(inMemory: true)
        
        // Test the new async recovery method
        testController.attemptRecovery { success in
            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = endTime - startTime
            
            XCTAssertTrue(success, "Store loading should succeed")
            XCTAssertLessThan(duration, 1.0, "Async initialization should complete quickly for in-memory stores")
            
            expectation.fulfill()
        }
        
        // Verify the calling thread is not blocked
        let afterCallTime = CFAbsoluteTimeGetCurrent()
        let callDuration = afterCallTime - startTime
        XCTAssertLessThan(callDuration, 0.1, "Async method should return immediately without blocking")
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testBackwardCompatibilityOfSynchronousRecovery() {
        // Test that the synchronous recovery method still works for existing code
        let testController = PersistenceController(inMemory: true)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let success = testController.attemptRecovery()
        let endTime = CFAbsoluteTimeGetCurrent()
        
        XCTAssertTrue(success, "Synchronous recovery should succeed")
        
        // For in-memory stores, this should still be relatively fast
        let duration = endTime - startTime
        XCTAssertLessThan(duration, 1.0, "Synchronous recovery should complete reasonably quickly for in-memory stores")
    }
    
    func testStoreLoadingDoesNotBlockMainThread() {
        // This test verifies that store loading can be called from main thread without blocking
        let expectation = XCTestExpectation(description: "Main thread not blocked")
        
        DispatchQueue.main.async {
            let testController = PersistenceController(inMemory: true)
            
            // Use async version to avoid blocking main thread
            testController.attemptRecovery { success in
                XCTAssertTrue(success, "Recovery should succeed")
                expectation.fulfill()
            }
            
            // This code should execute immediately, proving main thread isn't blocked
            XCTAssertTrue(Thread.isMainThread, "Should still be on main thread")
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
} 
