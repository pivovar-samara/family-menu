//
//  DishSelectionUnitTests.swift
//  FamilyMenuPlanner
//
//  Created by Pivovar 63 on 27.05.25.
//

import XCTest

// MARK: - Mock Models (not using Core Data)
class MockMealType: Hashable {
    let name: String
    init(name: String) { self.name = name }
    static func == (lhs: MockMealType, rhs: MockMealType) -> Bool { lhs.name == rhs.name }
    func hash(into hasher: inout Hasher) { hasher.combine(name) }
}

class MockDish: Hashable {
    let name: String?
    var mealTypes: Set<MockMealType>
    init(name: String?, mealTypes: Set<MockMealType> = []) {
        self.name = name
        self.mealTypes = mealTypes
    }
    static func == (lhs: MockDish, rhs: MockDish) -> Bool {
        lhs.name == rhs.name && lhs.mealTypes == rhs.mealTypes
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(mealTypes)
    }
}

// MARK: - Mock Service
protocol MockDishSelectionServiceProtocol {
    func fetchAllDishes() -> [MockDish]
    func rollback()
}

class MockDishSelectionService: MockDishSelectionServiceProtocol {
    var dishes: [MockDish] = []
    var rollbackCalled = false
    func fetchAllDishes() -> [MockDish] { dishes }
    func rollback() { rollbackCalled = true }
}

// MARK: - ViewModel (non-Core Data version for testing)
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
    func rollback() {
        dishSelectionService.rollback()
    }
    func splitDishes(dishes: [MockDish]? = nil, mealType: String? = nil) -> (dishesForMealType: [MockDish], otherDishes: [MockDish]) {
        let allDishes = dishes ?? dishSelectionService.fetchAllDishes()
        let filterMealType = mealType ?? self.mealType
        var dishesForMealType: [MockDish] = []
        var otherDishes: [MockDish] = []
        for dish in allDishes {
            let matchesSearch = searchText.isEmpty || (dish.name?.localizedCaseInsensitiveContains(searchText) ?? false)
            guard matchesSearch else { continue }
            if dish.mealTypes.contains(where: { $0.name == filterMealType }) {
                dishesForMealType.append(dish)
            } else {
                otherDishes.append(dish)
            }
        }
        return (dishesForMealType, otherDishes)
    }
}

// MARK: - Tests
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

    func makeDish(name: String, mealTypeNames: [String] = []) -> MockDish {
        let mealTypes = Set(mealTypeNames.map { MockMealType(name: $0) })
        return MockDish(name: name, mealTypes: mealTypes)
    }

    func setUpViewModel(selected: [MockDish] = [], mealType: String = "Breakfast", onDishesSelected: @escaping ([MockDish]) -> Void = { _ in }) {
        viewModel = MockDishSelectionViewModel(selectedDishes: selected, mealType: mealType, dishSelectionService: mockService, onDishesSelected: onDishesSelected)
    }

    func testFetchAllDishesReturnsDishes() {
        let dish1 = makeDish(name: "Omelette", mealTypeNames: ["Breakfast"])
        let dish2 = makeDish(name: "Soup", mealTypeNames: ["Lunch"])
        mockService.dishes = [dish1, dish2]
        XCTAssertEqual(mockService.fetchAllDishes().count, 2)
    }

    func testRollbackCallsService() {
        setUpViewModel()
        viewModel.rollback()
        XCTAssertTrue(mockService.rollbackCalled)
    }

    func testSplitDishesFiltersByMealType() {
        let breakfast = makeDish(name: "Omelette", mealTypeNames: ["Breakfast"])
        let lunch = makeDish(name: "Soup", mealTypeNames: ["Lunch"])
        let both = makeDish(name: "Toast", mealTypeNames: ["Breakfast", "Lunch"])
        mockService.dishes = [breakfast, lunch, both]
        setUpViewModel(mealType: "Breakfast")
        let (forMeal, other) = viewModel.splitDishes(dishes: mockService.dishes, mealType: "Breakfast")
        XCTAssertTrue(forMeal.contains(breakfast))
        XCTAssertTrue(forMeal.contains(both))
        XCTAssertFalse(forMeal.contains(lunch))
        XCTAssertTrue(other.contains(lunch))
        XCTAssertFalse(other.contains(breakfast))
        XCTAssertFalse(other.contains(both))
    }

    func testSplitDishesFiltersBySearchText() {
        let dish1 = makeDish(name: "Omelette", mealTypeNames: ["Breakfast"])
        let dish2 = makeDish(name: "Soup", mealTypeNames: ["Lunch"])
        mockService.dishes = [dish1, dish2]
        setUpViewModel(mealType: "Breakfast")
        viewModel.searchText = "Soup"
        let (forMeal, other) = viewModel.splitDishes(dishes: mockService.dishes, mealType: "Breakfast")
        XCTAssertTrue(other.contains(dish2))
        XCTAssertTrue(forMeal.isEmpty)
    }

    func testSelectionLogic() {
        let dish = makeDish(name: "Omelette", mealTypeNames: ["Breakfast"])
        var selected: [MockDish] = []
        setUpViewModel(selected: selected, mealType: "Breakfast") { newSelected in
            selected = newSelected
        }
        viewModel.selectedDishes.append(dish)
        viewModel.onDishesSelected(viewModel.selectedDishes)
        XCTAssertTrue(selected.contains(dish))
    }
}
