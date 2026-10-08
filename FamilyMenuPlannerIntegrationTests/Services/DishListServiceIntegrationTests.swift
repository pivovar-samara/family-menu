//
//  DishListServiceIntegrationTests.swift
//  FamilyMenuPlannerIntegrationTests
//
//  Created by Performance Optimization on 28.01.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

class DishListServiceIntegrationTests: BaseIntegrationTest {
    var dishListService: DishListService!
    var mockDelegate: MockDishListServiceDelegate!
    var testBackgroundManager: TestBackgroundOperationManager!
    
    override func setUp() {
        super.setUp()
        // Create test background manager using the same test stack
        testBackgroundManager = TestBackgroundOperationManager(testStack: TestCoreDataStack.shared)
        
        // Use faster debounce interval for tests (10ms instead of 100ms)
        dishListService = DishListService(
            context: context,
            debounceInterval: 0.01,
            backgroundOperationManager: testBackgroundManager
        )
        mockDelegate = MockDishListServiceDelegate()
        dishListService.delegate = mockDelegate
    }
    
    override func tearDown() {
        mockDelegate = nil
        dishListService = nil
        testBackgroundManager = nil
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testFetchAllDishes() {
        // Create test dishes
        let category = createDishCategory(name: "Test Category")
        _ = createDish(name: "Pasta", category: category)
        _ = createDish(name: "Pizza", category: category)
        
        // Fetch dishes
        dishListService.fetchAllDishes()
        
        // Verify delegate was called with correct data
        XCTAssertEqual(mockDelegate.receivedDishes.count, 2)
        XCTAssertTrue(mockDelegate.receivedDishes.contains { $0.name == "Pasta" })
        XCTAssertTrue(mockDelegate.receivedDishes.contains { $0.name == "Pizza" })
    }
    
    func testDeleteDishes() {
        // Create test dishes
        let category = createDishCategory(name: "Test Category")
        let dish1 = createDish(name: "Dish1", category: category)
        let dish2 = createDish(name: "Dish2", category: category)
        let dish3 = createDish(name: "Dish3", category: category)
        
        // Delete one dish
        do {
            try dishListService.deleteDishes(dishes: [dish2])
        } catch {
            XCTFail("Delete operation failed: \(error)")
        }
        
        // Verify deletion
        let fetchRequest: NSFetchRequest<Dish> = Dish.fetchRequest()
        let remainingDishes = try! context.fetch(fetchRequest)
        
        XCTAssertEqual(remainingDishes.count, 2)
        XCTAssertTrue(remainingDishes.contains(dish1))
        XCTAssertTrue(remainingDishes.contains(dish3))
        XCTAssertFalse(remainingDishes.contains(dish2))
    }
    
    // MARK: - Performance Optimization Integration Tests
    
    func testDebouncingPreventsExcessiveUpdates() {
        // Setup expectation for single update
        let updateExpectation = expectation(description: "Debounced update")
        var hasBeenFulfilled = false
        
        mockDelegate.onUpdate = { dishes in
            if !hasBeenFulfilled {
                hasBeenFulfilled = true
                updateExpectation.fulfill()
            }
        }
        
        // Perform initial fetch to establish baseline
        dishListService.fetchAllDishes()
        mockDelegate.resetCallCount()
        
        let category = createDishCategory(name: "Rapid Test Category")
        
        // Rapidly create multiple dishes to trigger multiple NSFetchedResultsController updates
        context.performAndWait {
            for i in 1...5 {
                _ = self.createDish(name: "Rapid Dish \(i)", category: category)
            }
        }
        
        // Wait for debounced update
        wait(for: [updateExpectation], timeout: 0.5)
        
        // Give a bit more time to ensure no additional updates
        let noAdditionalUpdatesExpectation = expectation(description: "No additional updates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            noAdditionalUpdatesExpectation.fulfill()
        }
        wait(for: [noAdditionalUpdatesExpectation], timeout: 0.3)
        
        // Verify only one debounced update occurred
        XCTAssertEqual(mockDelegate.callCount, 1, "Expected only one debounced update, but got \(mockDelegate.callCount)")
        XCTAssertEqual(mockDelegate.receivedDishes.count, 5, "Should have received all 5 dishes in single update")
    }
    
    func testDebouncingWithMultipleBatches() {
        let firstBatchExpectation = expectation(description: "First batch update")
        let secondBatchExpectation = expectation(description: "Second batch update")
        
        var firstBatchFulfilled = false
        var secondBatchFulfilled = false
        
        mockDelegate.onUpdate = { dishes in
            // Use the delegate's call count to determine which batch this is
            if self.mockDelegate.callCount == 1 && !firstBatchFulfilled {
                firstBatchFulfilled = true
                firstBatchExpectation.fulfill()
            } else if self.mockDelegate.callCount == 2 && !secondBatchFulfilled {
                secondBatchFulfilled = true
                secondBatchExpectation.fulfill()
            }
        }
        
        // Initial fetch
        dishListService.fetchAllDishes()
        mockDelegate.resetCallCount()
        
        let category = createDishCategory(name: "Batch Test Category")
        
        // First batch of rapid changes
        context.performAndWait {
            for i in 1...3 {
                _ = self.createDish(name: "Batch1 Dish \(i)", category: category)
            }
        }
        
        // Wait for first debounced update to complete
        wait(for: [firstBatchExpectation], timeout: 0.5)
        
        // Wait significantly longer than debounce interval to ensure first batch is fully processed
        let delayExpectation = expectation(description: "Delay between batches")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            delayExpectation.fulfill()
        }
        wait(for: [delayExpectation], timeout: 0.5)
        
        // Second batch of changes (should trigger separate update)
        context.performAndWait {
            for i in 1...2 {
                _ = self.createDish(name: "Batch2 Dish \(i)", category: category)
            }
        }
        
        // Wait for second debounced update
        wait(for: [secondBatchExpectation], timeout: 0.5)
        
        // Verify two separate updates occurred
        XCTAssertEqual(mockDelegate.callCount, 2, "Expected two separate debounced updates")
        XCTAssertEqual(mockDelegate.receivedDishes.count, 5, "Should have received all 5 dishes in final update")
    }
    
