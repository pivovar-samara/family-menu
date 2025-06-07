//
//  BackgroundOperationManagerUnitTests.swift
//  FamilyMenuPlannerTests
//
//  Created by Critical Test Review on 28.01.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

enum TestError: Error {
    case testError
}

enum TransactionTestError: Error {
    case testError
}

// MARK: - Test Implementation of BackgroundOperationManager for Unit Tests
class TestBackgroundOperationManagerForUnitTests: BackgroundOperationManagerProtocol {
    private let testStack: TestCoreDataStack
    private let backgroundQueue = DispatchQueue(label: "com.familymenuplanner.unittest.background", qos: .utility)
    
    init(testStack: TestCoreDataStack) {
        self.testStack = testStack
    }
    
    func executeHeavyOperation<T>(
        operation: @escaping (NSManagedObjectContext) throws -> T,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        backgroundQueue.async {
            let backgroundContext = self.testStack.newBackgroundContext()
            
            do {
                let result = try backgroundContext.performAndWait {
                    try operation(backgroundContext)
                }
                
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func executeBatchSaveOperation(
        objectIDs: [NSManagedObjectID],
        operation: @escaping ([NSManagedObject]) throws -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        backgroundQueue.async {
            let backgroundContext = self.testStack.newBackgroundContext()
            
            do {
                try backgroundContext.performAndWait {
                    let backgroundObjects = objectIDs.compactMap { objectID in
                        try? backgroundContext.existingObject(with: objectID)
                    }
                    
                    try operation(backgroundObjects)
                    
                    if backgroundContext.hasChanges {
                        try backgroundContext.save()
                    }
                }
                
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func executeBulkOperation(
        operation: @escaping (NSManagedObjectContext) throws -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        backgroundQueue.async {
            let backgroundContext = self.testStack.newBackgroundContext()
            
            do {
                try backgroundContext.performAndWait {
                    try operation(backgroundContext)
                    
                    if backgroundContext.hasChanges {
                        try backgroundContext.save()
                    }
                }
                
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func executeHeavyFetch<T: NSManagedObject, R>(
        fetchRequest: NSFetchRequest<T>,
        transform: @escaping ([T]) -> R,
        completion: @escaping (Result<R, Error>) -> Void
    ) {
        backgroundQueue.async {
            let backgroundContext = self.testStack.newBackgroundContext()
            
            do {
                let results = try backgroundContext.performAndWait {
                    try backgroundContext.fetch(fetchRequest)
                }
                
                let transformed = transform(results)
                
                DispatchQueue.main.async {
                    completion(.success(transformed))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func executeTransaction(
        operations: [(NSManagedObjectContext) throws -> Void],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        backgroundQueue.async {
            let backgroundContext = self.testStack.newBackgroundContext()
            
            do {
                try backgroundContext.performAndWait {
                    for operation in operations {
                        try operation(backgroundContext)
                    }
                    
                    if backgroundContext.hasChanges {
                        try backgroundContext.save()
                    }
                }
                
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}

class BackgroundOperationManagerUnitTests: XCTestCase {
    var backgroundManager: BackgroundOperationManagerProtocol!
    var testStack: TestCoreDataStack!
    var context: NSManagedObjectContext!
    var testDataFactory: TestDataFactory!
    
    override func setUp() {
        super.setUp()
        testStack = TestCoreDataStack.shared
        context = testStack.viewContext
        testDataFactory = TestDataFactory(context: context)
        
        // Use test implementation that shares the same CoreData stack
        backgroundManager = TestBackgroundOperationManagerForUnitTests(testStack: testStack)
        
        // Clean slate for each test
        cleanUpTestData()
    }
    
    override func tearDown() {
        cleanUpTestData()
        backgroundManager = nil
        testDataFactory = nil
        context = nil
        testStack = nil
        super.tearDown()
    }
    
    private func cleanUpTestData() {
        testDataFactory?.cleanUpTestData()
    }
    
    // MARK: - Test executeHeavyOperation
    
    func testExecuteHeavyOperationSuccess() {
        let expectation = expectation(description: "Heavy operation completed")
        
        backgroundManager.executeHeavyOperation { backgroundContext in
            // Create test unit in background context
            let unit = Unit(context: backgroundContext)
            unit.name = "Test Unit"
            unit.sortOrder = 1
            
            // Save the unit
            if backgroundContext.hasChanges {
                try backgroundContext.save()
            }
        } completion: { result in
            switch result {
            case .success:
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Operation should succeed: \(error)")
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testExecuteHeavyOperationFailure() {
        let expectation = expectation(description: "Heavy operation completed")
        
        backgroundManager.executeHeavyOperation { backgroundContext in
            // Intentionally throw an error
            throw TestError.testError
        } completion: { result in
            switch result {
            case .success:
                XCTFail("Operation should fail")
                expectation.fulfill()
            case .failure:
                // Expected failure
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    // MARK: - Test executeBatchSaveOperation
    
    func testExecuteBatchSaveOperationSuccess() {
        // Create test units in main context first
        let unit1 = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        let unit2 = testDataFactory.createUnit(name: "pcs", sortOrder: 2)
        
        let objectIDs = [unit1.objectID, unit2.objectID]
        let expectation = expectation(description: "Batch save completed")
        
        backgroundManager.executeBatchSaveOperation(objectIDs: objectIDs) { backgroundObjects in
            // Modify the objects in background context
            for (index, object) in backgroundObjects.enumerated() {
                if let unit = object as? Unit {
                    unit.sortOrder = Int16(index + 10) // Change sort order
                }
            }
        } completion: { result in
            switch result {
            case .success:
                // Verify changes were saved
                self.context.refreshAllObjects()
                let updatedUnit1 = self.context.object(with: unit1.objectID) as! Unit
                XCTAssertEqual(updatedUnit1.sortOrder, 10, "First unit should have sortOrder 10")
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Batch save should succeed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testExecuteBatchSaveOperationWithEmptyArray() {
        let expectation = expectation(description: "Batch save with empty array")
        
        backgroundManager.executeBatchSaveOperation(objectIDs: []) { backgroundObjects in
            // Should receive empty array
            XCTAssertTrue(backgroundObjects.isEmpty, "Should have no valid objects")
        } completion: { result in
            switch result {
            case .success:
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Should handle empty array gracefully: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Test executeBulkOperation
    
    func testExecuteBulkOperationSuccess() {
        let expectation = expectation(description: "Bulk operation completed")
        
        backgroundManager.executeBulkOperation { backgroundContext in
            // Create multiple units in one operation
            for i in 1...10 {
                let unit = Unit(context: backgroundContext)
                unit.name = "Bulk Unit \(i)"
                unit.sortOrder = Int16(i)
            }
            
            // Save operation
            if backgroundContext.hasChanges {
                try backgroundContext.save()
            }
        } completion: { result in
            switch result {
            case .success:
                // Verify units were created in main context
                self.context.refreshAllObjects()
                let fetchRequest: NSFetchRequest<Unit> = Unit.fetchRequest()
                do {
                    let units = try self.context.fetch(fetchRequest)
                    let bulkUnits = units.filter { $0.name?.hasPrefix("Bulk Unit") == true }
                    XCTAssertEqual(bulkUnits.count, 10, "Should have created 10 bulk units")
                } catch {
                    XCTFail("Failed to fetch units: \(error)")
                }
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Bulk operation should succeed: \(error)")
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testExecuteBulkOperationFailure() {
        let expectation = expectation(description: "Bulk operation completed")
        
        backgroundManager.executeBulkOperation { backgroundContext in
            // Create a unit but then throw an error
            let unit = Unit(context: backgroundContext)
            unit.name = "Should Not Be Saved"
            unit.sortOrder = 1
            
            throw TestError.testError
        } completion: { result in
            switch result {
            case .success:
                XCTFail("Operation should fail")
                expectation.fulfill()
            case .failure:
                // Verify no units were saved
                let fetchRequest: NSFetchRequest<Unit> = Unit.fetchRequest()
                do {
                    let units = try self.context.fetch(fetchRequest)
                    let testUnits = units.filter { $0.name == "Should Not Be Saved" }
                    XCTAssertEqual(testUnits.count, 0, "Failed operation should not save units")
                } catch {
                    XCTFail("Failed to fetch units: \(error)")
                }
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    // MARK: - Test executeHeavyFetch
    
    func testExecuteHeavyFetch() {
        // Create test data in main context
        _ = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        _ = testDataFactory.createUnit(name: "pcs", sortOrder: 2)
        
        let fetchRequest: NSFetchRequest<Unit> = Unit.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Unit.sortOrder, ascending: true)]
        
        let expectation = expectation(description: "Heavy fetch completed")
        
        backgroundManager.executeHeavyFetch(
            fetchRequest: fetchRequest,
            transform: { units in
                return units.compactMap { $0.name }
            }
        ) { (result: Result<[String], Error>) in
            switch result {
            case .success(let names):
                XCTAssertEqual(names.count, 2, "Should fetch 2 units")
                XCTAssertEqual(names.first, "kg")
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Fetch should succeed: \(error)")
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    // MARK: - Test executeTransaction
    
    func testExecuteTransactionSuccess() {
        let expectation = expectation(description: "Transaction completed")
        
        let operations: [(NSManagedObjectContext) throws -> Void] = [
            { backgroundContext in
                // Create unit in transaction
                let unit = Unit(context: backgroundContext)
                unit.name = "Transaction Unit"
                unit.sortOrder = 1
            }
        ]
        
        backgroundManager.executeTransaction(operations: operations) { result in
            switch result {
            case .success:
                // Verify unit exists in main context
                self.context.refreshAllObjects()
                let fetchRequest: NSFetchRequest<Unit> = Unit.fetchRequest()
                do {
                    let units = try self.context.fetch(fetchRequest)
                    let transactionUnits = units.filter { $0.name == "Transaction Unit" }
                    XCTAssertEqual(transactionUnits.count, 1, "Transaction should have saved unit")
                } catch {
                    XCTFail("Failed to fetch units: \(error)")
                }
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Transaction should succeed: \(error)")
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testExecuteTransactionFailure() {
        let expectation = expectation(description: "Transaction completed")
        
        let operations: [(NSManagedObjectContext) throws -> Void] = [
            { backgroundContext in
                // Create unit but then fail
                let unit = Unit(context: backgroundContext)
                unit.name = "Failed Transaction Unit"
                unit.sortOrder = 1
                
                throw TransactionTestError.testError
            }
        ]
        
        backgroundManager.executeTransaction(operations: operations) { result in
            switch result {
            case .success:
                XCTFail("Transaction should fail")
                expectation.fulfill()
            case .failure:
                // Verify no unit was saved
                let fetchRequest: NSFetchRequest<Unit> = Unit.fetchRequest()
                do {
                    let units = try self.context.fetch(fetchRequest)
                    let failedUnits = units.filter { $0.name == "Failed Transaction Unit" }
                    XCTAssertEqual(failedUnits.count, 0, "Failed transaction should not save unit")
                } catch {
                    XCTFail("Failed to fetch units: \(error)")
                }
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    // MARK: - Test Error Handling
    
    func testBackgroundOperationErrorTypes() {
        // Test error descriptions
        XCTAssertNotNil(BackgroundOperationError.managerDeallocated.errorDescription)
        XCTAssertNotNil(BackgroundOperationError.contextNotAvailable.errorDescription)
        XCTAssertNotNil(BackgroundOperationError.operationCancelled.errorDescription)
        
        // Verify error descriptions contain meaningful text
        XCTAssertTrue(BackgroundOperationError.managerDeallocated.errorDescription!.contains("deallocated"))
        XCTAssertTrue(BackgroundOperationError.contextNotAvailable.errorDescription!.contains("context"))
        XCTAssertTrue(BackgroundOperationError.operationCancelled.errorDescription!.contains("cancelled"))
    }
} 