import XCTest
import CoreData
@testable import FamilyMenuPlanner

class ServicePerformanceTests: BaseIntegrationTest {
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
    
    func testProductListServicePerformance() {
        // Create test data
        let unit = createUnit(name: "pcs")
        for i in 1...100 {
            _ = createProduct(name: "Product \(i)", unit: unit)
        }
        
        let service = ProductListService(context: context)
        
        measure {
            _ = service.fetchAllProducts()
        }
    }
    
    func testDishSelectionServicePerformance() {
        // Create test data
        let category = createDishCategory(name: "Main Course")
        let mealType = createMealType(name: "Dinner")
        for i in 1...50 {
            _ = createDish(name: "Dish \(i)", mealTypes: [mealType], category: category)
        }
        
        let service = DishSelectionService(context: context)
        
        measure {
            _ = service.fetchAllDishes()
        }
    }
    
    func testDishDetailsServicePerformance() {
        // Create test data
        _ = createDishCategory(name: "Main Course")
        _ = createMealType(name: "Dinner")
        _ = createUnit(name: "kg")
        
        let service = DishDetailsService(context: context)
        
        measure {
            let _ = service.fetchAllUnits()
            let _ = service.fetchAllMealTypes()
            let _ = service.fetchAllDishCategories()
        }
    }
    
    func testMultipleServiceOperationsPerformance() {
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
        
        measure {
            // All services should work without explicit setQueryGenerationFrom calls
            let _ = productListService.fetchAllProducts()
            let _ = dishDetailsService.fetchAllUnits()
            let _ = dishDetailsService.fetchAllMealTypes()
            let _ = dishDetailsService.fetchAllDishCategories()
            let _ = dishSelectionService.fetchAllDishes()
        }
    }
    
    func testServiceInitializationPerformance() {
        measure {
            let productListService = ProductListService(context: context)
            let dishDetailsService = DishDetailsService(context: context)
            let dishSelectionService = DishSelectionService(context: context)
            
            // Verify services are initialized properly
            XCTAssertNotNil(productListService)
            XCTAssertNotNil(dishDetailsService)
            XCTAssertNotNil(dishSelectionService)
        }
    }
    
    func testAsynchronousStoreLoadingPerformance() {
        // Test that the new asynchronous store loading doesn't block the calling thread
        let expectation = XCTestExpectation(description: "Async store loading completes")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Create a new persistence controller to test initialization
        let testController = PersistenceController(inMemory: true)
        
        measure {
            // Test the new async recovery method
            testController.attemptRecovery { success in
                let endTime = CFAbsoluteTimeGetCurrent()
                let duration = endTime - startTime
                
                XCTAssertTrue(success, "Store loading should succeed")
                XCTAssertLessThan(duration, 1.0, "Async initialization should complete quickly for in-memory stores")
                
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
} 
