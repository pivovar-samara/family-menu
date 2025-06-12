//
//  BackgroundOperationManagerTests.swift
//  FamilyMenuPlannerIntegrationTests
//
//  Created by Assistant on 27.01.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

class BackgroundOperationManagerTests: BaseIntegrationTest {
    var backgroundManager: BackgroundOperationManagerProtocol!
    
    override func setUp() async throws {
        try await super.setUp()
        context = TestCoreDataStack.shared.viewContext
        testDataFactory = TestDataFactory(context: context)
        cleanUpTestData()
        
        // Use test implementation for better control
        backgroundManager = TestBackgroundOperationManager(testStack: TestCoreDataStack.shared)
    }
    
    override func tearDown() async throws {
        cleanUpTestData()
        backgroundManager = nil
        testDataFactory = nil
        try await super.tearDown()
    }
    
    func testExecuteHeavyOperation() {
        let unit = createUnit(name: "kg")
        let unitObjectID = unit.objectID  // Store ObjectID before async operation
        let expectation = expectation(description: "Heavy operation completed")
        
        backgroundManager.executeHeavyOperation { backgroundContext in
            guard let backgroundUnit = try? backgroundContext.existingObject(with: unitObjectID) as? Unit else {
                throw NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unit not found"])
            }
            
            let product = Product(context: backgroundContext)
            product.name = "Background Product"
            product.unit = backgroundUnit
            
            if backgroundContext.hasChanges {
                try backgroundContext.save()
            }
            
            return product.objectID
        } completion: { result in
            switch result {
            case .success(let objectID):
                // Verify product exists in main context
                do {
                    self.context.refreshAllObjects()
                    let mainProduct = try self.context.existingObject(with: objectID) as! Product
                    XCTAssertEqual(mainProduct.name, "Background Product")
                    // Compare using ObjectID since objects are from different contexts
                    XCTAssertEqual(mainProduct.unit?.objectID, unitObjectID)
                    expectation.fulfill()
                } catch {
                    XCTFail("Failed to get product in main context: \(error)")
                }
            case .failure(let error):
                XCTFail("Heavy operation failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testExecuteBatchSaveOperation() {
        // Create test products
        let unit = createUnit(name: "pcs")
        var products: [Product] = []
        for i in 1...5 {
            let product = createProduct(name: "Product \(i)", unit: unit)
            products.append(product)
        }
        
        let objectIDs = products.map { $0.objectID }
        let expectation = expectation(description: "Batch save completed")
        
        backgroundManager.executeBatchSaveOperation(objectIDs: objectIDs) { backgroundObjects in
            // Update all products in background
            for object in backgroundObjects {
                if let product = object as? Product {
                    product.name = "Updated \(product.name ?? "")"
                }
            }
        } completion: { result in
            switch result {
            case .success:
                self.context.refreshAllObjects()
                
                for objectID in objectIDs {
                    do {
                        let product = try self.context.existingObject(with: objectID) as! Product
                        XCTAssertTrue(product.name?.hasPrefix("Updated") == true, "Product name should be updated: \(product.name ?? "")")
                    } catch {
                        XCTFail("Failed to fetch updated product: \(error)")
                    }
                }
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Batch save operation failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testExecuteBulkOperation() {
        let unit = createUnit(name: "kg")
        let unitObjectID = unit.objectID  // Store ObjectID
        let expectation = expectation(description: "Bulk operation completed")
        
        backgroundManager.executeBulkOperation { backgroundContext in
            guard let backgroundUnit = try? backgroundContext.existingObject(with: unitObjectID) as? Unit else {
                throw NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unit not found in background context"])
            }
            
            // Create multiple products in bulk
            for i in 1...10 {
                let product = Product(context: backgroundContext)
                product.name = "Bulk Product \(i)"
                product.unit = backgroundUnit
            }
        } completion: { result in
            switch result {
            case .success:
                self.context.refreshAllObjects()
                
                // Verify products were created
                let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name BEGINSWITH %@", "Bulk Product")
                
                do {
                    let bulkProducts = try self.context.fetch(fetchRequest)
                    XCTAssertEqual(bulkProducts.count, 10, "Should have created 10 bulk products")
                    expectation.fulfill()
                } catch {
                    XCTFail("Failed to fetch bulk products: \(error)")
                }
            case .failure(let error):
                XCTFail("Bulk operation failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testExecuteHeavyFetch() {
        // Create test data
        let unit = createUnit(name: "pcs")
        for i in 1...20 {
            _ = createProduct(name: "Fetch Product \(i)", unit: unit)
        }
        
        let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name BEGINSWITH %@", "Fetch Product")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Product.name, ascending: true)]
        
        let expectation = expectation(description: "Heavy fetch completed")
        
        backgroundManager.executeHeavyFetch(
            fetchRequest: fetchRequest,
            transform: { $0 },
            completion: { (result: Result<[Product], Error>) in
                switch result {
                case .success(let products):
                    XCTAssertEqual(products.count, 20, "Should have fetched 20 products")
                    
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail("Heavy fetch failed: \(error)")
                }
            }
        )
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testExecuteHeavyFetchWithTransform() {
        // Create test data
        let unit = createUnit(name: "kg")
        for i in 1...15 {
            _ = createProduct(name: "Transform Product \(i)", unit: unit)
        }
        
        let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name BEGINSWITH %@", "Transform Product")
        
        let expectation = expectation(description: "Heavy fetch with transform completed")
        
        backgroundManager.executeHeavyFetch(
            fetchRequest: fetchRequest,
            transform: { products in
                products.compactMap { $0.name }
            }
        ) { (result: Result<[String], Error>) in
            switch result {
            case .success(let productNames):
                XCTAssertEqual(productNames.count, 15, "Should have 15 product names")
                
                // Verify all names start with "Transform Product"
                for name in productNames {
                    XCTAssertTrue(name.hasPrefix("Transform Product"), "All names should start with 'Transform Product'")
                }
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Heavy fetch with transform failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testExecuteTransaction() {
        let unit = createUnit(name: "pcs")
        let unitObjectID = unit.objectID  // Store ObjectID
        let expectation = expectation(description: "Transaction completed")
        
        let operations: [(NSManagedObjectContext) throws -> Void] = [
            { backgroundContext in
                // Operation 1: Create products
                guard let backgroundUnit = try? backgroundContext.existingObject(with: unitObjectID) as? Unit else {
                    throw NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unit not found"])
                }
                
                for i in 1...5 {
                    let product = Product(context: backgroundContext)
                    product.name = "Transaction Product \(i)"
                    product.unit = backgroundUnit
                }
            },
            { backgroundContext in
                // Operation 2: Create a dish category
                let category = DishCategory(context: backgroundContext)
                category.name = "Transaction Category"
                category.sortOrder = 1
            },
            { backgroundContext in
                // Operation 3: Create a meal type
                let mealType = MealType(context: backgroundContext)
                mealType.name = "Transaction Meal"
                mealType.sortOrder = 1
            }
        ]
        
        backgroundManager.executeTransaction(operations: operations) { result in
            switch result {
            case .success:
                self.context.refreshAllObjects()
                
                // Verify all operations completed
                let productFetch: NSFetchRequest<Product> = Product.fetchRequest()
                productFetch.predicate = NSPredicate(format: "name BEGINSWITH %@", "Transaction Product")
                
                let categoryFetch: NSFetchRequest<DishCategory> = DishCategory.fetchRequest()
                categoryFetch.predicate = NSPredicate(format: "name == %@", "Transaction Category")
                
                let mealTypeFetch: NSFetchRequest<MealType> = MealType.fetchRequest()
                mealTypeFetch.predicate = NSPredicate(format: "name == %@", "Transaction Meal")
                
                do {
                    let products = try self.context.fetch(productFetch)
                    let categories = try self.context.fetch(categoryFetch)
                    let mealTypes = try self.context.fetch(mealTypeFetch)
                    
                    XCTAssertEqual(products.count, 5, "Should have created 5 products")
                    XCTAssertEqual(categories.count, 1, "Should have created 1 category")
                    XCTAssertEqual(mealTypes.count, 1, "Should have created 1 meal type")
                    
                    expectation.fulfill()
                } catch {
                    XCTFail("Failed to verify transaction results: \(error)")
                }
            case .failure(let error):
                XCTFail("Transaction failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testErrorHandling() {
        let expectation = expectation(description: "Error handling")
        
        backgroundManager.executeHeavyOperation { backgroundContext in
            // Intentionally cause an error
            throw NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Intentional test error"])
        } completion: { result in
            switch result {
            case .success:
                XCTFail("Operation should have failed")
            case .failure(let error):
                XCTAssertEqual((error as NSError).domain, "TestError")
                XCTAssertEqual((error as NSError).code, -1)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}

// MARK: - Test Implementation of BackgroundOperationManager
class TestBackgroundOperationManager: BackgroundOperationManagerProtocol {
    private let testStack: TestCoreDataStack
    private let backgroundQueue = DispatchQueue(label: "com.familymenuplanner.test.background", qos: .utility)
    
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
        transform: @escaping ([T]) -> R = { $0 },
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
