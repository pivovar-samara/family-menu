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
    
    override func setUp() async throws {
        // Use TestCoreDataStack which properly loads the model from the correct bundle
        context = TestCoreDataStack.shared.viewContext
        testDataFactory = TestDataFactory(context: context)
        cleanUpTestData()
    }
    
    override func tearDown() async throws {
        cleanUpTestData()
        testDataFactory = nil
        try await super.tearDown()
    }

    func testInMemoryStoreSkipsQueryGeneration() {
        // Test that in-memory stores (used in tests) don't have query generation
        // This is expected behavior since in-memory stores don't support this feature
        let persistenceContext = TestCoreDataStack.shared.viewContext
        
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
        let backgroundContext = TestCoreDataStack.shared.newBackgroundContext()
        
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
        
        // Set up expectation for delegate callback
        let expectation = XCTestExpectation(description: "Products fetched")
        
        // Mock delegate to capture the results
        class MockDelegate: ProductListServiceDelegate {
            var products: [Product] = []
            var expectation: XCTestExpectation?
            
            func serviceDidChangeContent(_ products: [Product]) {
                self.products = products
                expectation?.fulfill()
            }
        }
        
        let mockDelegate = MockDelegate()
        mockDelegate.expectation = expectation
        productListService.delegate = mockDelegate
        
        // Trigger fetch
        productListService.fetchAllProducts()
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(mockDelegate.products.count, 1)
        XCTAssertEqual(mockDelegate.products.first?.name, "Test Product")
    }
    
    func testContextConfigurationIsProperlyApplied() {
        // Test that all context configurations are applied correctly
        let persistenceContext = TestCoreDataStack.shared.viewContext
        let backgroundContext = TestCoreDataStack.shared.newBackgroundContext()
        
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
    
    func testCoreDataPerformanceWithTestStack() {
        // Test basic Core Data performance with the test stack
        let unit = createUnit(name: "kg", sortOrder: 1)
        
        measure {
            for i in 1...100 {
                _ = createProduct(name: "Performance Product \(i)", unit: unit)
            }
        }
    }
    
    func testContextOperationsPerformance() {
        // Test context operations performance
        let unit = createUnit(name: "pieces", sortOrder: 1)
        
        measure {
            context.performAndWait {
                for i in 1...50 {
                    let product = Product(context: context)
                    product.name = "Batch Product \(i)"
                    product.unit = unit
                }
                try! context.save()
            }
        }
    }
}
