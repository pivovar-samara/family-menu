import XCTest
import CoreData
@testable import FamilyMenuPlanner

class DishDetailsIntegrationTests: BaseIntegrationTest {
    var dishDetailsService: DishDetailsService!
    var viewModel: DishDetailsViewModel!
    
    override func setUp() {
        super.setUp()
        // Use real service with Core Data context for integration testing
        dishDetailsService = DishDetailsService(context: context)
        viewModel = DishDetailsViewModel(dishDetailsService: dishDetailsService)
    }
    
    override func tearDown() {
        dishDetailsService = nil
        viewModel = nil
        super.tearDown()
    }
    
    // Helper method to create test data
    private func createTestData() -> (dish: Dish, product: Product, mealType: MealType, unit: Unit, category: DishCategory) {
        // Create unit
        let unit = Unit(context: context)
        unit.name = "pcs"
        unit.sortOrder = 0
        
        // Create product
        let product = Product(context: context)
        product.name = "Test Product"
        product.unit = unit
        
        // Create meal type
        let mealType = MealType(context: context)
        mealType.name = "Breakfast"
        mealType.sortOrder = 0
        
        // Create dish category
        let category = DishCategory(context: context)
        category.name = "Main Course"
        category.sortOrder = 1
        
        // Create dish
        let dish = Dish(context: context)
        dish.name = "Test Dish"
        dish.details = "Test Details"
        
        try? context.save()
        context.refreshAllObjects()
        return (dish, product, mealType, unit, category)
    }
    
    // MARK: - Tests
    
    func testCreateNewDish() {
        // Create test data for validation requirements
        let (_, product, mealType, _, _) = createTestData()
        
        // Load new dish
        viewModel.loadDish()
        
        // Verify dish was created
        XCTAssertNotNil(viewModel.dish)
        
        // Set dish properties
        viewModel.dish?.name = "New Dish"
        viewModel.descriptionText = "New Description"
        // Manually sync description text to dish details (normally done by view's onChange)
        viewModel.dish?.details = viewModel.descriptionText
        
        // Add required data for validation to pass
        viewModel.addIngredient(product: product, quantity: 1.0)
        viewModel.toggleMealTypeSelection(mealType)
        
        // Save changes
        var successCalled = false
        viewModel.saveChanges {
            successCalled = true
        }
        
        // Verify changes were saved
        XCTAssertTrue(successCalled)
        
        // Verify dish exists in database
        let fetchRequest: NSFetchRequest<Dish> = Dish.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", "New Dish")
        
        do {
            let dishes = try context.fetch(fetchRequest)
            XCTAssertEqual(dishes.count, 1)
            XCTAssertEqual(dishes.first?.details, "New Description")
        } catch {
            XCTFail("Failed to fetch dish: \(error)")
        }
    }
    
    func testLoadExistingDish() {
        let (dish, _, _, _, _) = createTestData()
        
        // Create view model with existing dish
        viewModel = DishDetailsViewModel(dishDetailsService: dishDetailsService, dish: dish)
        
        // Load dish data
        viewModel.loadDish()
        viewModel.loadIngredients()
        viewModel.loadSelectedMealTypes()
        viewModel.loadSelectedCategory()
        
        // Verify dish data was loaded
        XCTAssertEqual(viewModel.dish?.name, "Test Dish")
        XCTAssertEqual(viewModel.dish?.details, "Test Details")
    }
    
