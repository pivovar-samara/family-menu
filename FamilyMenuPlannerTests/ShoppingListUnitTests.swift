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
        XCTAssertEqual(formattedDoubleForUnits(2.0), "2")
        XCTAssertEqual(formattedDoubleForUnits(2.5), "2.50")
        XCTAssertEqual(formattedDoubleForUnits(0.333), "0.33")
    }

    func testShoppingListSorting() {
        let shoppingList: [String: [String: Double]] = [
            "Banana": ["kg": 1.0],
            "Apple": ["kg": 2.0],
            "Carrot": ["pcs": 5.0]
        ]
        let sorted = shoppingList.sorted(by: { $0.key < $1.key })
        let sortedKeys = sorted.map { $0.key }
        XCTAssertEqual(sortedKeys, ["Apple", "Banana", "Carrot"])
    }

    func testShoppingListEmpty() {
        let shoppingList: [String: [String: Double]] = [:]
        XCTAssertTrue(shoppingList.isEmpty)
    }

    func testShoppingListProductDetails() {
        let shoppingList: [String: [String: Double]] = [
            "Milk": ["l": 1.5]
        ]
        let product = shoppingList.first!
        let productName = product.key
        let details = product.value
        let quantity = details.values.first ?? 0.0
        let unit = details.keys.first ?? ""
        XCTAssertEqual(productName, "Milk")
        XCTAssertEqual(quantity, 1.5)
        XCTAssertEqual(unit, "l")
    }
}
