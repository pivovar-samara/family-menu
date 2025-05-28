//
//  MenuIntegrationTests.swift
//  FamilyMenuPlannerTests
//
//  Created by Pivovar 63 on 28.05.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

class MenuIntegrationTests: XCTestCase {
    var context: NSManagedObjectContext!
    var menuService: MenuService!
    var viewModel: MenuViewModel!
    
    override func setUp() {
        super.setUp()
        context = TestCoreDataStack.shared.viewContext
        menuService = MenuService(context: context)
        viewModel = MenuViewModel(menuService: menuService)
        
        // Clean up any existing data
        cleanUpTestData()
    }
    
    override func tearDown() {
        cleanUpTestData()
        context = nil
        menuService = nil
        viewModel = nil
        super.tearDown()
    }
    
    private func cleanUpTestData() {
        let entities = ["Menu", "Dish", "MealType", "Product", "Unit", "IngredientDetail"]
        
        for entityName in entities {
            let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: entityName)
            do {
                let objects = try context.fetch(fetchRequest)
                for object in objects {
                    context.delete(object)
                }
            } catch {
                print("Error cleaning up \(entityName): \(error)")
            }
        }
        
        do {
            try context.save()
        } catch {
            print("Error saving context after cleanup: \(error)")
        }
    }
    
    // Helper method to create test data
    private func createTestData() {
        // Create meal types
        let breakfast = createMealType(name: "Breakfast", sortOrder: 0)
        let lunch = createMealType(name: "Lunch", sortOrder: 1)
        let dinner = createMealType(name: "Dinner", sortOrder: 2)
        
        // Create units
        let pieces = createUnit(name: "pcs", sortOrder: 0)
        let grams = createUnit(name: "g", sortOrder: 1)
        
        // Create products
        let eggs = createProduct(name: "Eggs", unit: pieces)
        let bread = createProduct(name: "Bread", unit: grams)
        let chicken = createProduct(name: "Chicken", unit: grams)
        
        // Create dishes with ingredients
        let omelette = createDish(name: "Omelette", mealTypes: [breakfast])
        createIngredient(dish: omelette, product: eggs, quantity: 2)
        
        let sandwich = createDish(name: "Sandwich", mealTypes: [breakfast, lunch])
        createIngredient(dish: sandwich, product: bread, quantity: 200)
        
        let chickenDish = createDish(name: "Grilled Chicken", mealTypes: [lunch, dinner])
        createIngredient(dish: chickenDish, product: chicken, quantity: 300)
        
        try? context.save()
    }
    
    private func createMealType(name: String, sortOrder: Int16) -> MealType {
        let mealType = MealType(context: context)
        mealType.name = name
        mealType.sortOrder = sortOrder
        return mealType
    }
    
    private func createUnit(name: String, sortOrder: Int16) -> Unit {
        let unit = Unit(context: context)
        unit.name = name
        unit.sortOrder = sortOrder
        return unit
    }
    
    private func createProduct(name: String, unit: Unit) -> Product {
        let product = Product(context: context)
        product.name = name
        product.unit = unit
        return product
    }
    
    private func createDish(name: String, mealTypes: [MealType]) -> Dish {
        let dish = Dish(context: context)
        dish.name = name
        dish.mealTypes = NSSet(array: mealTypes)
        return dish
    }
    
    private func createIngredient(dish: Dish, product: Product, quantity: Double) {
        let ingredient = IngredientDetail(context: context)
        ingredient.dish = dish
        ingredient.product = product
        ingredient.quantity = quantity
    }
    
    // MARK: - Tests
    
    func testFetchMenuForWeek() {
        createTestData()
        
        // Generate menu for current week
        menuService.generateMenu(for: Date())
        
        // Fetch menu
        let menu = menuService.fetchMenu(for: 0)
        
        // Verify structure
        XCTAssertEqual(menu.count, 7) // 7 days in a week
        XCTAssertEqual(menu[0].dailyMeals.count, 3) // 3 meal types
        
        // Verify meal types are in correct order
        XCTAssertEqual(menu[0].dailyMeals[0].meal, "Breakfast")
        XCTAssertEqual(menu[0].dailyMeals[1].meal, "Lunch")
        XCTAssertEqual(menu[0].dailyMeals[2].meal, "Dinner")
    }
    
    func testGenerateMenu() {
        createTestData()
        
        // Generate menu
        menuService.generateMenu(for: Date())
        
        // Fetch and verify
        let menu = menuService.fetchMenu(for: 0)
        XCTAssertFalse(menu.isEmpty)
        
        // Verify dishes are assigned to appropriate meal types
        for dailyMenu in menu {
            for dailyMeal in dailyMenu.dailyMeals {
                if let dish = dailyMeal.dishes.first {
                    let mealTypes = dish.mealTypes as? Set<MealType> ?? []
                    XCTAssertTrue(mealTypes.contains(where: { $0.name == dailyMeal.meal }))
                }
            }
        }
    }
    
    func testReplaceDishes() {
        createTestData()
        menuService.generateMenu(for: Date())
        
        // Create a new dish for replacement
        let newDish = createDish(name: "New Dish", mealTypes: [createMealType(name: "Breakfast", sortOrder: 0)])
        
        // Replace dishes
        try? menuService.replaceDishes(for: "Monday", mealType: "Breakfast", selectedWeekDate: Date(), with: [newDish])
        
        // Verify replacement
        let menu = menuService.fetchMenu(for: 0)
        let mondayBreakfast = menu.first { $0.day == "Monday" }?.dailyMeals.first { $0.meal == "Breakfast" }
        XCTAssertEqual(mondayBreakfast?.dishes.first?.name, "New Dish")
    }
    
    func testClearMealType() {
        createTestData()
        menuService.generateMenu(for: Date())
        
        // Clear breakfast for Monday
        try? menuService.clearMealType(for: "Monday", selectedWeekDate: Date(), mealType: "Breakfast")
        
        // Verify clearing
        let menu = menuService.fetchMenu(for: 0)
        let mondayBreakfast = menu.first { $0.day == "Monday" }?.dailyMeals.first { $0.meal == "Breakfast" }
        XCTAssertTrue(mondayBreakfast?.dishes.isEmpty ?? false)
    }
    
    func testRemoveOldWeeks() {
        createTestData()
        
        // Generate menu for current week
        menuService.generateMenu(for: Date())
        
        // Remove old weeks
        menuService.removeOldWeeks()
        
        // Verify current week's menu still exists
        let menu = menuService.fetchMenu(for: 0)
        XCTAssertFalse(menu.isEmpty)
    }
    
    func testShoppingListGeneration() {
        // Create test data with known relationships
        let breakfast = createMealType(name: "Breakfast", sortOrder: 0)
        let pieces = createUnit(name: "pcs", sortOrder: 0)
        let eggs = createProduct(name: "Eggs", unit: pieces)
        
        // Create dish with ingredient
        let omelette = createDish(name: "Omelette", mealTypes: [breakfast])
        createIngredient(dish: omelette, product: eggs, quantity: 2)
        
        // Save and verify initial setup
        try? context.save()
        
        // Verify dish relationships
        XCTAssertNotNil(omelette.mealTypes, "Dish should have meal types")
        XCTAssertEqual((omelette.mealTypes as? Set<MealType>)?.count, 1, "Dish should have one meal type")
        
        // Verify ingredient relationships
        let ingredients = omelette.ingredientDetails as? Set<IngredientDetail>
        XCTAssertNotNil(ingredients, "Dish should have ingredients")
        XCTAssertEqual(ingredients?.count, 1, "Dish should have one ingredient")
        
        let ingredient = ingredients?.first
        XCTAssertNotNil(ingredient, "Ingredient should exist")
        XCTAssertEqual(ingredient?.quantity, 2, "Ingredient should have quantity 2")
        XCTAssertEqual(ingredient?.product?.name, "Eggs", "Ingredient should be eggs")
        XCTAssertEqual(ingredient?.product?.unit?.name, "pcs", "Eggs should be measured in pieces")
        
        // Create menu entry for Monday breakfast
        let weekComponents = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let encodedWeek = encodeWeek(weekComponents)
        
        let menu = Menu(context: context)
        menu.day = "Monday"
        menu.mealType = "Breakfast"
        menu.calendarWeek = Int32(encodedWeek)
        menu.dishes = NSSet(array: [omelette])
        
        // Save and verify menu setup
        try? context.save()
        
        // Refresh the context to ensure all relationships are properly loaded
        context.refreshAllObjects()
        
        // Load the menu into the view model
        viewModel.loadMenu(for: 0)
        
        // Verify menu was created correctly
        let menuFetchRequest: NSFetchRequest<Menu> = Menu.fetchRequest()
        menuFetchRequest.predicate = NSPredicate(format: "day == %@ AND mealType == %@ AND calendarWeek == %d", 
                                               "Monday", "Breakfast", encodedWeek)
        let fetchedMenus = try? context.fetch(menuFetchRequest)
        XCTAssertNotNil(fetchedMenus, "Should be able to fetch menus")
        XCTAssertEqual(fetchedMenus?.count, 1, "Should have one menu entry")
        XCTAssertEqual(fetchedMenus?.first?.dishes?.count, 1, "Menu should have one dish")
        
        // Verify through service
        let fetchedMenu = menuService.fetchMenu(for: 0)
        print("Fetched Menu: \(fetchedMenu)")
        
        let mondayBreakfast = fetchedMenu.first { $0.day == "Monday" }?.dailyMeals.first { $0.meal == "Breakfast" }
        XCTAssertNotNil(mondayBreakfast, "Monday breakfast should exist")
        XCTAssertEqual(mondayBreakfast?.dishes.count, 1, "Should have one dish")
        XCTAssertEqual(mondayBreakfast?.dishes.first?.name, "Omelette", "Should be Omelette")
        
        // Debug print dish and its ingredients
        if let dish = mondayBreakfast?.dishes.first {
            print("Dish: \(dish.name ?? "")")
            print("Ingredients: \(dish.ingredientDetails?.count ?? 0)")
            if let ingredients = dish.ingredientDetails as? Set<IngredientDetail> {
                for ingredient in ingredients {
                    print("- \(ingredient.quantity) \(ingredient.product?.unit?.name ?? "") of \(ingredient.product?.name ?? "")")
                }
            }
        }
        
        // Generate shopping list
        let shoppingList = viewModel.generateShoppingList()
        print("Shopping List Contents: \(shoppingList)")
        
        // Verify shopping list
        XCTAssertFalse(shoppingList.isEmpty, "Shopping list should not be empty")
        XCTAssertEqual(shoppingList["Eggs"]?["pcs"], 2, "Should have 2 eggs in the shopping list")
    }
    
    private func encodeWeek(_ weekComponents: DateComponents) -> Int {
        let year = weekComponents.yearForWeekOfYear ?? 0
        let week = weekComponents.weekOfYear ?? 0
        return year * 100 + week
    }
    
    func testMenuPersistence() {
        createTestData()
        menuService.generateMenu(for: Date())
        
        // Create a new context
        let newContext = TestCoreDataStack.shared.persistentContainer.newBackgroundContext()
        let newMenuService = MenuService(context: newContext)
        
        // Fetch menu in new context
        let menu = newMenuService.fetchMenu(for: 0)
        XCTAssertFalse(menu.isEmpty)
    }
} 