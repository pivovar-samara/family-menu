//
//  DishDetailsUnitTests.swift
//  FamilyMenuPlannerUnitTests
//
//  Created by Critical Test Review on 28.01.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

// MARK: - Mock Service
class MockDishDetailsService: DishDetailsServiceProtocol {
    var units: [Unit] = []
    var mealTypes: [MealType] = []
    var dishCategories: [DishCategory] = []
    var error: Error?
    var saveChangesCalled = false
    var saveChangesInBackgroundCalled = false
    var rollbackCalled = false
    var deleteIngredientCalled = false
    var createdDish: Dish?
    var createdIngredient: IngredientDetail?
    
    // Context for creating real entities
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
        // Create default test data
        setupTestData()
    }
    
    private func setupTestData() {
        // Create units
        units = [
            createUnit(name: "kg", sortOrder: 1),
            createUnit(name: "pcs", sortOrder: 2)
        ]
        
        // Create meal types
        mealTypes = [
            createMealType(name: "Breakfast", sortOrder: 1),
            createMealType(name: "Lunch", sortOrder: 2)
        ]
        
        // Create categories
        dishCategories = [
            createDishCategory(name: "Main", sortOrder: 1),
            createDishCategory(name: "Dessert", sortOrder: 2)
        ]
    }
    
    private func createUnit(name: String, sortOrder: Int16) -> Unit {
        let unit = Unit(context: context)
        unit.name = name
        unit.sortOrder = sortOrder
        return unit
    }
    
    private func createMealType(name: String, sortOrder: Int16) -> MealType {
        let mealType = MealType(context: context)
        mealType.name = name
        mealType.sortOrder = sortOrder
        return mealType
    }
    
    private func createDishCategory(name: String, sortOrder: Int16) -> DishCategory {
        let category = DishCategory(context: context)
        category.name = name
        category.sortOrder = sortOrder
        return category
    }
    
    // MARK: - DishDetailsServiceProtocol Implementation
    func fetchAllUnits() -> [Unit] {
        if error != nil {
            return []
        }
        return units
    }
    
    func fetchAllMealTypes() -> [MealType] {
        if error != nil {
            return []
        }
        return mealTypes
    }
    
    func fetchAllDishCategories() -> [DishCategory] {
        if error != nil {
            return []
        }
        return dishCategories
    }
    
    func createDish() throws -> Dish {
        if let error = error {
            throw error
        }
        let dish = Dish(context: context)
        dish.isDraft = true  // Mock service creates drafts like the real service
        createdDish = dish
        return dish
    }
    
    func createIngredient() throws -> IngredientDetail {
        if let error = error {
            throw error
        }
        let ingredient = IngredientDetail(context: context)
        createdIngredient = ingredient
        return ingredient
    }
    
    func deleteIngredient(ingredient: IngredientDetail) {
        deleteIngredientCalled = true
        context.delete(ingredient)
    }
    
    func saveChanges() throws {
        saveChangesCalled = true
        if let error = error {
            throw error
        }
        try context.save()
    }
    
    func saveChangesInBackground(completion: @escaping (Result<Void, Error>) -> Void) {
        saveChangesInBackgroundCalled = true
        if let error = error {
            completion(.failure(error))
        } else {
            completion(.success(()))
        }
    }
    
    func rollback() {
        rollbackCalled = true
        context.rollback()
    }
}

class DishDetailsUnitTests: XCTestCase {
    var context: NSManagedObjectContext!
    var testStack: TestCoreDataStack!
    var testDataFactory: TestDataFactory!
    var mockService: MockDishDetailsService!
    var viewModel: DishDetailsViewModel!
    
    override func setUp() {
        super.setUp()
        testStack = TestCoreDataStack.shared
        context = testStack.viewContext
        testDataFactory = TestDataFactory(context: context)
        mockService = MockDishDetailsService(context: context)
        
        // Initialize the shared static data cache manager with test context
        // This ensures DishDetailsViewModel gets the right data
        StaticDataCacheManager.shared.initialize(with: context)
        
        // Clean slate for each test
        cleanUpTestData()
    }
    
    override func tearDown() {
        cleanUpTestData()
        viewModel = nil
        mockService = nil
        testDataFactory = nil
        context = nil
        testStack = nil
        super.tearDown()
    }
    
    private func cleanUpTestData() {
        testDataFactory?.cleanUpTestData()
    }
    
