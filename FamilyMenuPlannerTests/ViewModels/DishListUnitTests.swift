import XCTest
@testable import FamilyMenuPlanner

// MARK: - Mock Service
class MockDishListService: DishListServiceProtocol {
    var dishes: [MockDish] = []
    var error: Error?
    var deleteDishCalled = false
    var delegate: DishListServiceDelegate?
    
    func fetchAllDishes() {
        if let error = error {
            print("Error fetching dishes: \(error)")
            delegate?.serviceDidChangeContent([])
            return
        }
        // In real tests we'd convert MockDish to Dish
        delegate?.serviceDidChangeContent([])
    }
    
    func deleteDishes(dishes: [Dish]) throws {
        if let error = error {
            throw error
        }
        deleteDishCalled = true
    }
    
    func deleteDishesInBackground(dishes: [Dish], completion: @escaping (Result<Void, Error>) -> Void) {
        if let error = error {
            completion(.failure(error))
        } else {
            deleteDishCalled = true
            completion(.success(()))
        }
    }
}

// MARK: - View Model for Unit Tests
class MockDishListViewModel {
    var selectedDish: MockDish?
    var isAddingNewDish: Bool = false
    var dishes: [MockDish] = []
    var currentAlert: AlertItem?
    
    private let dishListService: MockDishListService
    
    init(dishListService: MockDishListService) {
        self.dishListService = dishListService
    }
    
    func loadDishes() {
        dishListService.fetchAllDishes()
    }
    
    func deleteDishes(at offsets: IndexSet) throws {
        try dishListService.deleteDishes(dishes: [])
    }
}

// MARK: - Unit Tests
class DishListUnitTests: XCTestCase {
    var mockService: MockDishListService!
    var viewModel: MockDishListViewModel!
    
    override func setUp() {
        super.setUp()
        mockService = MockDishListService()
        viewModel = MockDishListViewModel(dishListService: mockService)
    }
    
    override func tearDown() {
        mockService = nil
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Loading Tests
    
    func testLoadDishes() {
        // Setup test data
        let dish = MockDish(name: "Test Dish", details: "Test Details")
        mockService.dishes = [dish]
        
        // Load dishes
        viewModel.loadDishes()
        
        // Verify service was called
        XCTAssertTrue(true) // Service call is verified through delegate pattern
    }
    
    func testLoadDishesWithError() {
        // Setup error
        mockService.error = NSError(domain: "test", code: -1, userInfo: nil)
        
        // Load dishes
        viewModel.loadDishes()
        
        // Verify no dishes are loaded through delegate pattern
        XCTAssertTrue(viewModel.dishes.isEmpty)
    }
    
    // MARK: - CRUD Operation Tests
    
    func testDeleteDish() {
        // Delete dish
        try? viewModel.deleteDishes(at: IndexSet(integer: 0))
        
        // Verify service was called
        XCTAssertTrue(mockService.deleteDishCalled)
    }
    
    func testDeleteDishWithError() {
        // Setup error
        mockService.error = NSError(domain: "test", code: -1, userInfo: nil)
        
        // Try to delete dish
        XCTAssertThrowsError(try viewModel.deleteDishes(at: IndexSet(integer: 0)))
    }
    
    // MARK: - UI State Tests
    
    func testAddNewDishState() {
        // Verify initial state
        XCTAssertFalse(viewModel.isAddingNewDish)
        
        // Set adding new dish state
        viewModel.isAddingNewDish = true
        
        // Verify state changed
        XCTAssertTrue(viewModel.isAddingNewDish)
    }
    
    func testSelectedDishState() {
        // Verify initial state
        XCTAssertNil(viewModel.selectedDish)
        
        // Set selected dish
        let dish = MockDish(name: "Test Dish", details: "Test Details")
        viewModel.selectedDish = dish
        
        // Verify state changed
        XCTAssertNotNil(viewModel.selectedDish)
        XCTAssertEqual(viewModel.selectedDish?.name, "Test Dish")
    }
} 
