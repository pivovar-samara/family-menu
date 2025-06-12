//
//  SimpleMenuIntegrationTests.swift
//  FamilyMenuPlannerIntegrationTests
//
//  Created by AI Assistant on 21.01.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

final class SimpleMenuIntegrationTests: BaseIntegrationTest {
    
    func testMenuServiceCreation() {
        let menuService = MenuService(context: context)
        XCTAssertNotNil(menuService)
    }
    
    func testMenuViewModelCreation() {
        let menuService = MenuService(context: context)
        let viewModel = MenuViewModel(menuService: menuService)
        XCTAssertNotNil(viewModel)
    }
    
    func testBasicEntityCreation() {
        // Test creating basic entities
        let unit = createUnit(name: "test_kg", sortOrder: 1)
        XCTAssertEqual(unit.name, "test_kg")
        
        let mealType = createMealType(name: "test_breakfast", sortOrder: 1)
        XCTAssertEqual(mealType.name, "test_breakfast")
        
        let product = createProduct(name: "test_product", unit: unit)
        XCTAssertEqual(product.name, "test_product")
        XCTAssertEqual(product.unit, unit)
    }
    
    func testMenuServiceFetch() {
        let menuService = MenuService(context: context)
        
        // Should be able to fetch menu even when empty
        let menu = menuService.fetchMenu(for: 0)
        XCTAssertNotNil(menu)
    }
}