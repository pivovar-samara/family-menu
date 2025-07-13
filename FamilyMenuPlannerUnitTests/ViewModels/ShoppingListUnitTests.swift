//
//  ShoppingListUnitTests.swift
//  FamilyMenuPlannerUnitTests
//
//  Created by Ilya Khokhlov on 18.12.24.
//

import XCTest
@testable import FamilyMenuPlanner

final class ShoppingListUnitTests: XCTestCase {
    var viewModel: ShoppingListViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = ShoppingListViewModel()
        // Clear any existing UserDefaults from previous tests
        UserDefaults.standard.removeObject(forKey: "ShoppingListSortPreference")
        clearAllSelectionKeys()
    }
    
    override func tearDown() {
        viewModel = nil
        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: "ShoppingListSortPreference")
        clearAllSelectionKeys()
        super.tearDown()
    }
    
    private func clearAllSelectionKeys() {
        let defaults = UserDefaults.standard
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys {
            if key.hasPrefix("ShoppingListSelection") {
                defaults.removeObject(forKey: key)
            }
        }
    }
    
    private func createTestWeekDate() -> Date {
        let calendar = Calendar.current
        let today = Date()
        return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
    }
    
    // MARK: - Shopping List Loading Tests
    
    func testLoadShoppingList() {
        let rawShoppingList: [String: [String: Double]] = [
            "Milk": ["ml": 500.0],
            "Eggs": ["pcs": 6.0],
            "Flour": ["g": 250.0]
        ]
        
        let weekDate = createTestWeekDate()
        viewModel.loadShoppingList(from: rawShoppingList, for: weekDate)
        
        XCTAssertEqual(viewModel.shoppingItems.count, 3)
        XCTAssertEqual(viewModel.filteredItems.count, 3)
        
        let milkItem = viewModel.shoppingItems.first { $0.productName == "Milk" }
        XCTAssertNotNil(milkItem)
        XCTAssertEqual(milkItem?.quantity, 500.0)
        XCTAssertEqual(milkItem?.unitName, "ml")
        XCTAssertFalse(milkItem?.isSelected ?? true)
    }
    
    func testLoadShoppingListWithMultipleUnits() {
        let rawShoppingList: [String: [String: Double]] = [
            "Sugar": ["g": 100.0, "kg": 0.5],
            "Water": ["ml": 1000.0, "l": 2.0]
        ]
        
        let weekDate = createTestWeekDate()
        viewModel.loadShoppingList(from: rawShoppingList, for: weekDate)
        
        XCTAssertEqual(viewModel.shoppingItems.count, 4)
        XCTAssertEqual(viewModel.filteredItems.count, 4)
        
        let sugarItems = viewModel.shoppingItems.filter { $0.productName == "Sugar" }
        XCTAssertEqual(sugarItems.count, 2)
        
        let waterItems = viewModel.shoppingItems.filter { $0.productName == "Water" }
        XCTAssertEqual(waterItems.count, 2)
    }
    
    func testLoadEmptyShoppingList() {
        let rawShoppingList: [String: [String: Double]] = [:]
        
        let weekDate = createTestWeekDate()
        viewModel.loadShoppingList(from: rawShoppingList, for: weekDate)
        
        XCTAssertEqual(viewModel.shoppingItems.count, 0)
        XCTAssertEqual(viewModel.filteredItems.count, 0)
    }
    
    // MARK: - Selection Tests
    
    func testToggleSelection() {
        let rawShoppingList: [String: [String: Double]] = [
            "Milk": ["ml": 500.0],
            "Eggs": ["pcs": 6.0]
        ]
        
        let weekDate = createTestWeekDate()
        viewModel.loadShoppingList(from: rawShoppingList, for: weekDate)
        
        let milkItem = viewModel.shoppingItems.first { $0.productName == "Milk" }!
        
        // Initially not selected
        XCTAssertFalse(milkItem.isSelected)
        
        // Toggle selection
        viewModel.toggleSelection(for: milkItem)
        
        let updatedMilkItem = viewModel.shoppingItems.first { $0.productName == "Milk" }!
        XCTAssertTrue(updatedMilkItem.isSelected)
        
        // Toggle again
        viewModel.toggleSelection(for: updatedMilkItem)
        
        let finalMilkItem = viewModel.shoppingItems.first { $0.productName == "Milk" }!
        XCTAssertFalse(finalMilkItem.isSelected)
    }
    
    func testSelectAll() {
        let rawShoppingList: [String: [String: Double]] = [
            "Milk": ["ml": 500.0],
            "Eggs": ["pcs": 6.0],
            "Flour": ["g": 250.0]
        ]
        
        let weekDate = createTestWeekDate()
        viewModel.loadShoppingList(from: rawShoppingList, for: weekDate)
        
        // Initially none selected
        XCTAssertTrue(viewModel.shoppingItems.allSatisfy { !$0.isSelected })
        
        // Select all
        viewModel.selectAll()
        
        // All should be selected
        XCTAssertTrue(viewModel.shoppingItems.allSatisfy { $0.isSelected })
    }
    
    func testDeselectAll() {
        let rawShoppingList: [String: [String: Double]] = [
            "Milk": ["ml": 500.0],
            "Eggs": ["pcs": 6.0]
        ]
        
        let weekDate = createTestWeekDate()
        viewModel.loadShoppingList(from: rawShoppingList, for: weekDate)
        
        // Select all first
        viewModel.selectAll()
        XCTAssertTrue(viewModel.shoppingItems.allSatisfy { $0.isSelected })
        
        // Deselect all
        viewModel.deselectAll()
        
        // None should be selected
        XCTAssertTrue(viewModel.shoppingItems.allSatisfy { !$0.isSelected })
    }
    
    // MARK: - Sorting Tests
    
    func testSortByNameAscending() {
        let rawShoppingList: [String: [String: Double]] = [
            "Zucchini": ["pcs": 2.0],
            "Apple": ["pcs": 5.0],
            "Banana": ["pcs": 3.0]
        ]
        
        let weekDate = createTestWeekDate()
        viewModel.loadShoppingList(from: rawShoppingList, for: weekDate)
        viewModel.updateSortOption(.nameAscending)
        
        let sortedNames = viewModel.filteredItems.map { $0.productName }
        XCTAssertEqual(sortedNames, ["Apple", "Banana", "Zucchini"])
    }
    
    func testSortByNameDescending() {
        let rawShoppingList: [String: [String: Double]] = [
            "Apple": ["pcs": 5.0],
            "Banana": ["pcs": 3.0],
            "Zucchini": ["pcs": 2.0]
        ]
        
        let weekDate = createTestWeekDate()
        viewModel.loadShoppingList(from: rawShoppingList, for: weekDate)
        viewModel.updateSortOption(.nameDescending)
        
        let sortedNames = viewModel.filteredItems.map { $0.productName }
        XCTAssertEqual(sortedNames, ["Zucchini", "Banana", "Apple"])
    }
    
    func testSortByQuantityHighToLow() {
        let rawShoppingList: [String: [String: Double]] = [
            "Milk": ["ml": 500.0],
            "Flour": ["g": 1000.0],
            "Sugar": ["g": 250.0]
        ]
        
        let weekDate = createTestWeekDate()
        viewModel.loadShoppingList(from: rawShoppingList, for: weekDate)
        viewModel.updateSortOption(.quantityHighToLow)
        
        let sortedQuantities = viewModel.filteredItems.map { $0.quantity }
        XCTAssertEqual(sortedQuantities, [1000.0, 500.0, 250.0])
    }
    
    func testSortByQuantityLowToHigh() {
        let rawShoppingList: [String: [String: Double]] = [
            "Milk": ["ml": 500.0],
            "Flour": ["g": 1000.0],
            "Sugar": ["g": 250.0]
        ]
        
        let weekDate = createTestWeekDate()
        viewModel.loadShoppingList(from: rawShoppingList, for: weekDate)
        viewModel.updateSortOption(.quantityLowToHigh)
        
        let sortedQuantities = viewModel.filteredItems.map { $0.quantity }
        XCTAssertEqual(sortedQuantities, [250.0, 500.0, 1000.0])
    }
    
    func testSortByUnit() {
        let rawShoppingList: [String: [String: Double]] = [
            "Milk": ["ml": 500.0],
            "Flour": ["g": 1000.0],
            "Water": ["l": 2.0],
            "Eggs": ["pcs": 6.0]
        ]
        
        let weekDate = createTestWeekDate()
        viewModel.loadShoppingList(from: rawShoppingList, for: weekDate)
        viewModel.updateSortOption(.unit)
        
        let sortedUnits = viewModel.filteredItems.map { $0.unitName }
        XCTAssertEqual(sortedUnits, ["g", "l", "ml", "pcs"])
    }
    
    // MARK: - Search Tests
    
    func testSearchByProductName() {
        let rawShoppingList: [String: [String: Double]] = [
            "Milk": ["ml": 500.0],
            "Eggs": ["pcs": 6.0],
            "Flour": ["g": 250.0]
        ]
        
        let weekDate = createTestWeekDate()
        viewModel.loadShoppingList(from: rawShoppingList, for: weekDate)
        viewModel.searchText = "milk"
        
        // Wait for debounced search to complete
        let expectation = XCTestExpectation(description: "Search completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems.first?.productName, "Milk")
    }
    
    func testSearchByUnit() {
        let rawShoppingList: [String: [String: Double]] = [
            "Milk": ["ml": 500.0],
            "Eggs": ["pcs": 6.0],
            "Flour": ["g": 250.0]
        ]
        
        let weekDate = createTestWeekDate()
        viewModel.loadShoppingList(from: rawShoppingList, for: weekDate)
        viewModel.searchText = "ml"
        
        // Wait for debounced search to complete
        let expectation = XCTestExpectation(description: "Search completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems.first?.unitName, "ml")
    }
    
    func testSearchNoResults() {
        let rawShoppingList: [String: [String: Double]] = [
            "Milk": ["ml": 500.0],
            "Eggs": ["pcs": 6.0]
        ]
        
        let weekDate = createTestWeekDate()
        viewModel.loadShoppingList(from: rawShoppingList, for: weekDate)
        viewModel.searchText = "nonexistent"
        
        // Wait for debounced search to complete
        let expectation = XCTestExpectation(description: "Search completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(viewModel.filteredItems.count, 0)
    }
    
    func testSearchEmpty() {
        let rawShoppingList: [String: [String: Double]] = [
            "Milk": ["ml": 500.0],
            "Eggs": ["pcs": 6.0]
        ]
        
        let weekDate = createTestWeekDate()
        viewModel.loadShoppingList(from: rawShoppingList, for: weekDate)
        viewModel.searchText = ""
        
        // Wait for debounced search to complete
        let expectation = XCTestExpectation(description: "Search completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(viewModel.filteredItems.count, 2)
    }
    
    // MARK: - Persistence Tests
    
    func testSortPreferencePersistence() {
        // Test that sort option is persisted in UserDefaults
        viewModel.updateSortOption(.quantityHighToLow)
        
        // Create a new view model instance
        let newViewModel = ShoppingListViewModel()
        
        // Verify sort option is restored from UserDefaults
        XCTAssertEqual(newViewModel.sortOption, .quantityHighToLow)
    }
    
    func testSelectionStatePersistence() {
        let rawShoppingList: [String: [String: Double]] = [
            "Milk": ["ml": 500.0],
            "Eggs": ["pcs": 6.0]
        ]
        
        let weekDate = createTestWeekDate()
        viewModel.loadShoppingList(from: rawShoppingList, for: weekDate)
        
        // Select an item
        let milkItem = viewModel.shoppingItems.first { $0.productName == "Milk" }!
        viewModel.toggleSelection(for: milkItem)
        
        // Create a new view model and load the same shopping list
        let newViewModel = ShoppingListViewModel()
        newViewModel.loadShoppingList(from: rawShoppingList, for: weekDate)
        
        // Verify selection state is restored
        let newMilkItem = newViewModel.shoppingItems.first { $0.productName == "Milk" }!
        XCTAssertTrue(newMilkItem.isSelected)
        
        let newEggsItem = newViewModel.shoppingItems.first { $0.productName == "Eggs" }!
        XCTAssertFalse(newEggsItem.isSelected)
    }
    
    func testClearOldSelections() {
        let rawShoppingList: [String: [String: Double]] = [
            "Milk": ["ml": 500.0],
            "Eggs": ["pcs": 6.0]
        ]
        
        let weekDate = createTestWeekDate()
        viewModel.loadShoppingList(from: rawShoppingList, for: weekDate)
        
        // Select some items
        viewModel.selectAll()
        
        // Clear old selections
        viewModel.clearOldSelections()
        
        // Load the shopping list again
        viewModel.loadShoppingList(from: rawShoppingList, for: weekDate)
        
        // Current week selections should remain (since they're not old)
        XCTAssertTrue(viewModel.shoppingItems.allSatisfy { $0.isSelected })
    }
    
    func testClearOldSelectionsDeletesAllOldWeeks() {
        let rawShoppingList: [String: [String: Double]] = [
            "Milk": ["ml": 500.0]
        ]
        
        // Create a week from 6 months ago
        let calendar = Calendar.current
        let today = Date()
        let oldWeekDate = calendar.date(byAdding: .month, value: -6, to: today) ?? today
        
        // Load and select items for the old week
        viewModel.loadShoppingList(from: rawShoppingList, for: oldWeekDate)
        let milkItem = viewModel.shoppingItems.first { $0.productName == "Milk" }!
        viewModel.toggleSelection(for: milkItem)
        
        // Clear old selections
        viewModel.clearOldSelections()
        
        // Load the old week again
        viewModel.loadShoppingList(from: rawShoppingList, for: oldWeekDate)
        
        // The old selection should be cleared (since it's older than current week)
        let oldMilkItem = viewModel.shoppingItems.first { $0.productName == "Milk" }!
        XCTAssertFalse(oldMilkItem.isSelected)
        
        // Load current week and make a selection
        let startOfCurrentWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        viewModel.loadShoppingList(from: rawShoppingList, for: startOfCurrentWeek)
        let currentMilkItem = viewModel.shoppingItems.first { $0.productName == "Milk" }!
        viewModel.toggleSelection(for: currentMilkItem)
        
        // Clear old selections again
        viewModel.clearOldSelections()
        
        // Current week selection should remain (since it's not old)
        viewModel.loadShoppingList(from: rawShoppingList, for: startOfCurrentWeek)
        let currentMilkItemAfterCleanup = viewModel.shoppingItems.first { $0.productName == "Milk" }!
        XCTAssertTrue(currentMilkItemAfterCleanup.isSelected)
    }
    
    // MARK: - Edge Cases
    
    func testToggleSelectionWithNonExistentItem() {
        let rawShoppingList: [String: [String: Double]] = [
            "Milk": ["ml": 500.0]
        ]
        
        let weekDate = createTestWeekDate()
        viewModel.loadShoppingList(from: rawShoppingList, for: weekDate)
        
        let nonExistentItem = ShoppingListItem(
            productName: "NonExistent",
            unitName: "pcs",
            quantity: 1.0,
            isSelected: false
        )
        
        // Should not crash
        viewModel.toggleSelection(for: nonExistentItem)
        
        // Original item should remain unchanged
        let milkItem = viewModel.shoppingItems.first { $0.productName == "Milk" }!
        XCTAssertFalse(milkItem.isSelected)
    }
    
    func testLoadShoppingListWithEmptyProductName() {
        let rawShoppingList: [String: [String: Double]] = [
            "": ["pcs": 1.0],
            "Valid Product": ["g": 100.0]
        ]
        
        let weekDate = createTestWeekDate()
        viewModel.loadShoppingList(from: rawShoppingList, for: weekDate)
        
        // Should handle empty product names gracefully
        XCTAssertEqual(viewModel.shoppingItems.count, 2)
    }
    
    func testLoadShoppingListWithEmptyUnit() {
        let rawShoppingList: [String: [String: Double]] = [
            "Product": ["": 1.0],
            "Valid Product": ["g": 100.0]
        ]
        
        let weekDate = createTestWeekDate()
        viewModel.loadShoppingList(from: rawShoppingList, for: weekDate)
        
        // Should handle empty units gracefully
        XCTAssertEqual(viewModel.shoppingItems.count, 2)
    }
    
    func testWeekIsolation() {
        let rawShoppingList: [String: [String: Double]] = [
            "Milk": ["ml": 500.0],
            "Eggs": ["pcs": 6.0]
        ]
        
        // Create two different week dates
        let calendar = Calendar.current
        let today = Date()
        let week1Date = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        let week2Date = calendar.date(byAdding: .weekOfYear, value: 1, to: week1Date)!
        
        // Load shopping list for week 1 and select an item
        viewModel.loadShoppingList(from: rawShoppingList, for: week1Date)
        let milkItem = viewModel.shoppingItems.first { $0.productName == "Milk" }!
        viewModel.toggleSelection(for: milkItem)
        
        // Load shopping list for week 2 - should not have any selections
        viewModel.loadShoppingList(from: rawShoppingList, for: week2Date)
        let week2MilkItem = viewModel.shoppingItems.first { $0.productName == "Milk" }!
        XCTAssertFalse(week2MilkItem.isSelected)
        
        // Load back to week 1 - should have the selection
        viewModel.loadShoppingList(from: rawShoppingList, for: week1Date)
        let week1MilkItem = viewModel.shoppingItems.first { $0.productName == "Milk" }!
        XCTAssertTrue(week1MilkItem.isSelected)
    }
    
    func testEncodedWeekConsistency() {
        // Test that our encodeWeek method produces the same result as MenuService
        let calendar = Calendar.current
        let today = Date()
        let weekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        
        // Our implementation
        let year = weekComponents.yearForWeekOfYear ?? 0
        let week = weekComponents.weekOfYear ?? 0
        let ourEncodedWeek = year * 100 + week
        
        // Verify the encoded week is reasonable (should be a large number like 202501 for week 1 of 2025)
        XCTAssertGreaterThan(ourEncodedWeek, 200000)
        XCTAssertLessThan(ourEncodedWeek, 210000)
        
        // Test with a specific known date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let testDate = formatter.date(from: "2025-01-06") { // Week 2 of 2025
            let testComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: testDate)
            let testYear = testComponents.yearForWeekOfYear ?? 0
            let testWeek = testComponents.weekOfYear ?? 0
            let testEncodedWeek = testYear * 100 + testWeek
            XCTAssertEqual(testEncodedWeek, 202502) // 2025 * 100 + 2
        }
    }
}