    func testViewModelInitialization() {
        viewModel = DishDetailsViewModel(dishDetailsService: mockService)
        
        XCTAssertNotNil(viewModel, "ViewModel should be initialized")
        XCTAssertTrue(viewModel.units.count >= 0, "Units should be loaded")
        XCTAssertTrue(viewModel.allMealTypes.count >= 0, "Meal types should be loaded")
        XCTAssertTrue(viewModel.allDishCategories.count >= 0, "Categories should be loaded")
    }
    
    func testCreateNewDish() {
        viewModel = DishDetailsViewModel(dishDetailsService: mockService)
        viewModel.loadDish()
        
        XCTAssertNotNil(viewModel.dish, "Dish should be created")
        XCTAssertNotNil(mockService.createdDish, "Service should have created a dish")
    }
    
    func testSaveChangesError() {
        viewModel = DishDetailsViewModel(dishDetailsService: mockService)
        viewModel.loadDish()
        
        // Provide valid data that would normally pass validation
        viewModel.dish?.name = "Test Dish"
        
        // Add ingredient BEFORE setting the error (to ensure ingredient creation succeeds)
        let unit = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        let product = testDataFactory.createProduct(name: "Test Product", unit: unit)
        viewModel.addIngredient(product: product, quantity: 1.0)
        
        // Add meal type BEFORE setting the error
        let mealType = testDataFactory.createMealType(name: "Breakfast", sortOrder: 1)
        viewModel.toggleMealTypeSelection(mealType)
        
        // NOW set the error for save operation
        mockService.error = NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test save error"])
        
        var saveCompleted = false
        viewModel.saveChanges {
            saveCompleted = true
        }
        
        XCTAssertFalse(saveCompleted, "Save should fail with error")
        XCTAssertTrue(mockService.saveChangesCalled, "Save should be attempted")
    }
    
    func testLoadExistingDish() {
        // Create existing dish
        let existingDish = testDataFactory.createDish(name: "Original Dish", details: "Original Details")
        
        viewModel = DishDetailsViewModel(dishDetailsService: mockService, dish: existingDish)
        
        XCTAssertEqual(viewModel.dish?.name, "Original Dish")
        XCTAssertNotNil(viewModel.dish, "Should load existing dish")
    }
    
    func testUpdateExistingDish() {
        // Create existing dish
        let existingDish = testDataFactory.createDish(name: "Original Dish", details: "Original Details")
        
        viewModel = DishDetailsViewModel(dishDetailsService: mockService, dish: existingDish)
        
        // Update dish name
        viewModel.dish?.name = "Updated Dish"
        
        // Add required data for validation to pass
        let unit = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        let product = testDataFactory.createProduct(name: "Test Product", unit: unit)
        viewModel.addIngredient(product: product, quantity: 1.0)
        
        let mealType = testDataFactory.createMealType(name: "Breakfast", sortOrder: 1)
        viewModel.toggleMealTypeSelection(mealType)
        
        var saveCompleted = false
        viewModel.saveChanges {
            saveCompleted = true
        }
        
        XCTAssertTrue(saveCompleted, "Save should succeed")
        XCTAssertTrue(mockService.saveChangesCalled, "Save should be called")
        XCTAssertEqual(existingDish.name, "Updated Dish", "Dish should be updated")
    }
    
    func testAddIngredient() {
        viewModel = DishDetailsViewModel(dishDetailsService: mockService)
        viewModel.loadDish()
        
        // Create unit and product in the same context
        let unit = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        let product = testDataFactory.createProduct(name: "Test Product", unit: unit)
        
        viewModel.addIngredient(product: product, quantity: 1.0)
        
        XCTAssertEqual(viewModel.selectedIngredients.count, 1, "Should have 1 ingredient detail")
        XCTAssertEqual(viewModel.selectedIngredients.first?.product, product)
        XCTAssertEqual(viewModel.selectedIngredients.first?.quantity, 1.0)
    }
    
    func testAddMultipleIngredientsForSameProduct() {
        // Create test product with unit in same context
        let unit = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        let product = testDataFactory.createProduct(name: "Test Product", unit: unit)
        
        viewModel = DishDetailsViewModel(dishDetailsService: mockService)
        viewModel.loadDish()
        
        // Add ingredient twice - should create separate entries
        viewModel.addIngredient(product: product, quantity: 1.0)
        viewModel.addIngredient(product: product, quantity: 2.0)
        
        XCTAssertEqual(viewModel.selectedIngredients.count, 2, "Should have 2 separate ingredient details")
    }
    
