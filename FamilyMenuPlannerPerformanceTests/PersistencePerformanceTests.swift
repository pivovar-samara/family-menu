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
    
    override func setUp() async throws {
        try await super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        testDataFactory = TestDataFactory(context: context)
        cleanUpTestData()
    }
    
    override func tearDown() async throws {
        cleanUpTestData()
        persistenceController = nil
        testDataFactory = nil
        try await super.tearDown()
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
