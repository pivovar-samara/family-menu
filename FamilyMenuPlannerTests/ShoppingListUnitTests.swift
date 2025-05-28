//
//  ShoppingListUnitTests.swift
//  FamilyMenuPlanner
//
//  Created by Pivovar 63 on 27.05.25.
//

import XCTest
@testable import FamilyMenuPlanner

final class ShoppingListUnitTests: XCTestCase {
    // Helper to mimic the formattedDoubleForUnits logic
    func formattedDoubleForUnits(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }

    func testFormattedDoubleForUnits() {
        // Test whole numbers
        XCTAssertEqual(formattedDoubleForUnits(2.0), "2")
        XCTAssertEqual(formattedDoubleForUnits(100.0), "100")
        
        // Test decimals
        XCTAssertEqual(formattedDoubleForUnits(2.5), "2.50")
        XCTAssertEqual(formattedDoubleForUnits(0.333), "0.33")
        
        // Test edge cases
        XCTAssertEqual(formattedDoubleForUnits(0.0), "0")
        XCTAssertEqual(formattedDoubleForUnits(-1.5), "-1.50")
    }

    func testShoppingListSorting() {
        let shoppingList: [String: [String: Double]] = [
            "Banana": ["kg": 1.0],
            "Apple": ["kg": 2.0],
            "Carrot": ["pcs": 5.0],
            "Zucchini": ["kg": 0.5],
            "Milk": ["l": 1.0]
        ]
        
        let sorted = shoppingList.sorted(by: { $0.key < $1.key })
        let sortedKeys = sorted.map { $0.key }
        
        // Test alphabetical sorting
        XCTAssertEqual(sortedKeys, ["Apple", "Banana", "Carrot", "Milk", "Zucchini"])
        
        // Test that sorting preserves all entries
        XCTAssertEqual(sorted.count, shoppingList.count)
    }

    func testShoppingListEmpty() {
        let shoppingList: [String: [String: Double]] = [:]
        XCTAssertTrue(shoppingList.isEmpty)
        
        let nonEmptyList: [String: [String: Double]] = ["Apple": [:]]
        XCTAssertFalse(nonEmptyList.isEmpty)
    }

    func testShoppingListProductDetails() {
        let shoppingList: [String: [String: Double]] = [
            "Milk": ["l": 1.5],
            "Eggs": ["pcs": 12.0],
            "Flour": ["g": 500.0]
        ]
        
        // Test single product details
        let milk = shoppingList["Milk"]
        XCTAssertEqual(milk?["l"], 1.5)
        
        // Test multiple products
        XCTAssertEqual(shoppingList["Eggs"]?["pcs"], 12.0)
        XCTAssertEqual(shoppingList["Flour"]?["g"], 500.0)
        
        // Test non-existent product
        XCTAssertNil(shoppingList["NonExistent"])
        
        // Test non-existent unit
        XCTAssertNil(shoppingList["Milk"]?["kg"])
    }
    
    func testShoppingListMultipleUnits() {
        let shoppingList: [String: [String: Double]] = [
            "Sugar": ["g": 500.0, "kg": 1.5],
            "Water": ["ml": 500.0, "l": 2.0]
        ]
        
        // Test multiple units for same product
        let sugar = shoppingList["Sugar"]
        XCTAssertEqual(sugar?.count, 2)
        XCTAssertEqual(sugar?["g"], 500.0)
        XCTAssertEqual(sugar?["kg"], 1.5)
        
        // Test all units are preserved
        let water = shoppingList["Water"]
        XCTAssertEqual(water?.count, 2)
        XCTAssertEqual(water?["ml"], 500.0)
        XCTAssertEqual(water?["l"], 2.0)
    }
    
    func testShoppingListLocalization() {
        let shoppingList: [String: [String: Double]] = [
            "Milk".localized(): ["l".localized(): 1.5]
        ]
        
        // Test that keys and units can be localized
        XCTAssertNotNil(shoppingList["Milk".localized()])
        XCTAssertNotNil(shoppingList["Milk".localized()]?["l".localized()])
    }
}