    func testFetchDishCategories() {
        let (_, _, _, _, _) = createTestData()
        
        // Fetch categories using service
        let categories = dishDetailsService.fetchAllDishCategories()
        
        // Verify category was fetched
        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories.first?.name, "Main Course")
    }
    
    func testSetDishCategory() {
        let (dish, product, mealType, _, category) = createTestData()
        
        // Create view model with existing dish
        viewModel = DishDetailsViewModel(dishDetailsService: dishDetailsService, dish: dish)
        
        // Load dish data
        viewModel.loadDish()
        viewModel.loadSelectedCategory()
        
        // Set category
        viewModel.selectedCategory = category
        dish.category = category
        
        // Add required data for validation
        viewModel.addIngredient(product: product, quantity: 1.0)
        viewModel.toggleMealTypeSelection(mealType)
        
        // Save changes
        var successCalled = false
        viewModel.saveChanges {
            successCalled = true
        }
        
        // Verify changes were saved
        XCTAssertTrue(successCalled)
        
        // Refresh and verify category relationship
        context.refreshAllObjects()
        XCTAssertEqual(dish.category?.name, "Main Course")
    }
    
    func testAddIngredient() {
        let (dish, product, _, _, _) = createTestData()
        
        // Create view model with existing dish
        viewModel = DishDetailsViewModel(dishDetailsService: dishDetailsService, dish: dish)
        
        // Add ingredient
        viewModel.addIngredient(product: product, quantity: 2.5)
        
        // Save changes
        viewModel.saveChanges {}
        
        // Verify ingredient was added
        if let ingredients = dish.ingredientDetails as? Set<IngredientDetail> {
            XCTAssertEqual(ingredients.count, 1)
            XCTAssertEqual(ingredients.first?.product?.name, "Test Product")
            XCTAssertEqual(ingredients.first?.quantity, 2.5)
        } else {
            XCTFail("No ingredients found")
        }
    }
    
    func testDeleteIngredient() {
        let (dish, product, mealType, unit, _) = createTestData()
        
        // Create view model with existing dish
        viewModel = DishDetailsViewModel(dishDetailsService: dishDetailsService, dish: dish)
        
        // Add meal type first so validation will pass
        viewModel.toggleMealTypeSelection(mealType)
        
        // Add two distinct ingredients (different products) so normalization doesn't merge them
        viewModel.addIngredient(product: product, quantity: 1.0)
        let product2 = Product(context: context)
        product2.name = "Second Product"
        product2.unit = unit
        try? context.save()
        viewModel.addIngredient(product: product2, quantity: 2.0)
        
        // Load ingredients to sync selectedIngredients with Core Data relationship
        viewModel.loadIngredients()
        
        // Verify both ingredients were added
        XCTAssertEqual(viewModel.selectedIngredients.count, 2)
        
        // Delete first ingredient
        viewModel.deleteIngredient(at: IndexSet(integer: 0))
        
        // Verify one ingredient was removed from selectedIngredients
        XCTAssertEqual(viewModel.selectedIngredients.count, 1)
        
        // Ensure dish has a name for validation
        if dish.name?.isEmpty ?? true {
            dish.name = "Test Dish"
        }
        
        // Save changes
        var successCalled = false
        viewModel.saveChanges {
            successCalled = true
        }
        
        // Verify save was successful
        XCTAssertTrue(successCalled, "Save should have succeeded")
        
        // Refresh context to see updated relationships
        context.refreshAllObjects()
        
        // Verify only one ingredient remains in Core Data
        if let ingredients = dish.ingredientDetails as? Set<IngredientDetail> {
            XCTAssertEqual(ingredients.count, 1, "Should have exactly one ingredient remaining after deletion")
        }
    }
    
    func testToggleMealType() {
        let (dish, _, mealType, _, _) = createTestData()
        
        // Create view model with existing dish
        viewModel = DishDetailsViewModel(dishDetailsService: dishDetailsService, dish: dish)
        
        // Toggle meal type
        viewModel.toggleMealTypeSelection(mealType)
        
        // Save changes
        viewModel.saveChanges {}
        
        // Verify meal type was added
        if let mealTypes = dish.mealTypes as? Set<MealType> {
            XCTAssertEqual(mealTypes.count, 1)
            XCTAssertEqual(mealTypes.first?.name, "Breakfast")
        } else {
            XCTFail("No meal types found")
        }
        
        // Toggle meal type again
        viewModel.toggleMealTypeSelection(mealType)
        
        // Save changes
        viewModel.saveChanges {}
        
        // Verify meal type was removed
        if let mealTypes = dish.mealTypes as? Set<MealType> {
            XCTAssertTrue(mealTypes.isEmpty)
        }
    }
    
    func testValidationWithRealData() {
        let (dish, product, mealType, _, _) = createTestData()
        
        // Create view model with existing dish
        viewModel = DishDetailsViewModel(dishDetailsService: dishDetailsService, dish: dish)
        
        // Test empty name
        viewModel.dish?.name = ""
        var successCalled = false
        viewModel.saveChanges { successCalled = true }
        XCTAssertFalse(successCalled)
        XCTAssertNotNil(viewModel.validationError)
        
        // Test with name but no ingredients and meal types
        viewModel.dish?.name = "Test Dish"
        successCalled = false
        viewModel.saveChanges { successCalled = true }
        XCTAssertFalse(successCalled)
        XCTAssertNotNil(viewModel.validationError)
        
        // Add ingredient
        viewModel.addIngredient(product: product, quantity: 1.0)
        
        // Add meal type
        viewModel.toggleMealTypeSelection(mealType)
        
        // Test with all required fields
        successCalled = false
        viewModel.saveChanges { successCalled = true }
        XCTAssertTrue(successCalled)
        XCTAssertNil(viewModel.validationError)
    }
    
    func testRollback() {
        let (dish, _, _, _, _) = createTestData()
        
        // Create view model with existing dish
        viewModel = DishDetailsViewModel(dishDetailsService: dishDetailsService, dish: dish)
        
        // Modify dish
        let originalName = dish.name
        viewModel.dish?.name = "Modified Name"
        
        // Rollback changes
        viewModel.rollback()
        
        // Verify changes were rolled back
        XCTAssertEqual(dish.name, originalName)
    }
} 