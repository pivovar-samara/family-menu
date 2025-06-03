import XCTest
import CoreData
@testable import FamilyMenuPlanner

class CoreDataPerformanceTests: BaseIntegrationTest {
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
    
    func testFetchPerformance() {
        // Create test data
        let unit = createUnit(name: "pcs", sortOrder: 0)
        for i in 1...100 {
            _ = createProduct(name: "Product \(i)", unit: unit)
        }
        
        let productListService = ProductListService(context: context)
        
        measure {
            _ = productListService.fetchAllProducts()
        }
    }
    
    func testBatchedFetchPerformance() {
        // Create test data
        let unit = createUnit(name: "pcs", sortOrder: 0)
        for i in 1...100 {
            _ = createProduct(name: "Product \(i)", unit: unit)
        }
        
        let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
        CoreDataFetchHelper.configure(fetchRequest, batchSize: 20)
        
        measure {
            do {
                let _ = try context.fetch(fetchRequest)
            } catch {
                XCTFail("Fetch failed: \(error)")
            }
        }
    }
    
    func testDishFetchPerformance() {
        // Create test data
        let category = createDishCategory(name: "Main Course")
        let mealType = createMealType(name: "Dinner")
        for i in 1...50 {
            _ = createDish(name: "Dish \(i)", mealTypes: [mealType], category: category)
        }
        
        let dishService = DishSelectionService(context: context)
        
        measure {
            _ = dishService.fetchAllDishes()
        }
    }
    
    func testSavePerformance() {
        let unit = createUnit(name: "kg")
        
        measure {
            context.performAndWait {
                for i in 1...50 {
                    let product = Product(context: context)
                    product.name = "Bulk Product \(i)"
                    product.unit = unit
                }
                
                do {
                    try context.save()
                } catch {
                    XCTFail("Save failed: \(error)")
                }
            }
        }
        
        // Clean up after test
        cleanUpTestData()
    }
    
    func testContextConfigurationPerformance() {
        measure {
            let backgroundContext = persistenceController.newBackgroundContext()
            
            // Test that context configuration doesn't impact performance
            XCTAssertNotNil(backgroundContext)
            XCTAssertEqual(backgroundContext.concurrencyType, .privateQueueConcurrencyType)
            XCTAssertTrue(backgroundContext.automaticallyMergesChangesFromParent)
            XCTAssertNil(backgroundContext.undoManager)
            XCTAssertTrue(backgroundContext.shouldDeleteInaccessibleFaults)
        }
    }
} 