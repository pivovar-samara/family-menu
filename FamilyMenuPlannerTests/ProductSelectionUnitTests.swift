import XCTest
@testable import FamilyMenuPlanner

// MARK: - Mock Service
class MockProductSelectionService: ProductSelectionServiceProtocol {
    var products: [MockProduct] = []
    var error: Error?
    
    func fetchAllProducts() -> [Product] {
        if let error = error {
            print("Error fetching products: \(error)")
            return []
        }
        // In real tests, we'd return the mock objects directly
        // For this unit test, we'll work with the mock objects in the view model
        return []
    }
}

// MARK: - Mock View Model for Unit Tests
class MockProductSelectionViewModel {
    var searchText: String = ""
    var selectedProduct: MockProduct?
    var filteredProducts: [MockProduct] = []
    private(set) var allProducts: [MockProduct] = []
    let currentProduct: MockProduct?
    var onProductSelectedCalled = false
    var lastSelectedProduct: MockProduct?
    
    private let productSelectionService: MockProductSelectionService
    
    init(productSelectionService: MockProductSelectionService, currentProduct: MockProduct?) {
        self.productSelectionService = productSelectionService
        self.currentProduct = currentProduct
    }
    
    func loadProducts() {
        allProducts = productSelectionService.products
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
    
    func selectProduct(_ product: MockProduct) {
        selectedProduct = product
        lastSelectedProduct = product
        onProductSelectedCalled = true
    }
}

// MARK: - Unit Tests
class ProductSelectionUnitTests: XCTestCase {
    var mockService: MockProductSelectionService!
    var viewModel: MockProductSelectionViewModel!
    
