//
//  DishSelectionIntegrationTests.swift
//  FamilyMenuPlannerUnitTests
//
//  Created by Pivovar 63 on 27.05.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

class DishSelectionIntegrationTests: BaseIntegrationTest {
    var dishSelectionService: DishSelectionService!
    var viewModel: DishSelectionViewModel!
    
    override func setUp() {
        super.setUp()
        dishSelectionService = DishSelectionService(context: context)
    }
    
    override func tearDown() {
        dishSelectionService = nil
        viewModel = nil
        super.tearDown()
    }
    
    // Helper method to create a dish with complete relationships
    private func createDishWithMealTypes(name: String, details: String? = nil, mealTypeNames: [String] = []) -> Dish {
        let mealTypes = Set(mealTypeNames.map { createOrFetchMealType(name: $0) })
        return createDish(name: name, details: details, mealTypes: mealTypes)
    }
    
    // Helper method to create or fetch a meal type
    private func createOrFetchMealType(name: String) -> MealType {
        let fetchRequest: NSFetchRequest<MealType> = MealType.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", name)
        
        if let existingMealType = try? context.fetch(fetchRequest).first {
            return existingMealType
        }
        
        return createMealType(name: name)
    }
    
    func testFetchAllDishesWithRealCoreData() {
        // Create test dishes with relationships
        let dish1 = createDishWithMealTypes(name: "Omelette", details: "Classic breakfast", mealTypeNames: ["Breakfast"])
        let dish2 = createDishWithMealTypes(name: "Soup", details: "Hot lunch", mealTypeNames: ["Lunch"])
        
        // Test fetching
        let fetchedDishes = dishSelectionService.fetchAllDishes()
        XCTAssertEqual(fetchedDishes.count, 2)
        XCTAssertTrue(fetchedDishes.contains(dish1))
        XCTAssertTrue(fetchedDishes.contains(dish2))
    }

    // MARK: - Draft Filtering Tests

    func testServiceFetchAllDishesExcludesDrafts() {
        // Create a complete dish
        let completeDish = createDishWithMealTypes(name: "Complete Dish", mealTypeNames: ["Dinner"])

        // Create a draft dish
        let draftDish = createDishWithMealTypes(name: "Draft Dish", mealTypeNames: ["Dinner"])
        draftDish.isDraft = true
        try? context.save()

        // Fetch dishes using service
        let fetchedDishes = dishSelectionService.fetchAllDishes()

        // Verify only the non-draft dish is returned
        XCTAssertTrue(fetchedDishes.contains(completeDish))
        XCTAssertFalse(fetchedDishes.contains(draftDish))
        XCTAssertEqual(fetchedDishes.count, 1)
    }
    
    func testCoreDataRelationships() {
        // Create dishes with shared meal type
        let breakfast = createOrFetchMealType(name: "Breakfast")
        let dish1 = createDishWithMealTypes(name: "Pancakes", mealTypeNames: ["Breakfast"])
        let dish2 = createDishWithMealTypes(name: "Waffles", mealTypeNames: ["Breakfast"])
        
        // Verify relationships
        XCTAssertEqual(breakfast.dishes?.count, 2)
        XCTAssertTrue(breakfast.dishes?.contains(dish1) ?? false)
        XCTAssertTrue(breakfast.dishes?.contains(dish2) ?? false)
    }
    
    func testCascadeDeletion() {
        // Create a dish with meal types
        let dish = createDishWithMealTypes(name: "Test Dish", mealTypeNames: ["Breakfast", "Lunch"])
        let mealTypeCount = (try? context.count(for: MealType.fetchRequest())) ?? 0
        
        // Delete the dish
        context.delete(dish)
        try? context.save()
        
        // Verify meal types still exist (nullify relationship)
        let newMealTypeCount = (try? context.count(for: MealType.fetchRequest())) ?? 0
        XCTAssertEqual(mealTypeCount, newMealTypeCount)
    }
    
