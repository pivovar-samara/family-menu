//
//  DishDetailsUnitTests.swift
//  FamilyMenuPlannerTests
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
} 