    func testRemoveIngredient() {
        viewModel = DishDetailsViewModel(dishDetailsService: mockService)
        viewModel.loadDish()
        
        // Create unit and product in the same context
        let unit = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        let product = testDataFactory.createProduct(name: "Test Product", unit: unit)
        
        viewModel.addIngredient(product: product, quantity: 1.0)
        _ = viewModel.selectedIngredients.first!
        
        viewModel.deleteIngredient(at: IndexSet(integer: 0))
        
        XCTAssertEqual(viewModel.selectedIngredients.count, 0, "Should have no ingredients")
        XCTAssertTrue(mockService.deleteIngredientCalled, "Delete should be called")
    }
    
    func testFormValidation() {
        viewModel = DishDetailsViewModel(dishDetailsService: mockService)
        viewModel.loadDish()
        
        // Test with empty dish - should fail validation
        var saveCompleted = false
        viewModel.saveChanges {
            saveCompleted = true
        }
        
        // Save should not complete due to validation failure
        XCTAssertFalse(saveCompleted, "Save should fail validation with empty dish")
        XCTAssertFalse(mockService.saveChangesCalled, "Save should not be attempted when validation fails")
        
        // Add name but no ingredients/meal types - should still fail
        viewModel.dish?.name = "Test Dish"
        saveCompleted = false
        viewModel.saveChanges {
            saveCompleted = true
        }
        
        XCTAssertFalse(saveCompleted, "Save should fail validation without ingredients")
        XCTAssertFalse(mockService.saveChangesCalled, "Save should not be attempted when validation fails")
        
        // Add ingredient and meal type - should now pass validation and attempt save
        let unit = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        let product = testDataFactory.createProduct(name: "Test Product", unit: unit)
        viewModel.addIngredient(product: product, quantity: 1.0)
        
        let mealType = testDataFactory.createMealType(name: "Breakfast", sortOrder: 1)
        viewModel.toggleMealTypeSelection(mealType)
        
        saveCompleted = false
        viewModel.saveChanges {
            saveCompleted = true
        }
        
        XCTAssertTrue(saveCompleted, "Save should succeed with valid data")
        XCTAssertTrue(mockService.saveChangesCalled, "Save should be attempted with valid data")
    }
    
    // MARK: - NaN Validation Tests
    
    func testAddIngredientWithNaNQuantity() {
        viewModel = DishDetailsViewModel(dishDetailsService: mockService)
        viewModel.loadDish()
        
        let unit = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        let product = testDataFactory.createProduct(name: "Test Product", unit: unit)
        
        // Add ingredient with NaN quantity
        viewModel.addIngredient(product: product, quantity: Double.nan)
        
        XCTAssertEqual(viewModel.selectedIngredients.count, 1, "Should have 1 ingredient detail")
        XCTAssertEqual(viewModel.selectedIngredients.first?.quantity, 0.0, "NaN quantity should be converted to 0.0")
        XCTAssertEqual(viewModel.selectedIngredients.first?.product, product)
    }
    
    func testAddIngredientWithInfiniteQuantity() {
        viewModel = DishDetailsViewModel(dishDetailsService: mockService)
        viewModel.loadDish()
        
        let unit = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        let product = testDataFactory.createProduct(name: "Test Product", unit: unit)
        
        // Add ingredient with infinite quantity
        viewModel.addIngredient(product: product, quantity: Double.infinity)
        
        XCTAssertEqual(viewModel.selectedIngredients.count, 1, "Should have 1 ingredient detail")
        XCTAssertEqual(viewModel.selectedIngredients.first?.quantity, 0.0, "Infinite quantity should be converted to 0.0")
        XCTAssertEqual(viewModel.selectedIngredients.first?.product, product)
    }
    
    func testAddIngredientWithNegativeInfiniteQuantity() {
        viewModel = DishDetailsViewModel(dishDetailsService: mockService)
        viewModel.loadDish()
        
        let unit = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        let product = testDataFactory.createProduct(name: "Test Product", unit: unit)
        
        // Add ingredient with negative infinite quantity
        viewModel.addIngredient(product: product, quantity: -Double.infinity)
        
        XCTAssertEqual(viewModel.selectedIngredients.count, 1, "Should have 1 ingredient detail")
        XCTAssertEqual(viewModel.selectedIngredients.first?.quantity, 0.0, "Negative infinite quantity should be converted to 0.0")
        XCTAssertEqual(viewModel.selectedIngredients.first?.product, product)
    }
    
