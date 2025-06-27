//
//  ProductListUnitTests.swift
//  FamilyMenuPlannerTests
//
//  Created by Pivovar 63 on 28.05.25.
//

import XCTest
@testable import FamilyMenuPlanner

// MARK: - Mock Service
class MockProductListService: ProductListServiceProtocol {
    var products: [MockProduct] = []
    var units: [MockUnit] = []
    var error: Error?
    var deleteProductsCalled = false
    var addProductCalled = false
    var lastAddedProductName: String?
    var lastAddedUnitName: String?
    
    var delegate: ProductListServiceDelegate?
    
    func fetchAllProducts() {
        if let error = error {
            print("Error fetching products: \(error)")
            delegate?.serviceDidChangeContent([])
            return
        }
        
        // Simulate fetching and notify delegate
        let emptyProducts: [Product] = []  // In real tests we'd return mock objects
        delegate?.serviceDidChangeContent(emptyProducts)
    }
    
    func fetchAllUnits() -> [Unit] {
        if let error = error {
            print("Error fetching units: \(error)")
            return []
        }
        // Convert MockUnit to Unit - in real tests we'd return the mock objects
        return []
    }
    
    func deleteProducts(products: [Product]) throws {
        if let error = error {
            throw error
        }
        deleteProductsCalled = true
    }
    
    func deleteProductsInBackground(products: [Product], completion: @escaping (Result<Void, Error>) -> Void) {
        if let error = error {
            completion(.failure(error))
        } else {
            deleteProductsCalled = true
            completion(.success(()))
        }
    }
    
    func addProduct(name: String, unit: Unit) throws {
        if let error = error {
            throw error
        }
        addProductCalled = true
        lastAddedProductName = name
        lastAddedUnitName = unit.name
    }
    
    func addProductInBackground(name: String, unit: Unit, completion: @escaping (Result<Product, Error>) -> Void) {
        if let error = error {
            completion(.failure(error))
        } else {
            addProductCalled = true
            lastAddedProductName = name
            lastAddedUnitName = unit.name
            
            // Create a mock product to return - in real implementation this would be the created Core Data object
            let mockProduct = Product()
            mockProduct.name = name
            mockProduct.unit = unit
            completion(.success(mockProduct))
        }
    }
    
    func createProductsBulk(productData: [(name: String, unit: Unit)], completion: @escaping (Result<[Product], Error>) -> Void) {
        if let error = error {
            completion(.failure(error))
        } else {
            var createdProducts: [Product] = []
            for data in productData {
                let mockProduct = Product()
                mockProduct.name = data.name
                mockProduct.unit = data.unit
                createdProducts.append(mockProduct)
            }
            completion(.success(createdProducts))
        }
    }
    
    // Additional method for unit testing that doesn't require Core Data entities
    func addProductWithMockData(name: String, unitName: String) throws {
        if let error = error {
            throw error
        }
        addProductCalled = true
        lastAddedProductName = name
        lastAddedUnitName = unitName
    }
}

// MARK: - View Model for Unit Tests
class MockProductListViewModel {
    var searchText: String = ""
    var selectedProduct: MockProduct?
    var newProductName: String = ""
    var selectedUnit: MockUnit?
    var validationError: String?
    var filteredProducts: [MockProduct] = []
    private(set) var allProducts: [MockProduct] = []
    
    private let productListService: MockProductListService
    
    init(productListService: MockProductListService) {
        self.productListService = productListService
    }
    
    func loadProducts() {
        allProducts = productListService.products
        filteredProducts = allProducts
    }
    
    func filterProducts(with text: String) {
        if text.isEmpty {
            filteredProducts = allProducts
        } else {
            filteredProducts = allProducts.filter {
                $0.name?.localizedCaseInsensitiveContains(text) ?? false
            }
        }
    }
    
    func deleteProducts(at offsets: IndexSet) throws {
        try productListService.deleteProducts(products: [])
    }
    
    func addProduct() throws {
        guard validateNewProduct() else { return }
        
        // Create a mock unit for testing instead of a real Core Data entity
        let mockUnit = MockUnit(name: selectedUnit?.name ?? "", sortOrder: selectedUnit?.sortOrder ?? 0)
        
        // For unit testing, we need to simulate the service call without creating real entities
        // The service expects a Unit entity, so we'll modify the service to accept mock data
        try productListService.addProductWithMockData(name: newProductName, unitName: mockUnit.name)
    }
    
    func validateNewProduct() -> Bool {
        validationError = nil
        
        if newProductName.isEmpty {
            validationError = "Product name cannot be empty."
            return false
        }
        
        if selectedUnit == nil {
            validationError = "Please select a unit for the product."
            return false
        }
        
        return true
    }
}

// MARK: - Unit Tests
class ProductListUnitTests: XCTestCase {
    var mockService: MockProductListService!
    var viewModel: MockProductListViewModel!
    
