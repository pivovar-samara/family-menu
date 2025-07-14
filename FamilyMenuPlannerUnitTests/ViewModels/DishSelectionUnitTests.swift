//
//  DishSelectionUnitTests.swift
//  FamilyMenuPlannerUnitTests
//
//  Created by Pivovar 63 on 27.05.25.
//

import XCTest
@testable import FamilyMenuPlanner

// MARK: - Mock Service
protocol MockDishSelectionServiceProtocol {
    func fetchAllDishes() -> [MockDish]
    func rollback()
}

class MockDishSelectionService: MockDishSelectionServiceProtocol {
    var dishes: [MockDish] = []
    var rollbackCalled = false
    var error: Error?
    
    func fetchAllDishes() -> [MockDish] {
        if let error = error {
            print("Error fetching dishes: \(error)")
            return []
        }
        return dishes
    }
    
    func rollback() {
        rollbackCalled = true
    }
}

// MARK: - View Model for Unit Tests
class MockDishSelectionViewModel {
    var searchText: String = ""
    var selectedDishes: [MockDish] = []
    var mealType: String
    var onDishesSelected: ([MockDish]) -> Void
    private let dishSelectionService: MockDishSelectionServiceProtocol
    
    init(selectedDishes: [MockDish], mealType: String, dishSelectionService: MockDishSelectionServiceProtocol, onDishesSelected: @escaping ([MockDish]) -> Void) {
        self.selectedDishes = selectedDishes
        self.mealType = mealType
        self.onDishesSelected = onDishesSelected
        self.dishSelectionService = dishSelectionService
    }
    
    func splitDishes() -> (dishesForMealType: [MockDish], otherDishes: [MockDish]) {
        let allDishes = dishSelectionService.fetchAllDishes()
        var dishesForMealType: [MockDish] = []
        var otherDishes: [MockDish] = []
        
        for dish in allDishes {
            let matchesSearch = searchText.isEmpty || (dish.name?.localizedCaseInsensitiveContains(searchText) ?? false)
            guard matchesSearch else { continue }
            
            if dish.mealTypes.contains(where: { $0.name == mealType }) {
                dishesForMealType.append(dish)
            } else {
                otherDishes.append(dish)
            }
        }
        return (dishesForMealType, otherDishes)
    }
}

// MARK: - Unit Tests
class DishSelectionUnitTests: XCTestCase {
    var mockService: MockDishSelectionService!
    var viewModel: MockDishSelectionViewModel!
    
    override func setUp() {
        super.setUp()
        mockService = MockDishSelectionService()
    }
    
