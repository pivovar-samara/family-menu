//
//  ShoppingListIntegrationTests.swift
//  FamilyMenuPlannerUnitTests
//
//  Created by Pivovar 63 on 28.05.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

class ShoppingListIntegrationTests: BaseIntegrationTest {
    var menuService: MenuService!
    var viewModel: MenuViewModel!
    var shoppingListViewModel: ShoppingListViewModel!
    
    override func setUp() {
        super.setUp()
        menuService = MenuService(context: context)
        viewModel = MenuViewModel(menuService: menuService)
        shoppingListViewModel = ShoppingListViewModel()
        
        // Clear any existing shopping list selections to ensure test isolation
        shoppingListViewModel.clearAllSelections()
    }
    
    override func tearDown() {
        menuService = nil
        viewModel = nil
        shoppingListViewModel = nil
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
    
    // MARK: - Quantity Change Integration Tests
    
    func testQuantityChangeResetsSelectionInShoppingList() {
        let (products, _, dishes) = createTestDataWithKnownQuantities()
        let weekDate = Date()
        
        // Add dishes to menu
        try? menuService.replaceDishes(for: "Monday", mealType: "Breakfast", selectedWeekDate: weekDate, with: dishes)
        try? context.save()
        context.refreshAllObjects()
        
        // Load the menu into the view model
        viewModel.loadMenu(for: 0)
        
        // Generate initial shopping list
        let initialShoppingList = viewModel.generateShoppingList()
        
        // Load shopping list and select an item
        shoppingListViewModel.loadShoppingList(from: initialShoppingList, for: weekDate)
        let eggsItem = shoppingListViewModel.shoppingItems.first { $0.productName == "Eggs" }!
        shoppingListViewModel.toggleSelection(for: eggsItem)
        
        // Verify selection by fetching updated item
        let selectedEggsItem = shoppingListViewModel.shoppingItems.first { $0.productName == "Eggs" }!
        XCTAssertTrue(selectedEggsItem.isSelected)
        
        // Modify ingredient quantity in Core Data
        if let ingredientDetail = dishes.first?.ingredientDetails?.first(where: { ($0 as? IngredientDetail)?.product?.name == "Eggs" }) as? IngredientDetail {
            ingredientDetail.quantity = 4 // Changed from 2 to 4
            try? context.save()
            context.refreshAllObjects()
        }
        
        // Reload menu and generate updated shopping list
        viewModel.loadMenu(for: 0)
        let updatedShoppingList = viewModel.generateShoppingList()
        
        // Create new shopping list view model and load updated list
        let newShoppingListViewModel = ShoppingListViewModel()
        newShoppingListViewModel.loadShoppingList(from: updatedShoppingList, for: weekDate)
        
        // Eggs should no longer be selected due to quantity change
        let updatedEggsItem = newShoppingListViewModel.shoppingItems.first { $0.productName == "Eggs" }!
        XCTAssertFalse(updatedEggsItem.isSelected)
        XCTAssertEqual(updatedEggsItem.quantity, 4) // Verify quantity was updated
        
        // Flour should still be unselected (no change)
        let flourItem = newShoppingListViewModel.shoppingItems.first { $0.productName == "Flour" }!
        XCTAssertFalse(flourItem.isSelected)
        XCTAssertEqual(flourItem.quantity, 200) // Verify quantity unchanged
    }
    
    func testQuantityChangePreservesOtherSelectionsInShoppingList() {
        let (products, _, dishes) = createTestDataWithKnownQuantities()
        let weekDate = Date()
        
        // Add dishes to menu
        try? menuService.replaceDishes(for: "Monday", mealType: "Breakfast", selectedWeekDate: weekDate, with: dishes)
        try? context.save()
        context.refreshAllObjects()
        
        // Load the menu into the view model
        viewModel.loadMenu(for: 0)
        
        // Generate initial shopping list
        let initialShoppingList = viewModel.generateShoppingList()
        
        // Load shopping list and select both items
        shoppingListViewModel.loadShoppingList(from: initialShoppingList, for: weekDate)
        let eggsItem = shoppingListViewModel.shoppingItems.first { $0.productName == "Eggs" }!
        let flourItem = shoppingListViewModel.shoppingItems.first { $0.productName == "Flour" }!
        
        shoppingListViewModel.toggleSelection(for: eggsItem)
        shoppingListViewModel.toggleSelection(for: flourItem)
        
        // Verify selections by fetching updated items
        let selectedEggsItem = shoppingListViewModel.shoppingItems.first { $0.productName == "Eggs" }!
        let selectedFlourItem = shoppingListViewModel.shoppingItems.first { $0.productName == "Flour" }!
        XCTAssertTrue(selectedEggsItem.isSelected)
        XCTAssertTrue(selectedFlourItem.isSelected)
        
        // Modify only eggs ingredient quantity in Core Data
        if let ingredientDetail = dishes.first?.ingredientDetails?.first(where: { ($0 as? IngredientDetail)?.product?.name == "Eggs" }) as? IngredientDetail {
            ingredientDetail.quantity = 3 // Changed from 2 to 3
            try? context.save()
            context.refreshAllObjects()
        }
        
        // Reload menu and generate updated shopping list
        viewModel.loadMenu(for: 0)
        let updatedShoppingList = viewModel.generateShoppingList()
        
        // Create new shopping list view model and load updated list
        let newShoppingListViewModel = ShoppingListViewModel()
        newShoppingListViewModel.loadShoppingList(from: updatedShoppingList, for: weekDate)
        
        // Eggs should no longer be selected (quantity changed)
        let updatedEggsItem = newShoppingListViewModel.shoppingItems.first { $0.productName == "Eggs" }!
        XCTAssertFalse(updatedEggsItem.isSelected)
        XCTAssertEqual(updatedEggsItem.quantity, 3)
        
        // Flour should still be selected (quantity unchanged)
        let updatedFlourItem = newShoppingListViewModel.shoppingItems.first { $0.productName == "Flour" }!
        XCTAssertTrue(updatedFlourItem.isSelected)
        XCTAssertEqual(updatedFlourItem.quantity, 200)
    }
    
    func testSmallQuantityChangesDoNotResetSelectionInShoppingList() {
        let (products, _, dishes) = createTestDataWithKnownQuantities()
        let weekDate = Date()
        
        // Add dishes to menu
        try? menuService.replaceDishes(for: "Monday", mealType: "Breakfast", selectedWeekDate: weekDate, with: dishes)
        try? context.save()
        context.refreshAllObjects()
        
        // Load the menu into the view model
        viewModel.loadMenu(for: 0)
        
        // Generate initial shopping list
        let initialShoppingList = viewModel.generateShoppingList()
        
        // Load shopping list and select an item
        shoppingListViewModel.loadShoppingList(from: initialShoppingList, for: weekDate)
        let eggsItem = shoppingListViewModel.shoppingItems.first { $0.productName == "Eggs" }!
        shoppingListViewModel.toggleSelection(for: eggsItem)
        
        // Verify selection by fetching updated item
        let selectedEggsItem = shoppingListViewModel.shoppingItems.first { $0.productName == "Eggs" }!
        XCTAssertTrue(selectedEggsItem.isSelected)
        
        // Modify ingredient quantity with very small change in Core Data
        if let ingredientDetail = dishes.first?.ingredientDetails?.first(where: { ($0 as? IngredientDetail)?.product?.name == "Eggs" }) as? IngredientDetail {
            ingredientDetail.quantity = 2.0001 // Very small change, should not reset
            try? context.save()
            context.refreshAllObjects()
        }
        
        // Reload menu and generate updated shopping list
        viewModel.loadMenu(for: 0)
        let updatedShoppingList = viewModel.generateShoppingList()
        
        // Create new shopping list view model and load updated list
        let newShoppingListViewModel = ShoppingListViewModel()
        newShoppingListViewModel.loadShoppingList(from: updatedShoppingList, for: weekDate)
        
        // Eggs should still be selected due to small quantity change
        let updatedEggsItem = newShoppingListViewModel.shoppingItems.first { $0.productName == "Eggs" }!
        XCTAssertTrue(updatedEggsItem.isSelected)
        XCTAssertEqual(updatedEggsItem.quantity, 2.0001)
    }
    
    func testQuantityChangeWithMultipleDishes() {
        // Create test data with multiple dishes
        let pieces = createUnit(name: "pcs")
        let grams = createUnit(name: "g", sortOrder: 1)
        
        let eggs = createProduct(name: "Eggs", unit: pieces)
        let flour = createProduct(name: "Flour", unit: grams)
        
        let breakfast = createMealType(name: "Breakfast")
        let lunch = createMealType(name: "Lunch")
        
        // Create two dishes with same ingredients
        let pancakes = createDish(name: "Pancakes", mealTypes: Set([breakfast]))
        let cake = createDish(name: "Cake", mealTypes: Set([lunch]))
        
        // Add eggs to both dishes
        let ingredient1 = IngredientDetail(context: context)
        ingredient1.dish = pancakes
        ingredient1.product = eggs
        ingredient1.quantity = 2
        
        let ingredient2 = IngredientDetail(context: context)
        ingredient2.dish = cake
        ingredient2.product = eggs
        ingredient2.quantity = 3
        
        // Add flour to pancakes only
        let ingredient3 = IngredientDetail(context: context)
        ingredient3.dish = pancakes
        ingredient3.product = flour
        ingredient3.quantity = 200
        
        saveContext()
        
        let weekDate = Date()
        
        // Add dishes to menu
        try? menuService.replaceDishes(for: "Monday", mealType: "Breakfast", selectedWeekDate: weekDate, with: [pancakes])
        try? menuService.replaceDishes(for: "Monday", mealType: "Lunch", selectedWeekDate: weekDate, with: [cake])
        try? context.save()
        context.refreshAllObjects()
        
        // Load the menu into the view model
        viewModel.loadMenu(for: 0)
        
        // Generate initial shopping list (eggs should be 5 total: 2 + 3)
        let initialShoppingList = viewModel.generateShoppingList()
        
        // Load shopping list and select eggs
        shoppingListViewModel.loadShoppingList(from: initialShoppingList, for: weekDate)
        let eggsItem = shoppingListViewModel.shoppingItems.first { $0.productName == "Eggs" }!
        shoppingListViewModel.toggleSelection(for: eggsItem)
        
        // Verify selection by fetching updated item
        let selectedEggsItem = shoppingListViewModel.shoppingItems.first { $0.productName == "Eggs" }!
        XCTAssertTrue(selectedEggsItem.isSelected)
        XCTAssertEqual(selectedEggsItem.quantity, 5) // 2 + 3
        
        // Modify quantity in one dish only
        ingredient1.quantity = 4 // Changed from 2 to 4
        try? context.save()
        context.refreshAllObjects()
        
        // Reload menu and generate updated shopping list
        viewModel.loadMenu(for: 0)
        let updatedShoppingList = viewModel.generateShoppingList()
        
        // Create new shopping list view model and load updated list
        let newShoppingListViewModel = ShoppingListViewModel()
        newShoppingListViewModel.loadShoppingList(from: updatedShoppingList, for: weekDate)
        
        // Eggs should no longer be selected (quantity changed from 5 to 7)
        let updatedEggsItem = newShoppingListViewModel.shoppingItems.first { $0.productName == "Eggs" }!
        XCTAssertFalse(updatedEggsItem.isSelected)
        XCTAssertEqual(updatedEggsItem.quantity, 7) // 4 + 3
        
        // Flour should still be unselected (no change)
        let flourItem = newShoppingListViewModel.shoppingItems.first { $0.productName == "Flour" }!
        XCTAssertFalse(flourItem.isSelected)
        XCTAssertEqual(flourItem.quantity, 200)
    }
} 