    func testDebounceTimerCleanupOnDeinit() {
        let category = createDishCategory(name: "Timer Test Category")
        
        // Create service in limited scope with faster debounce for testing
        var service: DishListService? = DishListService(context: context, debounceInterval: 0.01)
        weak let weakService = service
        
        // Trigger timer creation
        _ = createDish(name: "Timer Test Dish", category: category)
        
        // Deallocate service
        service = nil
        
        // Verify service is deallocated (timer cleanup worked)
        XCTAssertNil(weakService, "Service should be deallocated, indicating timer was properly cleaned up")
    }
    
    func testImmediateUpdateAfterDirectFetch() {
        let updateExpectation = expectation(description: "Immediate update after fetch")
        mockDelegate.onUpdate = { dishes in
            updateExpectation.fulfill()
        }
        
        // Create test data
        let category = createDishCategory(name: "Direct Fetch Category")
        _ = createDish(name: "Direct Fetch Test", category: category)
        
        // Direct fetch should trigger immediate update, not debounced
        dishListService.fetchAllDishes()
        
        // Should complete immediately
        wait(for: [updateExpectation], timeout: 0.1)
        
        XCTAssertEqual(mockDelegate.callCount, 1)
        XCTAssertEqual(mockDelegate.receivedDishes.count, 1)
    }
    
    func testDebouncingMechanismDirectly() {
        // Test the debouncing mechanism by creating multiple dishes individually
        let debouncedExpectation = expectation(description: "Debounced mechanism")
        var updateCount = 0
        
        mockDelegate.onUpdate = { dishes in
            updateCount += 1
            print("Debounce test update #\(updateCount): received \(dishes.count) dishes")
            
            if dishes.count == 5 {
                debouncedExpectation.fulfill()
            }
        }
        
        // Initial fetch
        dishListService.fetchAllDishes()
        mockDelegate.resetCallCount()
        updateCount = 0
        
        let category = createDishCategory(name: "Debounce Test Category")
        
        // Create dishes individually using the helper method (which saves context each time)
        for i in 1...5 {
            _ = createDish(name: "Debounce Test Dish \(i)", category: category)
        }
        
        // Wait for debounced update
        wait(for: [debouncedExpectation], timeout: 1.0)
        
        print("Debounce test final state: mockDelegate.callCount = \(mockDelegate.callCount), updateCount = \(updateCount)")
        
        // Verify debouncing worked - should have fewer updates than dish creations
        XCTAssertLessThanOrEqual(mockDelegate.callCount, 3, "Should have at most 3 debounced updates for 5 rapid changes, got \(mockDelegate.callCount)")
        XCTAssertEqual(mockDelegate.receivedDishes.count, 5, "Should have received all 5 dishes in final update")
    }
    
    func testDebouncingWithRapidChanges() {
        // Test that simulates rapid data changes triggering debounced updates
        let rapidChangesExpectation = expectation(description: "Rapid changes debounced")
        var updateCount = 0
        var receivedDishCounts: [Int] = []
        
        mockDelegate.onUpdate = { dishes in
            updateCount += 1
            receivedDishCounts.append(dishes.count)
            print("Update #\(updateCount): received \(dishes.count) dishes")
            
            // Only fulfill when we have received the final update with all dishes
            if dishes.count == 10 {
                rapidChangesExpectation.fulfill()
            }
        }
        
        // Initial fetch
        dishListService.fetchAllDishes()
        mockDelegate.resetCallCount()
        updateCount = 0
        receivedDishCounts = []
        
        let category = createDishCategory(name: "Rapid Changes Category")
        
        // Create dishes rapidly using the helper method (each creates and saves individually)
        for i in 1...10 {
            _ = createDish(name: "Rapid Change Dish \(i)", category: category)
        }
        
        // Wait for debounced update
        wait(for: [rapidChangesExpectation], timeout: 2.0)
        
        print("Final state: mockDelegate.callCount = \(mockDelegate.callCount), updateCount = \(updateCount)")
        print("Dish counts received in updates: \(receivedDishCounts)")
        
        // Verify debouncing worked - should have fewer updates than dish creations
        XCTAssertLessThanOrEqual(mockDelegate.callCount, 3, "Should have at most 3 debounced updates for 10 rapid changes, got \(mockDelegate.callCount)")
        XCTAssertEqual(mockDelegate.receivedDishes.count, 10, "Should have received all 10 dishes in final update")
    }
}

// MARK: - Mock Delegate

class MockDishListServiceDelegate: DishListServiceDelegate {
    var receivedDishes: [Dish] = []
    var callCount: Int = 0
    var onUpdate: (([Dish]) -> Void)?
    
    func serviceDidChangeContent(_ dishes: [Dish]) {
        receivedDishes = dishes
        callCount += 1
        onUpdate?(dishes)
    }
    
    func resetCallCount() {
        callCount = 0
    }
} 
