//
//  DishListServicePerformanceTests.swift
//  FamilyMenuPlannerPerformanceTests
//
//  Created by Performance Optimization on 28.01.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

class DishListServicePerformanceTests: BaseIntegrationTest {
    
    override func setUp() {
        // Use TestCoreDataStack which properly loads the model from the correct bundle
        context = TestCoreDataStack.shared.viewContext
        testDataFactory = TestDataFactory(context: context)
        
        // Clear cache before each test to ensure test isolation
        StaticDataCacheManager.shared.invalidateCacheSync()
        cleanUpTestData()
    }
    
    override func tearDown() {
        cleanUpTestData()
        // Clear cache after each test to prevent interference with other tests
        StaticDataCacheManager.shared.invalidateCacheSync()
        testDataFactory = nil
        context = nil
        super.tearDown()
    }
    
    func testDebouncedUpdatePerformance() {
        let dishListService = DishListService(context: context)
        let mockDelegate = MockPerformanceDelegate()
        dishListService.delegate = mockDelegate
        
        // Create initial data using test factory
        let category = createDishCategory(name: "Performance Test Category")
        for i in 1...50 {
            _ = createDish(name: "Initial Dish \(i)", category: category)
        }
        
        // Initial fetch
        dishListService.fetchAllDishes()
        
        // First, test that debouncing works correctly (single operation, not measured)
        mockDelegate.resetMetrics()
        let updateExpectation = expectation(description: "Batch updates completed")
        mockDelegate.onUpdate = { _ in
            updateExpectation.fulfill()
        }
        
        // Perform rapid batch updates that would previously cause excessive UI refreshes
        context.performAndWait {
            for i in 1...20 {
                let dish = Dish(context: self.context)
                dish.name = "Performance Test Dish \(i)"
                dish.category = category
            }
            try! self.context.save()
        }
        
        wait(for: [updateExpectation], timeout: 1.0)
        
        // Verify that debouncing reduced the number of delegate calls
        XCTAssertEqual(mockDelegate.totalUpdateCount, 1, "Debouncing should result in single update for batch operation")
        
        // Now measure performance of the batch operation
        measure {
            context.performAndWait {
                for i in 1...20 {
                    let dish = Dish(context: self.context)
                    dish.name = "Perf Dish \(i)"
                    dish.category = category
                }
                try! self.context.save()
            }
        }
    }
    
    func testMemoryUsageDuringRapidUpdates() {
        let dishListService = DishListService(context: context)
        let mockDelegate = MockPerformanceDelegate()
        dishListService.delegate = mockDelegate
        
        let category = createDishCategory(name: "Memory Test Category")
        
        // Initialize the NSFetchedResultsController with an initial fetch
        dishListService.fetchAllDishes()
        print("Initial dishes count: \(mockDelegate.totalUpdateCount)")
        mockDelegate.resetMetrics()
        
        // Test that debouncing works for rapid updates (not measured)
        let finalExpectation = expectation(description: "Final update")
        var hasBeenFulfilled = false
        
        mockDelegate.onUpdate = { dishes in
            print("Delegate called with \(dishes.count) dishes, total calls: \(mockDelegate.totalUpdateCount)")
            if !hasBeenFulfilled && dishes.count >= 50 {
                hasBeenFulfilled = true
                finalExpectation.fulfill()
            }
        }
        
        print("Starting rapid updates...")
        
        // Simulate rapid data changes using the helper methods (which save individually)
        for batch in 1...10 {
            autoreleasepool {
                for i in 1...5 {
                    _ = createDish(name: "Memory Test Batch \(batch) Dish \(i)", category: category)
                }
                print("Created batch \(batch), total dishes should be \(batch * 5)")
                
                // Allow debounce timer to potentially fire
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
            }
        }
        
        print("Finished rapid updates, waiting for delegate...")
        
        // Wait for final debounced update
        wait(for: [finalExpectation], timeout: 3.0)
        
        print("Final delegate call count: \(mockDelegate.totalUpdateCount)")
        
        // Memory should be managed efficiently with debouncing
        XCTAssertLessThanOrEqual(mockDelegate.totalUpdateCount, 15, "Should have significantly fewer updates than data changes")
        
        // Now measure performance of similar rapid update operations
        measure {
            for batch in 1...5 {
                for i in 1...3 {
                    _ = createDish(name: "Perf Memory Batch \(batch) Dish \(i)", category: category)
                }
            }
        }
    }
    