    func testConcurrentContextOperations() {
        // Create a background context
        let backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        backgroundContext.parent = context
        
        // Create dish in background
        let expectation = XCTestExpectation(description: "Background operation")
        
        backgroundContext.perform {
            let dish = NSEntityDescription.insertNewObject(forEntityName: "Dish", into: backgroundContext) as! Dish
            dish.name = "Background Dish"
            try? backgroundContext.save()
            
            self.context.perform {
                // Verify dish is accessible in main context after save
                let request = NSFetchRequest<Dish>(entityName: "Dish")
                request.predicate = NSPredicate(format: "name == %@", "Background Dish")
                let dishes = try? self.context.fetch(request)
                XCTAssertEqual(dishes?.first?.name, "Background Dish")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testBatchOperations() {
        // Create multiple dishes
        let dishes = (1...5).map { i in
            createDishWithMealTypes(name: "Dish \(i)", mealTypeNames: ["Breakfast"])
        }
        
        // Perform updates in a batch using performAndWait
        context.performAndWait {
            dishes.forEach { dish in
                dish.details = "Updated in batch"
            }
            try? context.save()
        }
        
        // Verify updates in a new context to ensure changes were persisted
        let newContext = TestCoreDataStack.shared.persistentContainer.newBackgroundContext()
        newContext.performAndWait {
            let request = NSFetchRequest<Dish>(entityName: "Dish")
            request.predicate = NSPredicate(format: "details == %@", "Updated in batch")
            
            do {
                let updatedDishes = try newContext.fetch(request)
                XCTAssertEqual(updatedDishes.count, 5)
                XCTAssertTrue(updatedDishes.allSatisfy { $0.details == "Updated in batch" })
            } catch {
                XCTFail("Fetch failed: \(error)")
            }
        }
    }
    
    func testBulkDeletion() {
        // Create multiple dishes
        for i in 1...5 {
            _ = createDishWithMealTypes(name: "Dish \(i)", mealTypeNames: ["Breakfast"])
        }
        
        // Delete all dishes
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Dish")
        do {
            let dishes = try context.fetch(fetchRequest) as? [Dish] ?? []
            dishes.forEach { context.delete($0) }
            try context.save()
            
            // Verify deletion
            let count = try context.count(for: fetchRequest)
            XCTAssertEqual(count, 0)
        } catch {
            XCTFail("Bulk deletion failed: \(error)")
        }
    }
    
    func testBulkFetch() {
        // Create a large number of dishes
        for i in 1...20 {
            _ = createDishWithMealTypes(name: String(format: "Dish %02d", i), mealTypeNames: ["Breakfast"])
        }
        
        // Test fetching in batches
        let fetchRequest = NSFetchRequest<Dish>(entityName: "Dish")
        fetchRequest.fetchBatchSize = 5
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            let dishes = try context.fetch(fetchRequest)
            XCTAssertEqual(dishes.count, 20)
            
            // Verify we can access all dishes in sorted order
            for (index, dish) in dishes.enumerated() {
                XCTAssertEqual(dish.name, String(format: "Dish %02d", index + 1))
            }
        } catch {
            XCTFail("Batch fetch failed: \(error)")
        }
    }
    
    func testFetchRequestWithSorting() {
        // Create dishes with different names
        let names = ["Zebra Cake", "Apple Pie", "Banana Bread"]
        for name in names {
            _ = createDishWithMealTypes(name: name, mealTypeNames: ["Dessert"])
        }
        
        // Create sorted fetch request
        let request = NSFetchRequest<Dish>(entityName: "Dish")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            let sortedDishes = try context.fetch(request)
            XCTAssertEqual(sortedDishes[0].name, "Apple Pie")
            XCTAssertEqual(sortedDishes[1].name, "Banana Bread")
            XCTAssertEqual(sortedDishes[2].name, "Zebra Cake")
        } catch {
            XCTFail("Fetch failed: \(error)")
        }
    }
    
    func testDishSelectionWithRealViewModel() {
        // Create test dishes
        let dish1 = createDishWithMealTypes(name: "Omelette", mealTypeNames: ["Breakfast"])
        _ = createDishWithMealTypes(name: "Pancakes", mealTypeNames: ["Breakfast"]) // Create but don't need to reference
        
        var selectedDishes: [Dish] = []
        viewModel = DishSelectionViewModel(
            selectedDishes: [],
            mealType: "Breakfast",
            dishSelectionService: dishSelectionService
        ) { dishes in
            selectedDishes = dishes
        }
        
        // Test selection
        viewModel.selectedDishes.append(dish1)
        viewModel.onDishesSelected(viewModel.selectedDishes)
        XCTAssertEqual(selectedDishes.count, 1)
        XCTAssertTrue(selectedDishes.contains(dish1))
        
        // Test deselection
        viewModel.selectedDishes.removeAll()
        viewModel.onDishesSelected(viewModel.selectedDishes)
        XCTAssertTrue(selectedDishes.isEmpty)
    }
    
    func testSearchFunctionalityWithRealObjects() {
        // Create test dishes
        let breakfast1 = createDishWithMealTypes(name: "Omelette", mealTypeNames: ["Breakfast"])
        _ = createDishWithMealTypes(name: "Pancakes", mealTypeNames: ["Breakfast"]) // Create but don't need to reference
        _ = createDishWithMealTypes(name: "Soup", mealTypeNames: ["Lunch"]) // Create but don't need to reference
        
        viewModel = DishSelectionViewModel(
            selectedDishes: [],
            mealType: "Breakfast",
            dishSelectionService: dishSelectionService
        ) { _ in }
        
        // Test search with reactive binding and debouncing
        let expectation = XCTestExpectation(description: "Search filtering with optimization")
        viewModel.searchText = "Omel"
        
        // Wait for debounce period
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let (forMeal, other) = self.viewModel.splitDishes()
            XCTAssertEqual(forMeal.count, 1)
            XCTAssertTrue(forMeal.contains(breakfast1))
            XCTAssertEqual(other.count, 0)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testOptimizedSearchPerformance() {
        // Create multiple dishes for search testing
        _ = createDishWithMealTypes(name: "Apple Pancakes", mealTypeNames: ["Breakfast"])
        _ = createDishWithMealTypes(name: "Blueberry Pancakes", mealTypeNames: ["Breakfast"])
        _ = createDishWithMealTypes(name: "Chocolate Pancakes", mealTypeNames: ["Breakfast"])
        _ = createDishWithMealTypes(name: "Apple Pie", mealTypeNames: ["Dessert"])
        _ = createDishWithMealTypes(name: "Chicken Soup", mealTypeNames: ["Lunch"])
        
        viewModel = DishSelectionViewModel(
            selectedDishes: [],
            mealType: "Breakfast",
            dishSelectionService: dishSelectionService
        ) { _ in }
        
        let expectation = XCTestExpectation(description: "Optimized search performance")
        
        // Test search for "Apple" - should find Apple Pancakes in breakfast section, Apple Pie in other section
        viewModel.searchText = "Apple"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let (forMeal, other) = self.viewModel.splitDishes()
            XCTAssertEqual(forMeal.count, 1) // Apple Pancakes for breakfast
            XCTAssertEqual(other.count, 1) // Apple Pie for dessert
            
            // Test search refinement
            self.viewModel.searchText = "Apple Pancakes"
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                let (forMealRefined, otherRefined) = self.viewModel.splitDishes()
                XCTAssertEqual(forMealRefined.count, 1) // Only Apple Pancakes
                XCTAssertEqual(otherRefined.count, 0) // Apple Pie filtered out
                
                // Test clearing search
                self.viewModel.searchText = ""
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    let (allForMeal, allOther) = self.viewModel.splitDishes()
                    XCTAssertEqual(allForMeal.count, 3) // All 3 breakfast items
                    XCTAssertEqual(allOther.count, 2) // Dessert and lunch items
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testSearchCaseInsensitivityAndSpecialCharacters() {
        // Create dishes with various names
        _ = createDishWithMealTypes(name: "Café Latte", mealTypeNames: ["Breakfast"])
        _ = createDishWithMealTypes(name: "UPPERCASE DISH", mealTypeNames: ["Breakfast"])
        _ = createDishWithMealTypes(name: "Mixed-Case Dish", mealTypeNames: ["Lunch"])
        
        viewModel = DishSelectionViewModel(
            selectedDishes: [],
            mealType: "Breakfast",
            dishSelectionService: dishSelectionService
        ) { _ in }
        
        let expectation = XCTestExpectation(description: "Case insensitive search")
        
        // Test case insensitive search
        viewModel.searchText = "café"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let (forMeal, _) = self.viewModel.splitDishes()
            XCTAssertEqual(forMeal.count, 1)
            XCTAssertEqual(forMeal.first?.name, "Café Latte")
            
            // Test uppercase search
            self.viewModel.searchText = "uppercase"
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                let (forMealUpper, _) = self.viewModel.splitDishes()
                XCTAssertEqual(forMealUpper.count, 1)
                XCTAssertEqual(forMealUpper.first?.name, "UPPERCASE DISH")
                
                // Test mixed case search
                self.viewModel.searchText = "MIXED-case"
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    let (_, otherMixed) = self.viewModel.splitDishes()
                    XCTAssertEqual(otherMixed.count, 1)
                    XCTAssertEqual(otherMixed.first?.name, "Mixed-Case Dish")
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testSearchWithEmptyResults() {
        // Create test dishes
        _ = createDishWithMealTypes(name: "Omelette", mealTypeNames: ["Breakfast"])
        _ = createDishWithMealTypes(name: "Pancakes", mealTypeNames: ["Breakfast"])
        
        viewModel = DishSelectionViewModel(
            selectedDishes: [],
            mealType: "Breakfast",
            dishSelectionService: dishSelectionService
        ) { _ in }
        
        let expectation = XCTestExpectation(description: "Empty search results")
        
        // Search for non-existent dish
        viewModel.searchText = "NonExistentDish"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let (forMeal, other) = self.viewModel.splitDishes()
            XCTAssertEqual(forMeal.count, 0)
            XCTAssertEqual(other.count, 0)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMealTypeFilteringWithRealObjects() {
        // Create test dishes with multiple meal types
        let versatileDish = createDishWithMealTypes(name: "Eggs Benedict", mealTypeNames: ["Breakfast", "Brunch"])
        let lunchDish = createDishWithMealTypes(name: "Sandwich", mealTypeNames: ["Lunch"])
        
        viewModel = DishSelectionViewModel(
            selectedDishes: [],
            mealType: "Breakfast",
            dishSelectionService: dishSelectionService
        ) { _ in }
        
        // Wait for reactive bindings to complete before testing
        let expectation = XCTestExpectation(description: "Meal type filtering with reactive bindings")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let (breakfastDishes, otherDishes) = self.viewModel.splitDishes()
            XCTAssertEqual(breakfastDishes.count, 1)
            XCTAssertTrue(breakfastDishes.contains(versatileDish))
            XCTAssertEqual(otherDishes.count, 1)
            XCTAssertTrue(otherDishes.contains(lunchDish))
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPersistenceOfSelections() {
        // Create test dishes
        let dish1 = createDishWithMealTypes(name: "Dish 1", mealTypeNames: ["Breakfast"])
        let dish2 = createDishWithMealTypes(name: "Dish 2", mealTypeNames: ["Breakfast"])
        
        var selectedDishes: [Dish] = []
        viewModel = DishSelectionViewModel(
            selectedDishes: [dish1],
            mealType: "Breakfast",
            dishSelectionService: dishSelectionService
        ) { dishes in
            selectedDishes = dishes
        }
        
        // Verify initial selection is preserved
        XCTAssertEqual(viewModel.selectedDishes.count, 1)
        XCTAssertTrue(viewModel.selectedDishes.contains(dish1))
        
        // Add another selection
        viewModel.selectedDishes.append(dish2)
        viewModel.onDishesSelected(viewModel.selectedDishes)
        
        // Verify both selections are maintained
        XCTAssertEqual(selectedDishes.count, 2)
        XCTAssertTrue(selectedDishes.contains(dish1))
        XCTAssertTrue(selectedDishes.contains(dish2))
    }
    
    func testEmptyStateHandling() {
        viewModel = DishSelectionViewModel(
            selectedDishes: [],
            mealType: "Breakfast",
            dishSelectionService: dishSelectionService
        ) { _ in }
        
        let (forMeal, other) = viewModel.splitDishes()
        XCTAssertEqual(forMeal.count, 0)
        XCTAssertEqual(other.count, 0)
    }
    
    // MARK: - UI Component Tests
    
    func testCardBasedSelectionUI() {
        // Create test dishes with categories and meal types
        _ = createOrFetchMealType(name: "Breakfast")
        _ = createOrFetchMealType(name: "Lunch")
        
        let dish1 = createDishWithMealTypes(name: "Omelette", mealTypeNames: ["Breakfast"])
        _ = createDishWithMealTypes(name: "Sandwich", mealTypeNames: ["Lunch"])
        
        var selectedDishes: [Dish] = []
        viewModel = DishSelectionViewModel(
            selectedDishes: [],
            mealType: "Breakfast",
            dishSelectionService: dishSelectionService
        ) { dishes in
            selectedDishes = dishes
        }
        
        // Test selection through card interaction
        viewModel.selectedDishes.append(dish1)
        viewModel.onDishesSelected(viewModel.selectedDishes)
        
        XCTAssertEqual(selectedDishes.count, 1)
        XCTAssertTrue(selectedDishes.contains(dish1))
        
        // Test deselection
        viewModel.selectedDishes.removeAll { $0 == dish1 }
        viewModel.onDishesSelected(viewModel.selectedDishes)
        
        XCTAssertTrue(selectedDishes.isEmpty)
    }
    
    func testMultiSelectionWithSaveButton() {
        // Create test dishes
        let dish1 = createDishWithMealTypes(name: "Dish 1", mealTypeNames: ["Breakfast"])
        let dish2 = createDishWithMealTypes(name: "Dish 2", mealTypeNames: ["Breakfast"])
        let dish3 = createDishWithMealTypes(name: "Dish 3", mealTypeNames: ["Lunch"])
        
        var selectedDishes: [Dish] = []
        viewModel = DishSelectionViewModel(
            selectedDishes: [],
            mealType: "Breakfast",
            dishSelectionService: dishSelectionService
        ) { dishes in
            selectedDishes = dishes
        }
        
        // Select multiple dishes
        viewModel.selectedDishes.append(dish1)
        viewModel.selectedDishes.append(dish2)
        viewModel.onDishesSelected(viewModel.selectedDishes)
        
        XCTAssertEqual(selectedDishes.count, 2)
        XCTAssertTrue(selectedDishes.contains(dish1))
        XCTAssertTrue(selectedDishes.contains(dish2))
        
        // Add dish from other section
        viewModel.selectedDishes.append(dish3)
        viewModel.onDishesSelected(viewModel.selectedDishes)
        
        XCTAssertEqual(selectedDishes.count, 3)
        XCTAssertTrue(selectedDishes.contains(dish3))
    }
    
    func testSectionOrganizationWithCards() {
        // Create dishes for different meal types
        let breakfastDish = createDishWithMealTypes(name: "Pancakes", mealTypeNames: ["Breakfast"])
        let lunchDish = createDishWithMealTypes(name: "Soup", mealTypeNames: ["Lunch"])
        let dinnerDish = createDishWithMealTypes(name: "Steak", mealTypeNames: ["Dinner"])
        
        viewModel = DishSelectionViewModel(
            selectedDishes: [],
            mealType: "Breakfast",
            dishSelectionService: dishSelectionService
        ) { _ in }
        
        // Wait for reactive bindings to complete
        let expectation = XCTestExpectation(description: "Section organization")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let (breakfastDishes, otherDishes) = self.viewModel.splitDishes()
            
            // Verify breakfast dishes are in the correct section
            XCTAssertEqual(breakfastDishes.count, 1)
            XCTAssertTrue(breakfastDishes.contains(breakfastDish))
            
            // Verify other dishes are in the other section
            XCTAssertEqual(otherDishes.count, 2)
            XCTAssertTrue(otherDishes.contains(lunchDish))
            XCTAssertTrue(otherDishes.contains(dinnerDish))
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testEmptyStateWithNoDishes() {
        viewModel = DishSelectionViewModel(
            selectedDishes: [],
            mealType: "Breakfast",
            dishSelectionService: dishSelectionService
        ) { _ in }
        
        let (forMeal, other) = viewModel.splitDishes()
        
        // Verify empty state when no dishes exist
        XCTAssertEqual(forMeal.count, 0)
        XCTAssertEqual(other.count, 0)
        
        // This should trigger the EmptyDishSelectionView in the UI
    }
    
    func testEmptyStateWithSearchNoResults() {
        // Create a dish that won't match search
        _ = createDishWithMealTypes(name: "Pancakes", mealTypeNames: ["Breakfast"])
        
        viewModel = DishSelectionViewModel(
            selectedDishes: [],
            mealType: "Breakfast",
            dishSelectionService: dishSelectionService
        ) { _ in }
        
        // Search for non-existent dish
        viewModel.searchText = "NonExistentDish"
        
        let expectation = XCTestExpectation(description: "Search filtering")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let (forMeal, other) = self.viewModel.splitDishes()
            XCTAssertEqual(forMeal.count, 0)
            XCTAssertEqual(other.count, 0)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testAccessibilitySupport() {
        let dish = createDishWithMealTypes(name: "Test Dish", mealTypeNames: ["Breakfast"])
        
        viewModel = DishSelectionViewModel(
            selectedDishes: [dish],
            mealType: "Breakfast",
            dishSelectionService: dishSelectionService
        ) { _ in }
        
        // Wait for reactive bindings to complete
        let expectation = XCTestExpectation(description: "Accessibility support")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let (forMeal, other) = self.viewModel.splitDishes()
            
            // Verify dish is selected in view model
            XCTAssertTrue(self.viewModel.selectedDishes.contains(dish))
            
            // Verify the dish has the expected name for accessibility
            XCTAssertEqual(dish.name, "Test Dish")
            
            // The dish should be in either forMeal or other section
            let totalDishes = forMeal.count + other.count
            XCTAssertGreaterThanOrEqual(totalDishes, 1)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
} 
