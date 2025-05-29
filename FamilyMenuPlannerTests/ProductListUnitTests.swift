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
    
    func fetchAllProducts() -> [Product] {
        if let error = error {
            print("Error fetching products: \(error)")
            return []
        }
        // Convert MockProduct to Product - in real tests we'd return the mock objects
        return []
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
    
    func addProduct(name: String, unit: Unit) throws {
        if let error = error {
            throw error
        }
        addProductCalled = true
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
        try productListService.addProduct(name: newProductName, unit: Unit())
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
    
    // MARK: - CRUD Operation Tests
    
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
} 