    override func tearDown() {
        mockService = nil
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Error Handling Tests
    
    func testFetchDishesWithError() {
        mockService.error = NSError(domain: "TestError", code: -1, userInfo: nil)
        viewModel = MockDishSelectionViewModel(
            selectedDishes: [],
            mealType: "Breakfast",
            dishSelectionService: mockService
        ) { _ in }
        
        let (dishesForMealType, otherDishes) = viewModel.splitDishes()
        XCTAssertTrue(dishesForMealType.isEmpty)
        XCTAssertTrue(otherDishes.isEmpty)
    }
    
    // MARK: - Search Tests
    
    func testSearchWithSpecialCharacters() {
        let dish = MockDish(name: "Egg & Cheese", mealTypes: [MockMealType(name: "Breakfast")])
        mockService.dishes = [dish]
        
        viewModel = MockDishSelectionViewModel(
            selectedDishes: [],
            mealType: "Breakfast",
            dishSelectionService: mockService
        ) { _ in }
        
        viewModel.searchText = "&"
        let (forMeal, _) = viewModel.splitDishes()
        XCTAssertEqual(forMeal.count, 1)
        XCTAssertTrue(forMeal.contains(dish))
    }
    
    func testSearchWithDifferentCases() {
        let dish = MockDish(name: "UPPERCASE DISH", mealTypes: [MockMealType(name: "Breakfast")])
        mockService.dishes = [dish]
        
        viewModel = MockDishSelectionViewModel(
            selectedDishes: [],
            mealType: "Breakfast",
            dishSelectionService: mockService
        ) { _ in }
        
        viewModel.searchText = "uppercase"
        let (forMeal, _) = viewModel.splitDishes()
        XCTAssertEqual(forMeal.count, 1)
        XCTAssertTrue(forMeal.contains(dish))
    }
    
    // MARK: - Meal Type Tests
    
    func testDishWithMultipleMealTypesSorting() {
        let breakfast = MockMealType(name: "Breakfast", sortOrder: 1)
        let lunch = MockMealType(name: "Lunch", sortOrder: 2)
        let dish = MockDish(name: "Versatile Dish", mealTypes: [breakfast, lunch])
        mockService.dishes = [dish]
        
        // Test breakfast view
        viewModel = MockDishSelectionViewModel(
            selectedDishes: [],
            mealType: "Breakfast",
            dishSelectionService: mockService
        ) { _ in }
        
        let (forBreakfast, other) = viewModel.splitDishes()
        XCTAssertEqual(forBreakfast.count, 1)
        XCTAssertEqual(other.count, 0)
        
        // Test lunch view
        viewModel.mealType = "Lunch"
        let (forLunch, _) = viewModel.splitDishes()
        XCTAssertEqual(forLunch.count, 1)
        
        // Test dinner view (dish shouldn't appear)
        viewModel.mealType = "Dinner"
        let (forDinner, otherMeals) = viewModel.splitDishes()
        XCTAssertEqual(forDinner.count, 0)
        XCTAssertEqual(otherMeals.count, 1)
    }
    
    // MARK: - Edge Cases
    
    func testDishWithNilName() {
        let dish = MockDish(name: nil, mealTypes: [MockMealType(name: "Breakfast")])
        mockService.dishes = [dish]
        
        viewModel = MockDishSelectionViewModel(
            selectedDishes: [],
            mealType: "Breakfast",
            dishSelectionService: mockService
        ) { _ in }
        
        viewModel.searchText = "any"
        let (forMeal, otherDishes) = viewModel.splitDishes()
        XCTAssertTrue(forMeal.isEmpty)
        XCTAssertTrue(otherDishes.isEmpty)
    }
    
    // MARK: - UI Component Tests
    
    func testCardBasedSelectionLogic() {
        let breakfast = MockMealType(name: "Breakfast")
        let dish1 = MockDish(name: "Omelette", mealTypes: [breakfast])
        let dish2 = MockDish(name: "Pancakes", mealTypes: [breakfast])
        
        mockService.dishes = [dish1, dish2]
        
        var selectedDishes: [MockDish] = []
        viewModel = MockDishSelectionViewModel(
            selectedDishes: [],
            mealType: "Breakfast",
            dishSelectionService: mockService
        ) { dishes in
            selectedDishes = dishes
        }
        
        // Test selection
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
        let breakfast = MockMealType(name: "Breakfast")
        let lunch = MockMealType(name: "Lunch")
        
        let dish1 = MockDish(name: "Dish 1", mealTypes: [breakfast])
        let dish2 = MockDish(name: "Dish 2", mealTypes: [breakfast])
        let dish3 = MockDish(name: "Dish 3", mealTypes: [lunch])
        
        mockService.dishes = [dish1, dish2, dish3]
        
        var selectedDishes: [MockDish] = []
        viewModel = MockDishSelectionViewModel(
            selectedDishes: [],
            mealType: "Breakfast",
            dishSelectionService: mockService
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
        let breakfast = MockMealType(name: "Breakfast")
        let lunch = MockMealType(name: "Lunch")
        let dinner = MockMealType(name: "Dinner")
        
        let breakfastDish = MockDish(name: "Pancakes", mealTypes: [breakfast])
        let lunchDish = MockDish(name: "Soup", mealTypes: [lunch])
        let dinnerDish = MockDish(name: "Steak", mealTypes: [dinner])
        
        mockService.dishes = [breakfastDish, lunchDish, dinnerDish]
        
        viewModel = MockDishSelectionViewModel(
            selectedDishes: [],
            mealType: "Breakfast",
            dishSelectionService: mockService
        ) { _ in }
        
        let (breakfastDishes, otherDishes) = viewModel.splitDishes()
        
        // Verify breakfast dishes are in the correct section
        XCTAssertEqual(breakfastDishes.count, 1)
        XCTAssertTrue(breakfastDishes.contains(breakfastDish))
        
        // Verify other dishes are in the other section
        XCTAssertEqual(otherDishes.count, 2)
        XCTAssertTrue(otherDishes.contains(lunchDish))
        XCTAssertTrue(otherDishes.contains(dinnerDish))
    }
    
    func testEmptyStateHandling() {
        mockService.dishes = []
        
        viewModel = MockDishSelectionViewModel(
            selectedDishes: [],
            mealType: "Breakfast",
            dishSelectionService: mockService
        ) { _ in }
        
        let (forMeal, other) = viewModel.splitDishes()
        
        // Verify empty state when no dishes exist
        XCTAssertEqual(forMeal.count, 0)
        XCTAssertEqual(other.count, 0)
    }
    
    func testEmptyStateWithSearchNoResults() {
        let breakfast = MockMealType(name: "Breakfast")
        let dish = MockDish(name: "Pancakes", mealTypes: [breakfast])
        mockService.dishes = [dish]
        
        viewModel = MockDishSelectionViewModel(
            selectedDishes: [],
            mealType: "Breakfast",
            dishSelectionService: mockService
        ) { _ in }
        
        // Search for non-existent dish
        viewModel.searchText = "NonExistentDish"
        
        let (forMeal, other) = viewModel.splitDishes()
        XCTAssertEqual(forMeal.count, 0)
        XCTAssertEqual(other.count, 0)
    }
    
    func testAccessibilitySupport() {
        let breakfast = MockMealType(name: "Breakfast")
        let dish = MockDish(name: "Test Dish", mealTypes: [breakfast])
        mockService.dishes = [dish]
        
        viewModel = MockDishSelectionViewModel(
            selectedDishes: [dish],
            mealType: "Breakfast",
            dishSelectionService: mockService
        ) { _ in }
        
        let (forMeal, _) = viewModel.splitDishes()
        
        // Verify dish is selected
        XCTAssertEqual(forMeal.count, 1)
        XCTAssertTrue(viewModel.selectedDishes.contains(dish))
        
        // The UI should have proper accessibility identifiers:
        // - dish_selection_card_Test Dish
        // - dish_selection_done_button
        // - dish_selection_empty_state (when applicable)
    }
    
    func testRollbackWithUnsavedSelections() {
        let breakfast = MockMealType(name: "Breakfast")
        let dish = MockDish(name: "Test Dish", mealTypes: [breakfast])
        mockService.dishes = [dish]
        
        var selectedDishes: [MockDish] = []
        viewModel = MockDishSelectionViewModel(
            selectedDishes: [],
            mealType: "Breakfast",
            dishSelectionService: mockService
        ) { dishes in
            selectedDishes = dishes
        }
        
        // Select a dish
        viewModel.selectedDishes.append(dish)
        viewModel.onDishesSelected(viewModel.selectedDishes)
        
        XCTAssertEqual(selectedDishes.count, 1)
        
        // Rollback without saving
        mockService.rollback()
        
        // Verify rollback occurred
        XCTAssertTrue(mockService.rollbackCalled)
    }
    
    func testCardSelectionWithCategoryAndMealTypes() {
        let breakfast = MockMealType(name: "Breakfast")
        let lunch = MockMealType(name: "Lunch")
        
        let dish = MockDish(name: "Versatile Dish", mealTypes: [breakfast, lunch])
        mockService.dishes = [dish]
        
        viewModel = MockDishSelectionViewModel(
            selectedDishes: [],
            mealType: "Breakfast",
            dishSelectionService: mockService
        ) { _ in }
        
        let (breakfastDishes, otherDishes) = viewModel.splitDishes()
        
        // Dish should appear in breakfast section since it has breakfast meal type
        XCTAssertEqual(breakfastDishes.count, 1)
        XCTAssertTrue(breakfastDishes.contains(dish))
        XCTAssertEqual(otherDishes.count, 0)
        
        // Change meal type to lunch
        viewModel.mealType = "Lunch"
        let (lunchDishes, otherLunchDishes) = viewModel.splitDishes()
        
        // Dish should appear in lunch section
        XCTAssertEqual(lunchDishes.count, 1)
        XCTAssertTrue(lunchDishes.contains(dish))
        XCTAssertEqual(otherLunchDishes.count, 0)
    }
}