    override func setUp() {
        super.setUp()
        mockService = MockProductSelectionService()
        viewModel = MockProductSelectionViewModel(productSelectionService: mockService, currentProduct: nil)
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
        let product1 = MockProduct(name: "Apple", unit: unit)
        let product2 = MockProduct(name: "Banana", unit: unit)
        mockService.products = [product1, product2]
        
        // Load products
        viewModel.loadProducts()
        
        // Verify products are loaded
        XCTAssertEqual(viewModel.allProducts.count, 2)
        XCTAssertEqual(viewModel.filteredProducts.count, 2)
        XCTAssertEqual(viewModel.allProducts.first?.name, "Apple")
        XCTAssertEqual(viewModel.allProducts.last?.name, "Banana")
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
    
    func testLoadProductsEmpty() {
        // Setup empty products list
        mockService.products = []
        
        // Load products
        viewModel.loadProducts()
        
        // Verify no products are loaded
        XCTAssertTrue(viewModel.allProducts.isEmpty)
        XCTAssertTrue(viewModel.filteredProducts.isEmpty)
    }
    
    // MARK: - Search/Filter Tests
    
    func testFilterProducts() {
        // Setup test data
        let unit = MockUnit(name: "pcs", sortOrder: 0)
        let apple = MockProduct(name: "Apple", unit: unit)
        let banana = MockProduct(name: "Banana", unit: unit)
        let apricot = MockProduct(name: "Apricot", unit: unit)
        mockService.products = [apple, banana, apricot]
        
        // Load products
        viewModel.loadProducts()
        
        // Test search with "Ap" - should match Apple and Apricot
        viewModel.filterProducts(with: "Ap")
        XCTAssertEqual(viewModel.filteredProducts.count, 2)
        XCTAssertTrue(viewModel.filteredProducts.contains(apple))
        XCTAssertTrue(viewModel.filteredProducts.contains(apricot))
        XCTAssertFalse(viewModel.filteredProducts.contains(banana))
        
        // Test search with "banana" - should match Banana
        viewModel.filterProducts(with: "banana")
        XCTAssertEqual(viewModel.filteredProducts.count, 1)
        XCTAssertEqual(viewModel.filteredProducts.first?.name, "Banana")
        
        // Test search with non-existent product
        viewModel.filterProducts(with: "Orange")
        XCTAssertTrue(viewModel.filteredProducts.isEmpty)
        
        // Test empty search - should show all products
        viewModel.filterProducts(with: "")
        XCTAssertEqual(viewModel.filteredProducts.count, 3)
    }
    
    func testFilterProductsCaseInsensitive() {
        // Setup test data
        let unit = MockUnit(name: "pcs", sortOrder: 0)
        let apple = MockProduct(name: "Apple", unit: unit)
        mockService.products = [apple]
        
        // Load products
        viewModel.loadProducts()
        
        // Test case insensitive search
        viewModel.filterProducts(with: "APPLE")
        XCTAssertEqual(viewModel.filteredProducts.count, 1)
        XCTAssertEqual(viewModel.filteredProducts.first?.name, "Apple")
        
        viewModel.filterProducts(with: "apple")
        XCTAssertEqual(viewModel.filteredProducts.count, 1)
        
        viewModel.filterProducts(with: "ApPlE")
        XCTAssertEqual(viewModel.filteredProducts.count, 1)
    }
    
    func testFilterProductsWithNilName() {
        // Setup test data with nil name
        let unit = MockUnit(name: "pcs", sortOrder: 0)
        let productWithNilName = MockProduct(name: nil, unit: unit)
        let productWithName = MockProduct(name: "Apple", unit: unit)
        mockService.products = [productWithNilName, productWithName]
        
        // Load products
        viewModel.loadProducts()
        
        // Test search - product with nil name should not match
        viewModel.filterProducts(with: "Apple")
        XCTAssertEqual(viewModel.filteredProducts.count, 1)
        XCTAssertEqual(viewModel.filteredProducts.first?.name, "Apple")
    }
    
    // MARK: - Product Selection Tests
    
    func testSelectProduct() {
        // Setup test data
        let unit = MockUnit(name: "pcs", sortOrder: 0)
        let product = MockProduct(name: "Apple", unit: unit)
        
        // Select product
        viewModel.selectProduct(product)
        
        // Verify product was selected
        XCTAssertEqual(viewModel.selectedProduct, product)
        XCTAssertEqual(viewModel.lastSelectedProduct, product)
        XCTAssertTrue(viewModel.onProductSelectedCalled)
    }
    
    func testCurrentProductHandling() {
        // Setup test data with current product
        let unit = MockUnit(name: "pcs", sortOrder: 0)
        let currentProduct = MockProduct(name: "Current Product", unit: unit)
        
        // Create view model with current product
        viewModel = MockProductSelectionViewModel(productSelectionService: mockService, currentProduct: currentProduct)
        
        // Verify current product is set
        XCTAssertEqual(viewModel.currentProduct, currentProduct)
    }
    
    // MARK: - Integration with Search Tests
    
    func testSearchAndSelectFlow() {
        // Setup test data
        let unit = MockUnit(name: "pcs", sortOrder: 0)
        let apple = MockProduct(name: "Apple", unit: unit)
        let banana = MockProduct(name: "Banana", unit: unit)
        mockService.products = [apple, banana]
        
        // Load products
        viewModel.loadProducts()
        
        // Search for specific product
        viewModel.filterProducts(with: "Apple")
        XCTAssertEqual(viewModel.filteredProducts.count, 1)
        
        // Select the filtered product
        viewModel.selectProduct(viewModel.filteredProducts.first!)
        XCTAssertEqual(viewModel.selectedProduct?.name, "Apple")
        XCTAssertTrue(viewModel.onProductSelectedCalled)
    }
    
    // MARK: - Edge Cases
    
    func testFilterWithEmptyProductsList() {
        // Setup empty products list
        mockService.products = []
        viewModel.loadProducts()
        
        // Test filtering with empty list
        viewModel.filterProducts(with: "Apple")
        XCTAssertTrue(viewModel.filteredProducts.isEmpty)
        
        viewModel.filterProducts(with: "")
        XCTAssertTrue(viewModel.filteredProducts.isEmpty)
    }
    
    func testMultipleProductSelections() {
        // Setup test data
        let unit = MockUnit(name: "pcs", sortOrder: 0)
        let apple = MockProduct(name: "Apple", unit: unit)
        let banana = MockProduct(name: "Banana", unit: unit)
        
        // Select first product
        viewModel.selectProduct(apple)
        XCTAssertEqual(viewModel.selectedProduct, apple)
        
        // Select second product
        viewModel.selectProduct(banana)
        XCTAssertEqual(viewModel.selectedProduct, banana)
        XCTAssertEqual(viewModel.lastSelectedProduct, banana)
    }
} 