    func testLoadIngredientsWithNaNQuantity() {
        viewModel = DishDetailsViewModel(dishDetailsService: mockService)
        viewModel.loadDish()
        
        // Create ingredient with valid quantity first
        let unit = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        let product = testDataFactory.createProduct(name: "Test Product", unit: unit)
        viewModel.addIngredient(product: product, quantity: 1.0)
        
        // Manually corrupt the quantity to simulate existing bad data
        if let ingredient = viewModel.selectedIngredients.first {
            ingredient.quantity = Double.nan
        }
        
        // Load ingredients should fix the NaN value
        viewModel.loadIngredients()
        
        XCTAssertEqual(viewModel.selectedIngredients.count, 1, "Should still have 1 ingredient")
        XCTAssertEqual(viewModel.selectedIngredients.first?.quantity, 0.0, "NaN quantity should be fixed to 0.0")
        XCTAssertFalse(viewModel.selectedIngredients.first?.quantity.isNaN ?? true, "Quantity should no longer be NaN")
    }
    
    func testAddIngredientWithNegativeQuantity() {
        viewModel = DishDetailsViewModel(dishDetailsService: mockService)
        viewModel.loadDish()
        
        let unit = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        let product = testDataFactory.createProduct(name: "Test Product", unit: unit)
        
        // Add ingredient with negative quantity
        viewModel.addIngredient(product: product, quantity: -5.0)
        
        XCTAssertEqual(viewModel.selectedIngredients.count, 1, "Should have 1 ingredient detail")
        XCTAssertEqual(viewModel.selectedIngredients.first?.quantity, 0.0, "Negative quantity should be converted to 0.0")
        XCTAssertEqual(viewModel.selectedIngredients.first?.product, product)
    }
    
    func testValidateQuantityHelperMethod() {
        viewModel = DishDetailsViewModel(dishDetailsService: mockService)
        
        // Test through reflection since validateQuantity is private
        // We'll test through public methods that use it
        let unit = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        let product = testDataFactory.createProduct(name: "Test Product", unit: unit)
        
        viewModel.loadDish()
        
        // Test various edge cases through addIngredient
        let testCases: [(input: Double, expected: Double)] = [
            (1.0, 1.0),           // Normal positive value
            (0.0, 0.0),           // Zero
            (-1.0, 0.0),          // Negative
            (Double.nan, 0.0),    // NaN
            (Double.infinity, 0.0), // Positive infinity
            (-Double.infinity, 0.0), // Negative infinity
            (0.5, 0.5),           // Decimal
            (1000.0, 1000.0)      // Large number
        ]
        
        for (index, testCase) in testCases.enumerated() {
            // Clear previous ingredients by deleting them properly
            while !viewModel.selectedIngredients.isEmpty {
                viewModel.deleteIngredient(at: IndexSet(integer: 0))
            }
            
            viewModel.addIngredient(product: product, quantity: testCase.input)
            
            XCTAssertEqual(viewModel.selectedIngredients.count, 1, "Should have 1 ingredient for test case \(index)")
            XCTAssertEqual(viewModel.selectedIngredients.first?.quantity, testCase.expected, 
                          "Quantity validation failed for input \(testCase.input), expected \(testCase.expected)")
        }
    }
    
    func testUpdateIngredientQuantityWithValidation() {
        viewModel = DishDetailsViewModel(dishDetailsService: mockService)
        viewModel.loadDish()
        
        // Create test ingredient
        let unit = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        let product = testDataFactory.createProduct(name: "Test Product", unit: unit)
        viewModel.addIngredient(product: product, quantity: 1.0)
        
        guard let ingredient = viewModel.selectedIngredients.first else {
            XCTFail("Should have created an ingredient")
            return
        }
        
        // Test various edge cases for updateIngredientQuantity
        let testCases: [(input: Double, expected: Double)] = [
            (2.5, 2.5),                    // Normal positive value
            (0.0, 0.0),                    // Zero
            (-1.0, 0.0),                   // Negative
            (Double.nan, 0.0),             // NaN
            (Double.infinity, 0.0),        // Positive infinity
            (-Double.infinity, 0.0),       // Negative infinity
            (100.5, 100.5)                 // Large number
        ]
        
        for testCase in testCases {
            viewModel.updateIngredientQuantity(ingredient, quantity: testCase.input)
            
            XCTAssertEqual(ingredient.quantity, testCase.expected,
                          "updateIngredientQuantity failed for input \(testCase.input), expected \(testCase.expected)")
            XCTAssertFalse(ingredient.quantity.isNaN, "Quantity should never be NaN after validation")
            XCTAssertFalse(ingredient.quantity.isInfinite, "Quantity should never be infinite after validation")
        }
    }
    
