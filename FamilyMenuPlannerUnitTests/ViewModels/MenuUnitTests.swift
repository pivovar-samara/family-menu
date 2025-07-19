//
//  MenuUnitTests.swift
//  FamilyMenuPlannerUnitTests
//
//  Created by Ilya Khokhlov on 27.01.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

// Mock implementations for protocol and models
class MockMenuService: MenuServiceProtocol {
    var fetchMenuCalled = false
    var generateMenuCalled = false
    var removeOldWeeksCalled = false
    var replaceDishesCalled = false
    var clearMealTypeCalled = false

    var fetchMenuResult: [DailyMenu] = []
    var replaceDishesShouldThrow = false
    var clearMealTypeShouldThrow = false

    func fetchMenu(for weekIndex: Int) -> [DailyMenu] {
        fetchMenuCalled = true
        return fetchMenuResult
    }
    func generateMenu(for weekDate: Date) {
        generateMenuCalled = true
    }
    func removeOldWeeks() {
        removeOldWeeksCalled = true
    }
    func replaceDishes(for day: String, mealType: String, selectedWeekDate: Date, with newDishes: [Dish]) throws {
        replaceDishesCalled = true
        if replaceDishesShouldThrow { throw NSError(domain: "Test", code: 1) }
    }
    func clearMealType(for day: String, selectedWeekDate: Date, mealType: String?) throws {
        clearMealTypeCalled = true
        if clearMealTypeShouldThrow { throw NSError(domain: "Test", code: 2) }
    }
}

final class MenuUnitTests: XCTestCase {
    
    private let selectedWeekIndexKey = "MenuSelectedWeekIndex"
    
    override func setUp() {
        super.setUp()
        // Clear any existing UserDefaults from previous tests
        UserDefaults.standard.removeObject(forKey: selectedWeekIndexKey)
    }
    
