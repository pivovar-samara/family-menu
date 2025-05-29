//
//  DishSelectionIntegrationTests.swift
//  FamilyMenuPlannerTests
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
    
    func testContextSaveAndRollback() {
        // Create initial state
        let dish = createDishWithMealTypes(name: "Original Name", mealTypeNames: ["Breakfast"])
        let originalMealTypes = dish.mealTypes?.count ?? 0
        
        // Modify dish
        dish.name = "Modified Name"
        dish.mealTypes = nil
        
        // Rollback
        context.rollback()
        
        // Verify original state is restored
        XCTAssertEqual(dish.name, "Original Name")
        XCTAssertEqual(dish.mealTypes?.count ?? 0, originalMealTypes)
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
        
        // Test search
        viewModel.searchText = "Omel"
        let (forMeal, other) = viewModel.splitDishes()
        XCTAssertEqual(forMeal.count, 1)
        XCTAssertTrue(forMeal.contains(breakfast1))
        XCTAssertEqual(other.count, 0)
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
        
        let (breakfastDishes, otherDishes) = viewModel.splitDishes()
        XCTAssertEqual(breakfastDishes.count, 1)
        XCTAssertTrue(breakfastDishes.contains(versatileDish))
        XCTAssertEqual(otherDishes.count, 1)
        XCTAssertTrue(otherDishes.contains(lunchDish))
    }
    
    func testRollbackFunctionality() {
        // Create initial state
        let dish = createDishWithMealTypes(name: "Test Dish", mealTypeNames: ["Breakfast"])
        
        // Modify dish
        dish.name = "Modified Name"
        
        // Rollback
        dishSelectionService.rollback()
        
        // Verify rollback
        XCTAssertEqual(dish.name, "Test Dish")
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
} 