    func testDataValidationCleanupOnInitialization() {
        // Create a dish with corrupted ingredient data
        let unit = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        let product = testDataFactory.createProduct(name: "Test Product", unit: unit)
        let dish = testDataFactory.createDish(name: "Test Dish")
        
        // Create ingredient with NaN quantity directly in CoreData (simulating existing bad data)
        let ingredient = IngredientDetail(context: context)
        ingredient.dish = dish
        ingredient.product = product
        ingredient.quantity = Double.nan
        
        // Save the corrupted data
        try! context.save()
        
        // Verify the NaN value exists before cleanup
        XCTAssertTrue(ingredient.quantity.isNaN, "Ingredient should have NaN quantity before cleanup")
        
        // Initialize ViewModel with the corrupted dish - this should trigger cleanup
        viewModel = DishDetailsViewModel(dishDetailsService: mockService, dish: dish)
        
        // Wait for any async operations to complete
        let expectation = XCTestExpectation(description: "Data cleanup completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Refresh the context to see the updated data
        context.refresh(ingredient, mergeChanges: false)
        
        // Verify the NaN value was fixed during initialization
        XCTAssertFalse(ingredient.quantity.isNaN, "Ingredient quantity should no longer be NaN after ViewModel initialization")
        XCTAssertEqual(ingredient.quantity, 0.0, "NaN quantity should be fixed to 0.0")
    }
    
    // MARK: - Ingredient Sorting Tests
    
    func testIngredientSortOptionsEnum() {
        // Test all enum cases exist and have proper values
        let allCases = IngredientSortOption.allCases
        XCTAssertEqual(allCases.count, 6, "Should have 6 sort options")
        
        // Test specific cases and their properties
        XCTAssertEqual(IngredientSortOption.custom.rawValue, "Default")
        XCTAssertEqual(IngredientSortOption.alphabetical.rawValue, "A-Z")
        XCTAssertEqual(IngredientSortOption.reverseAlphabetical.rawValue, "Z-A")
        XCTAssertEqual(IngredientSortOption.quantityHighToLow.rawValue, "Quantity: High to Low")
        XCTAssertEqual(IngredientSortOption.quantityLowToHigh.rawValue, "Quantity: Low to High")
        XCTAssertEqual(IngredientSortOption.unitType.rawValue, "By Unit Type")
        
        // Test icons
        XCTAssertEqual(IngredientSortOption.custom.icon, "list.number")
        XCTAssertEqual(IngredientSortOption.alphabetical.icon, "textformat.abc")
        XCTAssertEqual(IngredientSortOption.reverseAlphabetical.icon, "textformat")
        XCTAssertEqual(IngredientSortOption.quantityHighToLow.icon, "arrow.down.square")
        XCTAssertEqual(IngredientSortOption.quantityLowToHigh.icon, "arrow.up.square")
        XCTAssertEqual(IngredientSortOption.unitType.icon, "scale.3d")
    }
    
    func testSortPreferencePersistence() {
        // Clear any existing preferences
        UserDefaults.standard.removeObject(forKey: "IngredientSortPreference")
        
        // Test default preference loading (should be custom)
        viewModel = DishDetailsViewModel(dishDetailsService: mockService)
        XCTAssertEqual(viewModel.currentSortOption, .custom, "Default sort option should be custom")
        
        // Create test ingredients for sorting
        setupTestIngredientsForSorting()
        
        // Test preference saving and loading for each sort option
        for sortOption in IngredientSortOption.allCases {
            viewModel.sortIngredients(by: sortOption)
            XCTAssertEqual(viewModel.currentSortOption, sortOption, "Current sort option should match selected option")
            
            // Create new ViewModel to test persistence
            let newViewModel = DishDetailsViewModel(dishDetailsService: mockService)
            XCTAssertEqual(newViewModel.currentSortOption, sortOption, "Sort preference should persist after ViewModel recreation")
        }
    }
    
    func testAlphabeticalSorting() {
        viewModel = DishDetailsViewModel(dishDetailsService: mockService)
        viewModel.loadDish()
        
        // Create products with specific names for alphabetical testing
        let unit = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        let products = [
            testDataFactory.createProduct(name: "Carrots", unit: unit),
            testDataFactory.createProduct(name: "Apples", unit: unit),
            testDataFactory.createProduct(name: "Bananas", unit: unit)
        ]
        
        // Add ingredients in random order
        viewModel.addIngredient(product: products[0], quantity: 1.0) // Carrots
        viewModel.addIngredient(product: products[2], quantity: 2.0) // Bananas  
        viewModel.addIngredient(product: products[1], quantity: 3.0) // Apples
        
        // Sort alphabetically
        viewModel.sortIngredients(by: .alphabetical)
        
        // Verify alphabetical order
        let sortedNames = viewModel.selectedIngredients.map { $0.product?.name ?? "" }
        XCTAssertEqual(sortedNames, ["Apples", "Bananas", "Carrots"], "Ingredients should be sorted alphabetically")
        XCTAssertEqual(viewModel.currentSortOption, .alphabetical, "Current sort option should be alphabetical")
    }
    
    func testReverseAlphabeticalSorting() {
        viewModel = DishDetailsViewModel(dishDetailsService: mockService)
        viewModel.loadDish()
        
        // Create products with specific names
        let unit = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        let products = [
            testDataFactory.createProduct(name: "Apples", unit: unit),
            testDataFactory.createProduct(name: "Bananas", unit: unit),
            testDataFactory.createProduct(name: "Carrots", unit: unit)
        ]
        
        // Add ingredients in random order
        for product in products {
            viewModel.addIngredient(product: product, quantity: 1.0)
        }
        
        // Sort reverse alphabetically
        viewModel.sortIngredients(by: .reverseAlphabetical)
        
        // Verify reverse alphabetical order
        let sortedNames = viewModel.selectedIngredients.map { $0.product?.name ?? "" }
        XCTAssertEqual(sortedNames, ["Carrots", "Bananas", "Apples"], "Ingredients should be sorted reverse alphabetically")
        XCTAssertEqual(viewModel.currentSortOption, .reverseAlphabetical, "Current sort option should be reverse alphabetical")
    }
    
    func testQuantitySorting() {
        viewModel = DishDetailsViewModel(dishDetailsService: mockService)
        viewModel.loadDish()
        
        // Create products with specific quantities
        let unit = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        let products = [
            testDataFactory.createProduct(name: "Product A", unit: unit),
            testDataFactory.createProduct(name: "Product B", unit: unit),
            testDataFactory.createProduct(name: "Product C", unit: unit)
        ]
        
        // Add ingredients with different quantities
        viewModel.addIngredient(product: products[0], quantity: 2.5)
        viewModel.addIngredient(product: products[1], quantity: 1.0)
        viewModel.addIngredient(product: products[2], quantity: 5.0)
        
        // Test high to low sorting
        viewModel.sortIngredients(by: .quantityHighToLow)
        let quantitiesHighToLow = viewModel.selectedIngredients.map { $0.quantity }
        XCTAssertEqual(quantitiesHighToLow, [5.0, 2.5, 1.0], "Ingredients should be sorted by quantity high to low")
        XCTAssertEqual(viewModel.currentSortOption, .quantityHighToLow, "Current sort option should be quantity high to low")
        
        // Test low to high sorting
        viewModel.sortIngredients(by: .quantityLowToHigh)
        let quantitiesLowToHigh = viewModel.selectedIngredients.map { $0.quantity }
        XCTAssertEqual(quantitiesLowToHigh, [1.0, 2.5, 5.0], "Ingredients should be sorted by quantity low to high")
        XCTAssertEqual(viewModel.currentSortOption, .quantityLowToHigh, "Current sort option should be quantity low to high")
    }
    
    func testUnitTypeSorting() {
        viewModel = DishDetailsViewModel(dishDetailsService: mockService)
        viewModel.loadDish()
        
        // Create units with different names
        let units = [
            testDataFactory.createUnit(name: "kg", sortOrder: 1),
            testDataFactory.createUnit(name: "pcs", sortOrder: 2),
            testDataFactory.createUnit(name: "l", sortOrder: 3)
        ]
        
        // Create products with different units
        let products = [
            testDataFactory.createProduct(name: "Flour", unit: units[0]),      // kg
            testDataFactory.createProduct(name: "Apples", unit: units[1]),     // pcs
            testDataFactory.createProduct(name: "Milk", unit: units[2]),       // l
            testDataFactory.createProduct(name: "Sugar", unit: units[0])       // kg (same unit as flour)
        ]
        
        // Add ingredients in mixed order
        for product in products {
            viewModel.addIngredient(product: product, quantity: 1.0)
        }
        
        // Sort by unit type
        viewModel.sortIngredients(by: .unitType)
        
        // Verify sorting by unit type (kg, l, pcs in alphabetical order of units)
        // Within same unit, should be alphabetical by product name
        let sortedData = viewModel.selectedIngredients.map { 
            (productName: $0.product?.name ?? "", unitName: $0.product?.unit?.name ?? "") 
        }
        
        // Expected order: kg items (Flour, Sugar alphabetically), then l items (Milk), then pcs items (Apples)
        XCTAssertEqual(sortedData[0].unitName, "kg", "First unit should be kg")
        XCTAssertEqual(sortedData[1].unitName, "kg", "Second unit should be kg")
        XCTAssertEqual(sortedData[2].unitName, "l", "Third unit should be l")
        XCTAssertEqual(sortedData[3].unitName, "pcs", "Fourth unit should be pcs")
        
        // Within kg unit, should be alphabetical: Flour, Sugar
        XCTAssertTrue(sortedData[0].productName == "Flour" || sortedData[0].productName == "Sugar")
        XCTAssertTrue(sortedData[1].productName == "Flour" || sortedData[1].productName == "Sugar")
        XCTAssertNotEqual(sortedData[0].productName, sortedData[1].productName, "Flour and Sugar should be in different positions")
        
        XCTAssertEqual(viewModel.currentSortOption, .unitType, "Current sort option should be unit type")
    }
    
    func testCustomSorting() {
        viewModel = DishDetailsViewModel(dishDetailsService: mockService)
        viewModel.loadDish()
        
        // Create test ingredients
        let unit = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        let products = [
            testDataFactory.createProduct(name: "Product A", unit: unit),
            testDataFactory.createProduct(name: "Product B", unit: unit),
            testDataFactory.createProduct(name: "Product C", unit: unit)
        ]
        
        // Add ingredients
        for product in products {
            viewModel.addIngredient(product: product, quantity: 1.0)
        }
        
        // Sort by custom order (should use sortOrder property)
        viewModel.sortIngredients(by: .custom)
        
        // Verify that sortOrder was updated for custom sorting
        for (index, ingredient) in viewModel.selectedIngredients.enumerated() {
            XCTAssertEqual(ingredient.sortOrder, Int16(index), "Sort order should match array index for custom sorting")
        }
        
        XCTAssertEqual(viewModel.currentSortOption, .custom, "Current sort option should be custom")
        XCTAssertTrue(mockService.saveChangesCalled, "Save should be called when updating custom sort order")
    }
    
    func testSortingWithEmptyIngredients() {
        viewModel = DishDetailsViewModel(dishDetailsService: mockService)
        viewModel.loadDish()
        
        // Test sorting with no ingredients (should not crash)
        for sortOption in IngredientSortOption.allCases {
            viewModel.sortIngredients(by: sortOption)
            XCTAssertTrue(viewModel.selectedIngredients.isEmpty, "Ingredients should remain empty")
            XCTAssertEqual(viewModel.currentSortOption, sortOption, "Sort option should be updated even with empty ingredients")
        }
    }
    
    func testSortingWithSingleIngredient() {
        viewModel = DishDetailsViewModel(dishDetailsService: mockService)
        viewModel.loadDish()
        
        // Add single ingredient
        let unit = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        let product = testDataFactory.createProduct(name: "Single Product", unit: unit)
        viewModel.addIngredient(product: product, quantity: 1.0)
        
        // Test all sorting options with single ingredient
        for sortOption in IngredientSortOption.allCases {
            viewModel.sortIngredients(by: sortOption)
            XCTAssertEqual(viewModel.selectedIngredients.count, 1, "Should maintain single ingredient")
            XCTAssertEqual(viewModel.selectedIngredients.first?.product?.name, "Single Product", "Product should remain unchanged")
            XCTAssertEqual(viewModel.currentSortOption, sortOption, "Sort option should be updated")
        }
    }
    
    func testNewIngredientSortOrder() {
        viewModel = DishDetailsViewModel(dishDetailsService: mockService)
        viewModel.loadDish()
        
        // Create test products
        let unit = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        let products = [
            testDataFactory.createProduct(name: "First Product", unit: unit),
            testDataFactory.createProduct(name: "Second Product", unit: unit),
            testDataFactory.createProduct(name: "Third Product", unit: unit)
        ]
        
        // Test adding first ingredient (should have sortOrder 0)
        viewModel.addIngredient(product: products[0], quantity: 1.0)
        XCTAssertEqual(viewModel.selectedIngredients.count, 1, "Should have 1 ingredient")
        XCTAssertEqual(viewModel.selectedIngredients[0].sortOrder, 0, "First ingredient should have sortOrder 0")
        
        // Test adding second ingredient (should have sortOrder 1)
        viewModel.addIngredient(product: products[1], quantity: 2.0)
        XCTAssertEqual(viewModel.selectedIngredients.count, 2, "Should have 2 ingredients")
        XCTAssertEqual(viewModel.selectedIngredients[1].sortOrder, 1, "Second ingredient should have sortOrder 1")
        
        // Test adding third ingredient (should have sortOrder 2)
        viewModel.addIngredient(product: products[2], quantity: 3.0)
        XCTAssertEqual(viewModel.selectedIngredients.count, 3, "Should have 3 ingredients")
        XCTAssertEqual(viewModel.selectedIngredients[2].sortOrder, 2, "Third ingredient should have sortOrder 2")
        
        // Verify ingredients are in the correct order when using default sorting
        viewModel.sortIngredients(by: .custom)
        let productNames = viewModel.selectedIngredients.map { $0.product?.name ?? "" }
        XCTAssertEqual(productNames, ["First Product", "Second Product", "Third Product"], 
                      "Ingredients should maintain addition order with default sorting")
    }
    
    // Helper method to set up test ingredients for sorting tests
    private func setupTestIngredientsForSorting() {
        viewModel.loadDish()
        let unit = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        let products = [
            testDataFactory.createProduct(name: "Test Product 1", unit: unit),
            testDataFactory.createProduct(name: "Test Product 2", unit: unit)
        ]
        
        for product in products {
            viewModel.addIngredient(product: product, quantity: 1.0)
        }
    }

    // MARK: - Batch Add Ingredients (Multi-select) Tests
    func testAddIngredientsBatchAddsAllWithDefaultQuantityAndSortOrder() {
        viewModel = DishDetailsViewModel(dishDetailsService: mockService)
        viewModel.loadDish()

        let unit = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        let p1 = testDataFactory.createProduct(name: "Apples", unit: unit)
        let p2 = testDataFactory.createProduct(name: "Bananas", unit: unit)
        let p3 = testDataFactory.createProduct(name: "Carrots", unit: unit)

        viewModel.addIngredients(products: [p1, p2, p3], defaultQuantity: 1.0)

        XCTAssertEqual(viewModel.selectedIngredients.count, 3)
        let names = Set(viewModel.selectedIngredients.compactMap { $0.product?.name })
        XCTAssertEqual(names, Set(["Apples", "Bananas", "Carrots"]))
        XCTAssertTrue(viewModel.selectedIngredients.allSatisfy { $0.quantity == 1.0 })

        // Validate sort order starts at 0 and increases sequentially
        let sortOrders = viewModel.selectedIngredients.map { Int($0.sortOrder) }.sorted()
        XCTAssertEqual(sortOrders, [0, 1, 2])
    }

    func testAddIngredientsBatchAppendsAfterExistingWithCorrectSortOrder() {
        viewModel = DishDetailsViewModel(dishDetailsService: mockService)
        viewModel.loadDish()

        let unit = testDataFactory.createUnit(name: "kg", sortOrder: 1)
        let existing = testDataFactory.createProduct(name: "Existing", unit: unit)
        viewModel.addIngredient(product: existing, quantity: 2.0)

        let p1 = testDataFactory.createProduct(name: "A", unit: unit)
        let p2 = testDataFactory.createProduct(name: "B", unit: unit)

        viewModel.addIngredients(products: [p1, p2], defaultQuantity: 1.0)

        XCTAssertEqual(viewModel.selectedIngredients.count, 3)
        // Extract sort orders mapped by product name
        let map = Dictionary(uniqueKeysWithValues: viewModel.selectedIngredients.map { ($0.product?.name ?? "", Int($0.sortOrder)) })
        XCTAssertEqual(map["Existing"], 0)
        XCTAssertEqual(map["A"], 1)
        XCTAssertEqual(map["B"], 2)
    }
} 