    override func tearDown() {
        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: selectedWeekIndexKey)
        super.tearDown()
    }

    func testLoadMenuFetchesMenu() {
        let mock = MockMenuService()
        let viewModel = MenuViewModel(menuService: mock)
        mock.fetchMenuResult = [DailyMenu(day: "Monday", dailyMeals: [])]
        viewModel.loadMenu(for: 0)
        XCTAssertTrue(mock.fetchMenuCalled)
        XCTAssertEqual(viewModel.weeklyMenu.count, 1)
        XCTAssertEqual(viewModel.weeklyMenu.first?.day, "Monday")
    }

    func testGenerateMenuCallsServiceAndReloads() {
        let mock = MockMenuService()
        let viewModel = MenuViewModel(menuService: mock)
        viewModel.generateMenu()
        XCTAssertTrue(mock.generateMenuCalled)
        XCTAssertTrue(mock.fetchMenuCalled)
    }

    func testRemoveOldWeeksCallsService() {
        let mock = MockMenuService()
        let viewModel = MenuViewModel(menuService: mock)
        viewModel.removeOldWeeks()
        XCTAssertTrue(mock.removeOldWeeksCalled)
    }

    func testReplaceDishesSuccess() {
        let mock = MockMenuService()
        let viewModel = MenuViewModel(menuService: mock)
        viewModel.replaceDishes(for: "Monday", mealType: "Lunch", with: [])
        XCTAssertTrue(mock.replaceDishesCalled)
        XCTAssertTrue(mock.fetchMenuCalled)
    }

    func testReplaceDishesFailureShowsAlert() {
        let mock = MockMenuService()
        mock.replaceDishesShouldThrow = true
        let viewModel = MenuViewModel(menuService: mock)
        let exp = expectation(description: "Alert shown")
        viewModel.replaceDishes(for: "Monday", mealType: "Lunch", with: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertNotNil(viewModel.currentAlert)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }

    func testClearMealTypeSuccess() {
        let mock = MockMenuService()
        let viewModel = MenuViewModel(menuService: mock)
        viewModel.clearMealType(for: "Monday", mealType: "Lunch")
        XCTAssertTrue(mock.clearMealTypeCalled)
        XCTAssertTrue(mock.fetchMenuCalled)
    }

    func testClearMealTypeFailureShowsAlert() {
        let mock = MockMenuService()
        mock.clearMealTypeShouldThrow = true
        let viewModel = MenuViewModel(menuService: mock)
        let exp = expectation(description: "Alert shown")
        viewModel.clearMealType(for: "Monday", mealType: "Lunch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertNotNil(viewModel.currentAlert)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }

    func testEnqueueAndDismissAlert() {
        let mock = MockMenuService()
        let viewModel = MenuViewModel(menuService: mock)
        let exp = expectation(description: "Alert enqueued")
        viewModel.enqueueAlert(title: "Test", message: "Message")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNotNil(viewModel.currentAlert)
            viewModel.dismissAlert()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssertNil(viewModel.currentAlert)
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 1)
    }

    func testGenerateMenuWithInvalidIndexShowsAlert() {
        let mock = MockMenuService()
        let viewModel = MenuViewModel(menuService: mock)
        viewModel.selectedWeekIndex = 10 // Out of bounds
        let exp = expectation(description: "Alert shown")
        viewModel.generateMenu()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertNotNil(viewModel.currentAlert)
            XCTAssertFalse(mock.generateMenuCalled)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }

    func testReplaceDishesWithInvalidIndexShowsAlert() {
        let mock = MockMenuService()
        let viewModel = MenuViewModel(menuService: mock)
        viewModel.selectedWeekIndex = -1 // Out of bounds
        let exp = expectation(description: "Alert shown")
        viewModel.replaceDishes(for: "Monday", mealType: "Lunch", with: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertNotNil(viewModel.currentAlert)
            XCTAssertFalse(mock.replaceDishesCalled)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }

    func testClearMealTypeWithInvalidIndexShowsAlert() {
        let mock = MockMenuService()
        let viewModel = MenuViewModel(menuService: mock)
        viewModel.selectedWeekIndex = 100 // Out of bounds
        let exp = expectation(description: "Alert shown")
        viewModel.clearMealType(for: "Monday", mealType: "Lunch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertNotNil(viewModel.currentAlert)
            XCTAssertFalse(mock.clearMealTypeCalled)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }
    
    // MARK: - UserDefaults Persistence Tests
    
    func testLoadSelectedWeekIndexFromUserDefaults() {
        // Set a saved week index in UserDefaults
        UserDefaults.standard.set(2, forKey: selectedWeekIndexKey)
        
        let mock = MockMenuService()
        let viewModel = MenuViewModel(menuService: mock)
        
        // Should load the saved week index
        XCTAssertEqual(viewModel.selectedWeekIndex, 2)
    }
    
    func testLoadSelectedWeekIndexWithInvalidValueDefaultsToZero() {
        // Set an invalid week index in UserDefaults
        UserDefaults.standard.set(10, forKey: selectedWeekIndexKey)
        
        let mock = MockMenuService()
        let viewModel = MenuViewModel(menuService: mock)
        
        // Should default to 0 for invalid index
        XCTAssertEqual(viewModel.selectedWeekIndex, 0)
    }
    
    func testLoadSelectedWeekIndexWithNegativeValueDefaultsToZero() {
        // Set a negative week index in UserDefaults
        UserDefaults.standard.set(-1, forKey: selectedWeekIndexKey)
        
        let mock = MockMenuService()
        let viewModel = MenuViewModel(menuService: mock)
        
        // Should default to 0 for negative index
        XCTAssertEqual(viewModel.selectedWeekIndex, 0)
    }
    
    func testUpdateSelectedWeekIndexSavesToUserDefaults() {
        let mock = MockMenuService()
        let viewModel = MenuViewModel(menuService: mock)
        
        // Update to a new week index
        viewModel.updateSelectedWeekIndex(1)
        
        // Verify it's saved to UserDefaults
        let savedValue = UserDefaults.standard.integer(forKey: selectedWeekIndexKey)
        XCTAssertEqual(savedValue, 1)
        XCTAssertEqual(viewModel.selectedWeekIndex, 1)
    }
    
    func testUpdateSelectedWeekIndexDoesNotSaveIfSameValue() {
        let mock = MockMenuService()
        let viewModel = MenuViewModel(menuService: mock)
        
        // Set initial value
        viewModel.updateSelectedWeekIndex(1)
        
        // Clear UserDefaults to verify it gets set again
        UserDefaults.standard.removeObject(forKey: selectedWeekIndexKey)
        
        // Try to update to the same value
        viewModel.updateSelectedWeekIndex(1)
        
        // Should not save the same value again
        let savedValue = UserDefaults.standard.object(forKey: selectedWeekIndexKey)
        XCTAssertNil(savedValue, "Should not save the same value again")
    }
    
    func testInitializationWithNoUserDefaultsDefaultsToZero() {
        // Ensure UserDefaults is clean
        UserDefaults.standard.removeObject(forKey: selectedWeekIndexKey)
        
        let mock = MockMenuService()
        let viewModel = MenuViewModel(menuService: mock)
        
        // Should default to 0 when no value is saved
        XCTAssertEqual(viewModel.selectedWeekIndex, 0)
    }
}