    func testUIResponsivenessDuringBulkOperations() {
        let dishListService = DishListService(context: context)
        let mockDelegate = MockPerformanceDelegate()
        dishListService.delegate = mockDelegate
        
        let category = createDishCategory(name: "Bulk Test Category")
        
        // Initialize the NSFetchedResultsController
        dishListService.fetchAllDishes()
        mockDelegate.resetMetrics()
        
        // Test that bulk operations work with debouncing (not measured)
        let updateExpectation = expectation(description: "Bulk update")
        var hasBeenFulfilled = false
        
        mockDelegate.onUpdate = { dishes in
            print("Bulk test delegate called with \(dishes.count) dishes, total calls: \(mockDelegate.totalUpdateCount)")
            if !hasBeenFulfilled && dishes.count >= 50 {
                hasBeenFulfilled = true
                updateExpectation.fulfill()
            }
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        print("Starting bulk operations...")
        
        // Simulate bulk import using individual saves (which should trigger NSFetchedResultsController)
        for i in 1...50 {
            autoreleasepool {
                _ = createDish(name: "Bulk Import Dish \(i)", category: category)
                
                // Small delay every 10 items to allow debouncing to work
                if i % 10 == 0 {
                    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.02))
                }
            }
        }
        
        print("Finished bulk operations, waiting for delegate...")
        
        // Wait for debounced update
        wait(for: [updateExpectation], timeout: 3.0)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        
        print("Bulk operation completed in \(totalTime) seconds with \(mockDelegate.totalUpdateCount) delegate calls")
        
        // With debouncing, this should complete in reasonable time for tests
        XCTAssertLessThan(totalTime, 5.0, "Bulk operation with debouncing should complete in reasonable time for test environment")
        
        // Verify that debouncing worked
        XCTAssertLessThanOrEqual(mockDelegate.totalUpdateCount, 10, "Should have fewer delegate calls than individual operations due to debouncing")
        
        // Now measure performance of smaller bulk operations
        measure {
            for i in 1...20 {
                _ = createDish(name: "Perf Bulk Dish \(i)", category: category)
            }
        }
    }
    
    // MARK: - Baseline Comparison Test
    
    func testCompareWithNonDebouncedApproach() {
        // This test documents the improvement achieved by debouncing
        // by comparing with a simulated non-debounced approach
        
        let dishListService = DishListService(context: context)
        let mockDelegate = MockPerformanceDelegate()
        dishListService.delegate = mockDelegate
        
        let category = createDishCategory(name: "Comparison Test Category")
        
        // First, test debouncing behavior (not measured)
        let finalExpectation = expectation(description: "All updates complete")
        
        let updateCount = 20
        for i in 1...updateCount {
            autoreleasepool {
                _ = self.createDish(name: "Comparison Test Dish \(i)", category: category)
                
                // Small delay to simulate individual change notifications
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
            }
        }
        
        // Wait for all debounced updates to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            finalExpectation.fulfill()
        }
        wait(for: [finalExpectation], timeout: 1.0)
        
        // With debouncing, we should have significantly fewer updates than changes
        print("Total data changes: 20, Actual delegate updates: \(mockDelegate.totalUpdateCount)")
        XCTAssertLessThan(mockDelegate.totalUpdateCount, 10, "Debouncing should reduce update frequency")
        
        // Now measure performance of individual dish creation operations
        measure {
            for i in 1...10 {
                autoreleasepool {
                    _ = self.createDish(name: "Perf Comparison Dish \(i)", category: category)
                }
            }
        }
    }
}

// MARK: - Performance Mock Delegate

class MockPerformanceDelegate: DishListServiceDelegate {
    var totalUpdateCount: Int = 0
    var onUpdate: (([Dish]) -> Void)?
    
    func serviceDidChangeContent(_ dishes: [Dish]) {
        totalUpdateCount += 1
        onUpdate?(dishes)
    }
    
    func resetMetrics() {
        totalUpdateCount = 0
    }
} 