import XCTest
@testable import FamilyMenuPlanner

// MARK: - Mock Service
class MockDishDetailsService: DishDetailsServiceProtocol {
    var units: [Unit] = []
    var mealTypes: [MealType] = []
    var error: Error?
    var saveChangesCalled = false
    var rollbackCalled = false
    var deleteIngredientCalled = false
    var createdDish: Dish?
    var createdIngredient: IngredientDetail?
    
    func fetchAllUnits() -> [Unit] {
        if let error = error {
            print("Error fetching units: \(error)")
            return []
        }
        return units
    }
    
    func fetchAllMealTypes() -> [MealType] {
        if let error = error {
            print("Error fetching meal types: \(error)")
            return []
        }
        return mealTypes
    }
    
    func createDish() throws -> Dish {
        if let error = error {
            throw error
        }
        let dish = Dish()
        createdDish = dish
        return dish
    }
    
    func createIngredient() throws -> IngredientDetail {
        if let error = error {
            throw error
        }
        let ingredient = IngredientDetail()
        createdIngredient = ingredient
        return ingredient
    }
    
    func deleteIngredient(ingredient: IngredientDetail) {
        deleteIngredientCalled = true
    }
    
    func saveChanges() throws {
        if let error = error {
            throw error
        }
        saveChangesCalled = true
    }
    
    func rollback() {
        rollbackCalled = true
    }
}

// MARK: - Mock View Model
class MockDishDetailsViewModel {
    private(set) var dish: MockDish?
    var descriptionText: String = ""
    var selectedMealTypes: Set<MockMealType> = []
    var selectedIngredients: [MockIngredientDetail] = []
    var validationError: String?
    var currentAlert: AlertItem?
    
    private let dishDetailsService: MockDishDetailsService
    
    init(dishDetailsService: MockDishDetailsService, dish: MockDish? = nil) {
        self.dishDetailsService = dishDetailsService
        self.dish = dish
    }
    
    func loadDish() {
        guard dish == nil else { return }
        dish = MockDish(name: "")
    }
    
    func setDishName(_ name: String) {
        dish = MockDish(name: name, details: dish?.details)
    }
    
    func loadIngredients() {
        // In real implementation, this would load from Core Data relationships
    }
    
    func loadSelectedMealTypes() {
        // In real implementation, this would load from Core Data relationships
    }
    
    func addIngredient(for product: MockProduct) {
        let newIngredient = MockIngredientDetail()
        newIngredient.dish = dish
        newIngredient.product = product
        newIngredient.quantity = 1.0
        newIngredient.sortOrder = Int16(selectedIngredients.count)
        selectedIngredients.append(newIngredient)
    }
    
    func moveIngredient(from source: IndexSet, to destination: Int) {
        selectedIngredients.move(fromOffsets: source, toOffset: destination)
        
        for (index, ingredient) in selectedIngredients.enumerated() {
            ingredient.sortOrder = Int16(index)
        }
    }
    
    func deleteIngredient(at offsets: IndexSet) {
        dishDetailsService.deleteIngredientCalled = true
        selectedIngredients.remove(atOffsets: offsets)
    }
    
    func toggleMealTypeSelection(_ mealType: MockMealType) {
        if selectedMealTypes.contains(mealType) {
            selectedMealTypes.remove(mealType)
        } else {
            selectedMealTypes.insert(mealType)
        }
    }
    
    func saveChanges(onSuccess: ()->Void) {
        do {
            guard validate() else { return }
            try dishDetailsService.saveChanges()
            onSuccess()
        } catch {
            currentAlert = AlertItem(
                title: "Error".localized(),
                message: error.localizedDescription.localized(),
                action: nil
            )
        }
    }
    
    func rollback() {
        dishDetailsService.rollback()
    }
    
    private func validate() -> Bool {
        validationError = nil
        
        if dish?.name?.isEmpty ?? true {
            validationError = "Dish name cannot be empty.".localized()
            return false
        }
        
        if selectedIngredients.isEmpty {
            validationError = "Dish must have at least one ingredient.".localized()
            return false
        }
        
        if selectedMealTypes.isEmpty {
            validationError = "Dish must have at least one meal type.".localized()
            return false
        }
        
        return true
    }
}

// MARK: - Unit Tests
class DishDetailsUnitTests: XCTestCase {
    var mockService: MockDishDetailsService!
    var viewModel: MockDishDetailsViewModel!
    
    override func setUp() {
        super.setUp()
        mockService = MockDishDetailsService()
        viewModel = MockDishDetailsViewModel(dishDetailsService: mockService)
    }
    
