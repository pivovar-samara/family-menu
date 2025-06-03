//
//  CoreDataFetchHelperTests.swift
//  FamilyMenuPlannerTests
//
//  Created by Assistant on 27.01.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

class CoreDataFetchHelperTests: BaseIntegrationTest {
    
    func testConfigureFetchRequestWithDefaultBatchSize() {
        // Create a fetch request
        let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
        
        // Configure using helper
        CoreDataFetchHelper.configure(fetchRequest)
        
        // Verify configuration
        XCTAssertEqual(fetchRequest.fetchBatchSize, CoreDataFetchHelper.standardBatchSize)
        XCTAssertFalse(fetchRequest.includesSubentities)
        XCTAssertTrue(fetchRequest.returnsObjectsAsFaults)
    }
    
    func testConfigureFetchRequestWithCustomBatchSize() {
        // Create a fetch request
        let fetchRequest: NSFetchRequest<Dish> = Dish.fetchRequest()
        
        // Configure with custom batch size
        CoreDataFetchHelper.configure(fetchRequest, batchSize: CoreDataFetchHelper.largeBatchSize)
        
        // Verify configuration
        XCTAssertEqual(fetchRequest.fetchBatchSize, CoreDataFetchHelper.largeBatchSize)
        XCTAssertFalse(fetchRequest.includesSubentities)
        XCTAssertTrue(fetchRequest.returnsObjectsAsFaults)
    }
    
    func testConfigureFetchRequestWithSubentities() {
        // Create a fetch request
        let fetchRequest: NSFetchRequest<Unit> = Unit.fetchRequest()
        
        // Configure with subentities enabled
        CoreDataFetchHelper.configure(fetchRequest, includesSubentities: true)
        
        // Verify configuration
        XCTAssertEqual(fetchRequest.fetchBatchSize, CoreDataFetchHelper.standardBatchSize)
        XCTAssertTrue(fetchRequest.includesSubentities)
        XCTAssertTrue(fetchRequest.returnsObjectsAsFaults)
    }
    
    func testConfigureForLargeDataset() {
        // Create a fetch request
        let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
        
        // Configure for large dataset
        CoreDataFetchHelper.configureForLargeDataset(fetchRequest)
        
        // Verify configuration
        XCTAssertEqual(fetchRequest.fetchBatchSize, CoreDataFetchHelper.largeBatchSize)
        XCTAssertFalse(fetchRequest.includesSubentities)
        XCTAssertTrue(fetchRequest.returnsObjectsAsFaults)
    }
    
    func testConfigureForSmallList() {
        // Create a fetch request
        let fetchRequest: NSFetchRequest<Unit> = Unit.fetchRequest()
        
        // Configure for small list
        CoreDataFetchHelper.configureForSmallList(fetchRequest)
        
        // Verify configuration
        XCTAssertEqual(fetchRequest.fetchBatchSize, CoreDataFetchHelper.smallBatchSize)
        XCTAssertFalse(fetchRequest.includesSubentities)
        XCTAssertTrue(fetchRequest.returnsObjectsAsFaults)
    }
    
    func testBatchSizeConstants() {
        // Verify batch size constants are reasonable
        XCTAssertEqual(CoreDataFetchHelper.smallBatchSize, 10)
        XCTAssertEqual(CoreDataFetchHelper.standardBatchSize, 20)
        XCTAssertEqual(CoreDataFetchHelper.largeBatchSize, 50)
        
        // Verify they are in logical order
        XCTAssertLessThan(CoreDataFetchHelper.smallBatchSize, CoreDataFetchHelper.standardBatchSize)
        XCTAssertLessThan(CoreDataFetchHelper.standardBatchSize, CoreDataFetchHelper.largeBatchSize)
        
        // Verify all values are positive
        XCTAssertGreaterThan(CoreDataFetchHelper.smallBatchSize, 0)
        XCTAssertGreaterThan(CoreDataFetchHelper.standardBatchSize, 0)
        XCTAssertGreaterThan(CoreDataFetchHelper.largeBatchSize, 0)
    }
    
    func testPerformanceWithBatchedFetch() {
        // Create a unit for products
        let unit = createUnit(name: "pcs", sortOrder: 0)
        
        // Create test data
        for i in 1...100 {
            _ = createProduct(name: "Product \(i)", unit: unit)
        }
        
        // Measure fetch with batch size
        let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
        CoreDataFetchHelper.configure(fetchRequest, batchSize: 20)
        
        self.measure {
            do {
                let _ = try context.fetch(fetchRequest)
            } catch {
                XCTFail("Fetch failed: \(error)")
            }
        }
    }
    
    func testBatchedFetchWithSorting() {
        // Create a unit for products
        let unit = createUnit(name: "pcs", sortOrder: 0)
        
        // Create test data
        let names = ["Zebra Product", "Apple Product", "Banana Product"]
        for name in names {
            _ = createProduct(name: name, unit: unit)
        }
        
        // Configure fetch request with sorting
        let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Product.name, ascending: true)]
        CoreDataFetchHelper.configure(fetchRequest)
        
        do {
            let products = try context.fetch(fetchRequest)
            
            // Verify sorting works with batched fetch
            XCTAssertEqual(products.count, 3)
            XCTAssertEqual(products[0].name, "Apple Product")
            XCTAssertEqual(products[1].name, "Banana Product")
            XCTAssertEqual(products[2].name, "Zebra Product")
        } catch {
            XCTFail("Batched fetch with sorting failed: \(error)")
        }
    }
    
    func testBatchedFetchWithPredicate() {
        // Create a unit for products
        let unit = createUnit(name: "pcs", sortOrder: 0)
        
        // Create test data
        _ = createProduct(name: "Apple", unit: unit)
        _ = createProduct(name: "Banana", unit: unit)
        _ = createProduct(name: "Orange", unit: unit)
        
        // Configure fetch request with predicate
        let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", "a")
        CoreDataFetchHelper.configure(fetchRequest)
        
        do {
            let products = try context.fetch(fetchRequest)
            
            // Verify predicate works with batched fetch
            XCTAssertEqual(products.count, 3) // Apple, Banana, Orange all contain 'a'
            XCTAssertTrue(products.allSatisfy { $0.name?.lowercased().contains("a") == true })
        } catch {
            XCTFail("Batched fetch with predicate failed: \(error)")
        }
    }
    
    func testMultipleEntityTypes() {
        // Test that helper works with different entity types
        let productRequest: NSFetchRequest<Product> = Product.fetchRequest()
        let dishRequest: NSFetchRequest<Dish> = Dish.fetchRequest()
        let unitRequest: NSFetchRequest<Unit> = Unit.fetchRequest()
        
        CoreDataFetchHelper.configure(productRequest)
        CoreDataFetchHelper.configure(dishRequest)
        CoreDataFetchHelper.configure(unitRequest)
        
        // Verify all requests are configured properly
        XCTAssertEqual(productRequest.fetchBatchSize, CoreDataFetchHelper.standardBatchSize)
        XCTAssertEqual(dishRequest.fetchBatchSize, CoreDataFetchHelper.standardBatchSize)
        XCTAssertEqual(unitRequest.fetchBatchSize, CoreDataFetchHelper.standardBatchSize)
    }
} 