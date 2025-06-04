//
//  ShoppingListIntegrationTests.swift
//  FamilyMenuPlannerTests
//
//  Created by Pivovar 63 on 28.05.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

class ShoppingListIntegrationTests: BaseIntegrationTest {
    var menuService: MenuService!
    var viewModel: MenuViewModel!
    
    override func setUp() {
        super.setUp()
        menuService = MenuService(context: context)
        viewModel = MenuViewModel(menuService: menuService)
    }
    
    override func tearDown() {
        menuService = nil
        viewModel = nil
        super.tearDown()
    }
    
    // Helper method to create test data with specific quantities
    private func createTestDataWithKnownQuantities() -> ([Product], [Unit], [Dish]) {
        // Create units
        let pieces = createUnit(name: "pcs")
        let grams = createUnit(name: "g", sortOrder: 1)
        
        // Create products
        let eggs = createProduct(name: "Eggs", unit: pieces)
        let flour = createProduct(name: "Flour", unit: grams)
        
        // Create meal type
        let breakfast = createMealType(name: "Breakfast")
        
        // Create dishes with known quantities
        let pancakes = createDish(name: "Pancakes", mealTypes: Set([breakfast]))
        
        let ingredient1 = IngredientDetail(context: context)
        ingredient1.dish = pancakes
        ingredient1.product = eggs
        ingredient1.quantity = 2
        
        let ingredient2 = IngredientDetail(context: context)
        ingredient2.dish = pancakes
        ingredient2.product = flour
        ingredient2.quantity = 200
        
        saveContext()
        
        return ([eggs, flour], [pieces, grams], [pancakes])
    }
    
    // MARK: - Tests
    
    func testShoppingListCalculation() {
        let (products, _, dishes) = createTestDataWithKnownQuantities()
        
        // Add dishes to menu
        let weekDate = Date()
        try? menuService.replaceDishes(for: "Monday", mealType: "Breakfast", selectedWeekDate: weekDate, with: dishes)
        
        // Save and refresh context to ensure all relationships are properly loaded
        try? context.save()
        context.refreshAllObjects()
        
        // Load the menu into the view model
        viewModel.loadMenu(for: 0)
        
        // Generate shopping list
        let shoppingList = viewModel.generateShoppingList()
        
        // Verify quantities
        XCTAssertEqual(shoppingList[products[0].name ?? ""]?[products[0].unit?.name ?? ""], 2) // Eggs
        XCTAssertEqual(shoppingList[products[1].name ?? ""]?[products[1].unit?.name ?? ""], 200) // Flour
    }
    
    func testShoppingListAggregation() {
        let (products, _, dishes) = createTestDataWithKnownQuantities()
        
        // Add same dishes to multiple days
        let weekDate = Date()
        try? menuService.replaceDishes(for: "Monday", mealType: "Breakfast", selectedWeekDate: weekDate, with: dishes)
        try? menuService.replaceDishes(for: "Tuesday", mealType: "Breakfast", selectedWeekDate: weekDate, with: dishes)
        
        // Save and refresh context to ensure all relationships are properly loaded
        try? context.save()
        context.refreshAllObjects()
        
        // Load the menu into the view model
        viewModel.loadMenu(for: 0)
        
        // Generate shopping list
        let shoppingList = viewModel.generateShoppingList()
        
        // Verify quantities are summed
        XCTAssertEqual(shoppingList[products[0].name ?? ""]?[products[0].unit?.name ?? ""], 4) // Eggs (2 * 2)
        XCTAssertEqual(shoppingList[products[1].name ?? ""]?[products[1].unit?.name ?? ""], 400) // Flour (200 * 2)
    }
    
    func testShoppingListWithEmptyMenu() {
        // Generate shopping list without any menu items
        let shoppingList = viewModel.generateShoppingList()
        
        // Verify shopping list is empty
        XCTAssertTrue(shoppingList.isEmpty)
    }
    
    func testShoppingListWithMissingProducts() {
        let (_, _, dishes) = createTestDataWithKnownQuantities()
        
        // Delete products but keep dishes
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "Product")
        if let products = try? context.fetch(fetchRequest) {
            products.forEach { context.delete($0) }
            try? context.save()
        }
        
        // Add dishes to menu
        let weekDate = Date()
        try? menuService.replaceDishes(for: "Monday", mealType: "Breakfast", selectedWeekDate: weekDate, with: dishes)
        
        // Generate shopping list
        let shoppingList = viewModel.generateShoppingList()
        
        // Verify shopping list handles missing products gracefully
        XCTAssertTrue(shoppingList.isEmpty)
    }
    
    func testShoppingListWithDifferentUnits() {
        // Create products with different units
        let ml = Unit(context: context)
        ml.name = "ml"
        
        let product = Product(context: context)
        product.name = "Milk"
        product.unit = ml
        
        let breakfast = MealType(context: context)
        breakfast.name = "Breakfast"
        
        let dish = Dish(context: context)
        dish.name = "Cereal"
        dish.mealTypes = NSSet(array: [breakfast])
        
        let ingredient = IngredientDetail(context: context)
        ingredient.dish = dish
        ingredient.product = product
        ingredient.quantity = 250
        
        try? context.save()
        
        // Add dish to menu
        let weekDate = Date()
        try? menuService.replaceDishes(for: "Monday", mealType: "Breakfast", selectedWeekDate: weekDate, with: [dish])
        
        // Save and refresh context to ensure all relationships are properly loaded
        try? context.save()
        context.refreshAllObjects()
        
        // Load the menu into the view model
        viewModel.loadMenu(for: 0)
        
        // Generate shopping list
        let shoppingList = viewModel.generateShoppingList()
        
        // Verify correct unit is used
        XCTAssertEqual(shoppingList["Milk"]?["ml"], 250)
    }
} 