    override func tearDown() {
        mockService = nil
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Loading Tests
    
    func testLoadNewDish() {
        // Load new dish
        viewModel.loadDish()
        
        // Verify dish was created
        XCTAssertNotNil(viewModel.dish)
    }
    
    func testLoadExistingDish() {
        // Create an existing mock dish
        let existingDish = MockDish(name: "Test Dish")
        
        // Create view model with existing dish
        viewModel = MockDishDetailsViewModel(dishDetailsService: mockService, dish: existingDish)
        
        // Load dish
        viewModel.loadDish()
        
        // Verify existing dish wasn't replaced
        XCTAssertEqual(viewModel.dish?.name, "Test Dish")
    }
    
    // MARK: - Ingredient Tests
    
    func testAddIngredient() {
        // Create a dish
        viewModel.loadDish()
        
        // Create a mock unit and product
        let mockUnit = MockUnit(name: "pcs", sortOrder: 0)
        let mockProduct = MockProduct(name: "Test Product", unit: mockUnit)
        
        // Add ingredient
        viewModel.addIngredient(for: mockProduct)
        
        // Verify ingredient was created and added
        XCTAssertEqual(viewModel.selectedIngredients.count, 1)
        XCTAssertEqual(viewModel.selectedIngredients.first?.product?.name, "Test Product")
    }
    
    func testDeleteIngredient() {
        // Create mock ingredient
        let ingredient = MockIngredientDetail()
        viewModel.selectedIngredients = [ingredient]
        
        // Delete ingredient
        viewModel.deleteIngredient(at: IndexSet(integer: 0))
        
        // Verify ingredient was deleted
        XCTAssertTrue(mockService.deleteIngredientCalled)
        XCTAssertTrue(viewModel.selectedIngredients.isEmpty)
    }
    
    func testMoveIngredient() {
        // Create mock ingredients
        let mockUnit = MockUnit(name: "pcs", sortOrder: 0)
        let mockProduct = MockProduct(name: "Test Product", unit: mockUnit)
        
        let ingredient1 = MockIngredientDetail()
        ingredient1.product = mockProduct
        ingredient1.quantity = 1.0
        ingredient1.sortOrder = 0
        
        let ingredient2 = MockIngredientDetail()
        ingredient2.product = mockProduct
        ingredient2.quantity = 1.0
        ingredient2.sortOrder = 1
        
        // Create a mock dish and set up relationships
        let mockDish = MockDish(name: "Test Dish")
        ingredient1.dish = mockDish
        ingredient2.dish = mockDish
        
        // Set up the view model's selected ingredients
        viewModel.selectedIngredients = [ingredient1, ingredient2]
        
        // Move ingredient
        viewModel.moveIngredient(from: IndexSet(integer: 0), to: 1)
        
        // Verify order was updated
        XCTAssertEqual(viewModel.selectedIngredients[0].product?.name, ingredient2.product?.name)
        XCTAssertEqual(viewModel.selectedIngredients[1].product?.name, ingredient1.product?.name)
        XCTAssertEqual(viewModel.selectedIngredients[0].sortOrder, 0)
        XCTAssertEqual(viewModel.selectedIngredients[1].sortOrder, 1)
    }
    
    // MARK: - Meal Type Tests
    
    func testToggleMealType() {
        // Create a dish
        viewModel.loadDish()
        
        // Create a mock meal type
        let mealType = MockMealType(name: "Breakfast")
        
        // Toggle meal type
        viewModel.toggleMealTypeSelection(mealType)
        
        // Verify meal type was added
        XCTAssertTrue(viewModel.selectedMealTypes.contains(mealType))
        
        // Toggle again
        viewModel.toggleMealTypeSelection(mealType)
        
        // Verify meal type was removed
        XCTAssertFalse(viewModel.selectedMealTypes.contains(mealType))
    }
    
    // MARK: - Validation Tests
    
    func testValidation() {
        // Create a dish
        viewModel.loadDish()
        
        // Test empty name
        viewModel.setDishName("")
        var successCalled = false
        viewModel.saveChanges { successCalled = true }
        XCTAssertFalse(successCalled)
        XCTAssertNotNil(viewModel.validationError)
        XCTAssertEqual(viewModel.validationError, "Dish name cannot be empty.".localized())
        
        // Test with name but no ingredients
        viewModel.setDishName("Test Dish")
        successCalled = false
        viewModel.saveChanges { successCalled = true }
        XCTAssertFalse(successCalled)
        XCTAssertNotNil(viewModel.validationError)
        XCTAssertEqual(viewModel.validationError, "Dish must have at least one ingredient.".localized())
        
        // Test with name and ingredients but no meal type
        let ingredient = MockIngredientDetail()
        viewModel.selectedIngredients = [ingredient]
        successCalled = false
        viewModel.saveChanges { successCalled = true }
        XCTAssertFalse(successCalled)
        XCTAssertNotNil(viewModel.validationError)
        XCTAssertEqual(viewModel.validationError, "Dish must have at least one meal type.".localized())
        
        // Test with all required fields
        let mealType = MockMealType(name: "Breakfast")
        viewModel.selectedMealTypes.insert(mealType)
        successCalled = false
        viewModel.saveChanges { successCalled = true }
        XCTAssertTrue(successCalled)
        XCTAssertNil(viewModel.validationError)
        XCTAssertTrue(mockService.saveChangesCalled)
    }
    
    // MARK: - Save and Rollback Tests
    
    func testSaveChanges() {
        // Setup valid dish
        viewModel.loadDish()
        viewModel.setDishName("Test Dish")
        let ingredient = MockIngredientDetail()
        viewModel.selectedIngredients = [ingredient]
        let mealType = MockMealType(name: "Breakfast")
        viewModel.selectedMealTypes.insert(mealType)
        
        // Save changes
        var successCalled = false
        viewModel.saveChanges {
            successCalled = true
        }
        
        // Verify changes were saved
        XCTAssertTrue(mockService.saveChangesCalled)
        XCTAssertTrue(successCalled)
    }
    
    func testSaveChangesWithError() {
        // Setup valid dish first so validation passes
        viewModel.loadDish()
        viewModel.setDishName("Test Dish")
        let ingredient = MockIngredientDetail()
        viewModel.selectedIngredients = [ingredient]
        let mealType = MockMealType(name: "Breakfast")
        viewModel.selectedMealTypes.insert(mealType)
        
        // Setup error
        mockService.error = NSError(domain: "test", code: -1, userInfo: nil)
        
        // Try to save changes
        viewModel.saveChanges {}
        
        // Verify error was handled
        XCTAssertNotNil(viewModel.currentAlert)
    }
    
    func testRollback() {
        // Rollback changes
        viewModel.rollback()
        
        // Verify rollback was called
        XCTAssertTrue(mockService.rollbackCalled)
    }
} 
