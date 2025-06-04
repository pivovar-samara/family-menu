import XCTest
import CoreData
@testable import FamilyMenuPlanner

class ServicePerformanceTests: BaseIntegrationTest {
    
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
        // Test that the test stack loads quickly
        let expectation = XCTestExpectation(description: "Test stack loading completes")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        measure {
            // Test basic operations with the test stack
            let unit = createUnit(name: "test_kg", sortOrder: 1)
            _ = createProduct(name: "Test Product", unit: unit)
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = endTime - startTime
            
            XCTAssertLessThan(duration, 1.0, "Test stack operations should complete quickly")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
} 
