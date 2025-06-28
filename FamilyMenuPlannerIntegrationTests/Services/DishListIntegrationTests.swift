import XCTest
import CoreData
@testable import FamilyMenuPlanner

class DishListIntegrationTests: BaseIntegrationTest {
    var dishListService: DishListService!
    var viewModel: DishListViewModel!
    
    override func setUp() {
        super.setUp()
        dishListService = DishListService(context: context)
        viewModel = DishListViewModel(dishListService: dishListService)
    }
    
    override func tearDown() {
        dishListService = nil
        viewModel = nil
        super.tearDown()
    }
    
    // Helper method to create test data
    private func createTestDishes() -> [Dish] {
        // Create categories
        let mainCourseCategory = DishCategory(context: context)
        mainCourseCategory.name = "Main Course"
        mainCourseCategory.sortOrder = 1
        
        let garnishCategory = DishCategory(context: context)
        garnishCategory.name = "Garnish"
        garnishCategory.sortOrder = 2
        
        // Create dishes
        let dish1 = Dish(context: context)
        dish1.name = "Spaghetti Carbonara"
        dish1.details = "Classic Italian pasta dish"
        dish1.category = mainCourseCategory
        dish1.isDraft = false  // Mark as complete for tests
        
        let dish2 = Dish(context: context)
        dish2.name = "Caesar Salad"
        dish2.details = "Fresh salad with croutons"
        dish2.category = garnishCategory
        dish2.isDraft = false  // Mark as complete for tests
        
        try? context.save()
        context.refreshAllObjects()
        return [dish1, dish2]
    }
    
    // MARK: - Tests
    
    func testLoadDishes() {
        let dishes = createTestDishes()
        
        // Load dishes
        viewModel.loadDishes()
        
        // Wait for async operation to complete
        let exp = expectation(description: "Loading dishes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Verify dishes are loaded
            XCTAssertEqual(self.viewModel.filteredDishes.count, 2)
            XCTAssertTrue(self.viewModel.filteredDishes.contains { $0.name == dishes[0].name })
            XCTAssertTrue(self.viewModel.filteredDishes.contains { $0.name == dishes[1].name })
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 1.0)
    }
    
    func testDeleteDish() {
        // Create and save test dishes
        let dishes = createTestDishes()
        let firstDishName = dishes[0].name ?? ""
        let secondDishName = dishes[1].name ?? ""
        
        // Create expectations
        let loadExp = expectation(description: "Loading dishes")
        let deleteExp = expectation(description: "Deleting dish")
        
        // Load dishes and wait for the delegate callback
        viewModel.loadDishes()
        
        // Wait for initial load
        var initialLoadCompleted = false
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if self.viewModel.filteredDishes.count == 2 && !initialLoadCompleted {
                initialLoadCompleted = true
                
                // Verify initial state
                XCTAssertEqual(self.viewModel.filteredDishes.count, 2)
                XCTAssertTrue(self.viewModel.filteredDishes.contains { $0.name == firstDishName })
                XCTAssertTrue(self.viewModel.filteredDishes.contains { $0.name == secondDishName })
                
                loadExp.fulfill()
                timer.invalidate()
                
                // Now perform the deletion
                DispatchQueue.main.async {
                    // Get the index of the first dish in the current array
                    if let indexToDelete = self.viewModel.filteredDishes.firstIndex(where: { $0.name == firstDishName }) {
                        self.viewModel.deleteDishes(at: IndexSet(integer: indexToDelete))
                        
                        // Wait for the FetchedResultsController to update the dishes array
                        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                            if self.viewModel.filteredDishes.count == 1 {
                                timer.invalidate()
                                
                                // Verify the correct dish was deleted
                                XCTAssertEqual(self.viewModel.filteredDishes.count, 1)
                                XCTAssertFalse(self.viewModel.filteredDishes.contains { $0.name == firstDishName })
                                XCTAssertTrue(self.viewModel.filteredDishes.contains { $0.name == secondDishName })
                                
                                deleteExp.fulfill()
                            }
                        }
                    } else {
                        XCTFail("Could not find dish to delete")
                    }
                }
            }
        }
        
        wait(for: [loadExp, deleteExp], timeout: 3.0)
    }
    
    func testBulkOperations() {
        // First clean up any existing data
        cleanUpTestData()
        
        // Create multiple dishes
        let dishNames = ["Dish1", "Dish2", "Dish3", "Dish4", "Dish5"]
        
        for name in dishNames {
            let dish = Dish(context: context)
            dish.name = name
            dish.details = "Details for \(name)"
            dish.isDraft = false  // Mark as complete for tests
        }
        
        try? context.save()
        context.refreshAllObjects()
        
        // Create expectations
        let loadExp = expectation(description: "Loading dishes")
        let deleteExp = expectation(description: "Deleting dishes")
        
        // Load initial state
        viewModel.loadDishes()
        
        var initialLoadCompleted = false
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if self.viewModel.filteredDishes.count == 5 && !initialLoadCompleted {
                initialLoadCompleted = true
                loadExp.fulfill()
                timer.invalidate()
                
                // Now perform the deletion
                DispatchQueue.main.async {
                    self.viewModel.deleteDishes(at: IndexSet(0..<3))
                    
                    // Wait for the FetchedResultsController to update
                    Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                        if self.viewModel.filteredDishes.count == 2 {
                            timer.invalidate()
                            XCTAssertEqual(self.viewModel.filteredDishes.count, 2)
                            deleteExp.fulfill()
                        }
                    }
                }
            }
        }
        
        wait(for: [loadExp, deleteExp], timeout: 3.0)
    }
    
    func testDishListPersistence() {
        // Create a dish
        let dish = Dish(context: context)
        dish.name = "Persistent Dish"
        dish.details = "This dish should persist"
        dish.isDraft = false  // Mark as complete for tests
        try? context.save()
        
        // Create new view model instance
        let newViewModel = DishListViewModel(dishListService: DishListService(context: context))
        
        // Load dishes in new view model
        newViewModel.loadDishes()
        
        // Wait for loading
        let exp = expectation(description: "Loading dishes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Verify dish exists in new view model
            XCTAssertTrue(newViewModel.filteredDishes.contains { $0.name == "Persistent Dish" })
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 1.0)
    }
    
    func testEmptyDishList() {
        // Clean up any existing data
        cleanUpTestData()
        
        // Load dishes
        viewModel.loadDishes()
        
        // Wait for loading
        let exp = expectation(description: "Loading empty dish list")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Verify list is empty
            XCTAssertTrue(self.viewModel.filteredDishes.isEmpty)
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 1.0)
    }
} 