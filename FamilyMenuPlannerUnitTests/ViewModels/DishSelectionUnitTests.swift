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
    
    func testEmptyMealTypeString() {
        let dish = MockDish(name: "Test Dish", mealTypes: [MockMealType(name: "")])
        mockService.dishes = [dish]
        
        viewModel = MockDishSelectionViewModel(
            selectedDishes: [],
            mealType: "",
            dishSelectionService: mockService
        ) { _ in }
        
        let (forMeal, _) = viewModel.splitDishes()
        XCTAssertEqual(forMeal.count, 1)
        XCTAssertTrue(forMeal.contains(dish))
    }
}