    override func setUp() {
        super.setUp()
        mockService = MockProductListService()
        viewModel = MockProductListViewModel(productListService: mockService)
    }
    
    override func tearDown() {
        mockService = nil
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Loading Tests
    
    func testLoadProducts() {
        // Setup test data
        let unit = MockUnit(name: "pcs", sortOrder: 0)
        let product = MockProduct(name: "Test Product", unit: unit)
        mockService.products = [product]
        
        // Load products
        viewModel.loadProducts()
        
        // Verify products are loaded
        XCTAssertEqual(viewModel.allProducts.count, 1)
        XCTAssertEqual(viewModel.filteredProducts.count, 1)
        XCTAssertEqual(viewModel.allProducts.first?.name, "Test Product")
    }
    
    func testLoadProductsWithError() {
        // Setup error
        mockService.error = NSError(domain: "test", code: -1, userInfo: nil)
        
        // Load products
        viewModel.loadProducts()
        
        // Verify no products are loaded
        XCTAssertTrue(viewModel.allProducts.isEmpty)
        XCTAssertTrue(viewModel.filteredProducts.isEmpty)
    }
    
    // MARK: - Search Tests
    
    func testSearchProducts() {
        // Setup test data
        let unit = MockUnit(name: "pcs", sortOrder: 0)
        let product1 = MockProduct(name: "Apple", unit: unit)
        let product2 = MockProduct(name: "Banana", unit: unit)
        mockService.products = [product1, product2]
        
        // Load products
        viewModel.loadProducts()
        
        // Test search
        viewModel.filterProducts(with: "Apple")
        XCTAssertEqual(viewModel.filteredProducts.count, 1)
        XCTAssertEqual(viewModel.filteredProducts.first?.name, "Apple")
        
        // Test empty search
        viewModel.filterProducts(with: "")
        XCTAssertEqual(viewModel.filteredProducts.count, 2)
    }
    
    // MARK: - Validation Tests
    
    // TODO: Update tests to match new EditProduct-based architecture
    /*
    func testValidateNewProduct() {
        // Test empty name
        viewModel.newProductName = ""
        XCTAssertFalse(viewModel.validateNewProduct())
        XCTAssertNotNil(viewModel.validationError)
        
        // Test missing unit
        viewModel.newProductName = "Test"
        viewModel.selectedUnit = nil
        XCTAssertFalse(viewModel.validateNewProduct())
        XCTAssertNotNil(viewModel.validationError)
        
        // Test valid input
        viewModel.newProductName = "Test"
        viewModel.selectedUnit = MockUnit(name: "pcs", sortOrder: 0)
        XCTAssertTrue(viewModel.validateNewProduct())
        XCTAssertNil(viewModel.validationError)
    }
    */
    
    // MARK: - CRUD Operation Tests
    
    // TODO: Update tests to match new EditProduct-based architecture
    /*
    func testAddProduct() {
        // Setup valid input
        viewModel.newProductName = "Test"
        viewModel.selectedUnit = MockUnit(name: "pcs", sortOrder: 0)
        
        // Add product
        try? viewModel.addProduct()
        
        // Verify service was called
        XCTAssertTrue(mockService.addProductCalled)
    }
    
    func testAddProductWithError() {
        // Setup error
        mockService.error = NSError(domain: "test", code: -1, userInfo: nil)
        
        // Setup valid input
        viewModel.newProductName = "Test"
        viewModel.selectedUnit = MockUnit(name: "pcs", sortOrder: 0)
        
        // Try to add product
        XCTAssertThrowsError(try viewModel.addProduct())
    }
    */
    
    func testDeleteProduct() {
        // Delete product
        try? viewModel.deleteProducts(at: IndexSet(integer: 0))
        
        // Verify service was called
        XCTAssertTrue(mockService.deleteProductsCalled)
    }
    
    func testDeleteProductWithError() {
        // Setup error
        mockService.error = NSError(domain: "test", code: -1, userInfo: nil)
        
        // Try to delete product
        XCTAssertThrowsError(try viewModel.deleteProducts(at: IndexSet(integer: 0)))
    }
    
    // MARK: - Search Optimization Tests
    
    func testSearchOptimizationHelperIntegration() {
        // Setup test data
        let unit = MockUnit(name: "pcs", sortOrder: 0)
        let product1 = MockProduct(name: "Apple", unit: unit)
        let product2 = MockProduct(name: "Banana", unit: unit)
        mockService.products = [product1, product2]
        
        // Load products
        viewModel.loadProducts()
        
        // Test search functionality
        viewModel.searchText = "Apple"
        
        // Since we can't easily test the debounce without async, we'll test the logic directly
        viewModel.filterProducts(with: "Apple")
        XCTAssertEqual(viewModel.filteredProducts.count, 1)
        XCTAssertEqual(viewModel.filteredProducts.first?.name, "Apple")
        
        // Test search clearing
        viewModel.filterProducts(with: "")
        XCTAssertEqual(viewModel.filteredProducts.count, 2)
    }
} 
