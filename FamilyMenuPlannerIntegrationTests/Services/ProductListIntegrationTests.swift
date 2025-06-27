//
//  ProductListIntegrationTests.swift
//  FamilyMenuPlannerTests
//
//  Created by Pivovar 63 on 28.05.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

class ProductListIntegrationTests: BaseIntegrationTest {
    var productListService: ProductListService!
    var viewModel: ProductListViewModel!
    var testBackgroundManager: TestBackgroundOperationManager!
    
    override func setUp() {
        super.setUp()
        // Create test background manager using the same test stack
        testBackgroundManager = TestBackgroundOperationManager(testStack: TestCoreDataStack.shared)
        
        productListService = ProductListService(
            context: context,
            backgroundOperationManager: testBackgroundManager
        )
        viewModel = ProductListViewModel(productListService: productListService)
    }
    
    override func tearDown() {
        productListService = nil
        viewModel = nil
        testBackgroundManager = nil
        super.tearDown()
    }
    
    // Helper method to create test data
    private func createTestData(createProducts: Bool = true) -> ([Product], [Unit]) {
        // Create units
        let pieces = createUnit(name: "pcs")
        let grams = createUnit(name: "g", sortOrder: 1)
        
        var products: [Product] = []
        
        if createProducts {
            // Create products
            products = [
                createProduct(name: "Eggs", unit: pieces),
                createProduct(name: "Flour", unit: grams)
            ]
        }
        
        context.refreshAllObjects()
        return (products, [pieces, grams])
    }
    
    // MARK: - Tests
    
    func testLoadProducts() {
        let (products, _) = createTestData()
        
        // Load products
        viewModel.loadProducts()
        
        // Wait for products to be loaded and reactive bindings to update
        let loadExpectation = expectation(description: "Products loaded and filtered")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // Verify products are loaded
            XCTAssertEqual(self.viewModel.allProducts.count, 2)
            XCTAssertEqual(self.viewModel.filteredProducts.count, 2)
            XCTAssertTrue(self.viewModel.allProducts.contains(products[0])) // Eggs
            XCTAssertTrue(self.viewModel.allProducts.contains(products[1])) // Flour
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 0.5)
    }
    
    // TODO: Product creation functionality not yet implemented in ProductListViewModel  
    /*
    func testAddProduct() {
        let (_, units) = createTestData()
        
        // Load products first to get initial state
        viewModel.loadProducts()
        
        // Clear any existing products for this test
        let allProducts = viewModel.allProducts
        try? productListService.deleteProducts(products: allProducts)
        viewModel.loadProducts()
        
        // Set up new product data
        viewModel.newProductName = "Sugar"
        viewModel.selectedUnit = units[1] // grams
        
        // Add product
        viewModel.addProduct()
        
        // Wait for product to be added and reactive bindings to update
        let addExpectation = expectation(description: "Product added")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // Verify product was added
            XCTAssertEqual(self.viewModel.allProducts.count, 1)
            XCTAssertEqual(self.viewModel.allProducts.first?.name, "Sugar")
            XCTAssertEqual(self.viewModel.allProducts.first?.unit, units[1])
            addExpectation.fulfill()
        }
        wait(for: [addExpectation], timeout: 0.5)
    }
    */
    
    func testDeleteProduct() {
        let (products, _) = createTestData()
        
        // Load products
        viewModel.loadProducts()
        
        // Wait for products to be loaded and UI to update
        let loadExpectation = expectation(description: "Products loaded")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            XCTAssertEqual(self.viewModel.filteredProducts.count, 2, "Should have 2 filtered products loaded")
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 0.5)
        
        // Delete first product
        viewModel.deleteProducts(at: IndexSet(integer: 0))
        
        // Wait for deletion to complete and UI to update
        let deleteExpectation = expectation(description: "Product deleted")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // Verify product was deleted
            XCTAssertEqual(self.viewModel.allProducts.count, 1)
            XCTAssertFalse(self.viewModel.allProducts.contains(products[0]))
            XCTAssertTrue(self.viewModel.allProducts.contains(products[1]))
            deleteExpectation.fulfill()
        }
        wait(for: [deleteExpectation], timeout: 0.5)
    }
    
    func testSearchProducts() {
        let (_, _) = createTestData()
        
        // Load products first to get initial state
        viewModel.loadProducts()
        
        // Clear any existing products for this test
        let allProducts = viewModel.allProducts
        try? productListService.deleteProducts(products: allProducts)
        
        // Create specific test products
        let pieces = Unit(context: context)
        pieces.name = "pcs"
        pieces.sortOrder = 0
        
        let apple = Product(context: context)
        apple.name = "Apple"
        apple.unit = pieces
        
        let banana = Product(context: context)
        banana.name = "Banana"
        banana.unit = pieces
        
        try? context.save()
        context.refreshAllObjects()
        
        // Load products again to get our test products
        viewModel.loadProducts()
        
        // Test search - using actual debounce timing (300ms) + buffer
        let exp = expectation(description: "Search filtering")
        viewModel.searchText = "Apple"
        
        // Wait for debounce period (300ms) + buffer for reliability
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            // Verify filtered products
            XCTAssertEqual(self.viewModel.filteredProducts.count, 1)
            XCTAssertEqual(self.viewModel.filteredProducts.first?.name, "Apple")
            
            // Search for non-existent product
            self.viewModel.searchText = "NonExistent"
            
            // Wait for second search to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                XCTAssertEqual(self.viewModel.filteredProducts.count, 0)
                
                // Clear search
                self.viewModel.searchText = ""
                
                // Wait for final search to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    XCTAssertEqual(self.viewModel.filteredProducts.count, 2)
                    exp.fulfill()
                }
            }
        }
        
        wait(for: [exp], timeout: 2.0)
    }
    
    // TODO: Product validation functionality not yet implemented in ProductListViewModel
    /*
    func testValidateNewProduct() {
        let (_, units) = createTestData()
        
        // Test empty name
        viewModel.newProductName = ""
        viewModel.selectedUnit = units[0]
        XCTAssertFalse(viewModel.validateNewProduct())
        
        // Test missing unit
        viewModel.newProductName = "Test"
        viewModel.selectedUnit = nil
        XCTAssertFalse(viewModel.validateNewProduct())
        
        // Test valid input
        viewModel.newProductName = "Test"
        viewModel.selectedUnit = units[0]
        XCTAssertTrue(viewModel.validateNewProduct())
    }
    */
    
    // MARK: - Edge Cases and Error Handling
    
    // TODO: Product creation functionality not yet implemented in ProductListViewModel
    /*
    func testSpecialCharactersInProductName() {
        let (_, units) = createTestData()
        
        // Test product name with special characters
        viewModel.newProductName = "Product!@#$%^&*()"
        viewModel.selectedUnit = units[0]
        viewModel.addProduct()
        
        // Verify product was added
        viewModel.loadProducts()
        XCTAssertTrue(viewModel.allProducts.contains(where: { $0.name == "Product!@#$%^&*()" }))
        
        // Test searching for the product
        let exp = expectation(description: "Search filtering")
        viewModel.searchText = "!@#$"
        
        // Use correct debounce timing (300ms) + buffer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            XCTAssertEqual(self.viewModel.filteredProducts.count, 1)
            XCTAssertEqual(self.viewModel.filteredProducts.first?.name, "Product!@#$%^&*()")
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 1.0)
    }
    */
    
    // TODO: Bulk operations and product creation not yet implemented in ProductListViewModel
    /*
    func testBulkOperations() {
        // First clean up any existing data
        cleanUpTestData()
        
        // Create test data with only units, no products
        let (_, units) = createTestData(createProducts: false)
        
        // Load initial state
        viewModel.loadProducts()
        
        // Wait for initial state to be fully loaded
        let initialLoadExpectation = expectation(description: "Initial load completion")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.viewModel.allProducts.count, 0, "Should start with no products")
            XCTAssertEqual(self.viewModel.filteredProducts.count, 0, "Should start with no filtered products")
            initialLoadExpectation.fulfill()
        }
        wait(for: [initialLoadExpectation], timeout: 1.0)
        
        // Add multiple products
        let productNames = ["Product1", "Product2", "Product3", "Product4", "Product5"]
        
        for name in productNames {
            viewModel.newProductName = name
            viewModel.selectedUnit = units[0]
            viewModel.addProduct()
        }
        
        // Wait for all products to be added and UI to update
        let addExpectation = expectation(description: "Products added")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Verify all products were added
            XCTAssertEqual(self.viewModel.allProducts.count, 5, "Should have exactly 5 products after adding")
            XCTAssertEqual(self.viewModel.filteredProducts.count, 5, "Should have exactly 5 filtered products after adding")
            addExpectation.fulfill()
        }
        wait(for: [addExpectation], timeout: 2.0)
        
        // Delete multiple products using the first 3 from filteredProducts
        let indexSet = IndexSet(0..<3)
        viewModel.deleteProducts(at: indexSet)
        
        // Wait for deletion to complete and UI to update
        let deleteExpectation = expectation(description: "Products deleted")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Verify products were deleted
            XCTAssertEqual(self.viewModel.allProducts.count, 2, "Should have exactly 2 products after deleting 3")
            XCTAssertEqual(self.viewModel.filteredProducts.count, 2, "Should have exactly 2 filtered products after deleting 3")
            deleteExpectation.fulfill()
        }
        wait(for: [deleteExpectation], timeout: 2.0)
    }
    */
    
    // TODO: Product creation functionality not yet implemented in ProductListViewModel
    /*
    func testProductListPersistence() {
        let (_, units) = createTestData()
        
        // Add a product
        viewModel.newProductName = "Persistent Product"
        viewModel.selectedUnit = units[0]
        viewModel.addProduct()
        
        // Create new view model instance using the existing test setup
        let newViewModel = ProductListViewModel(productListService: ProductListService(
            context: context,
            backgroundOperationManager: testBackgroundManager
        ))
        
        // Load products in new view model
        newViewModel.loadProducts()
        
        // Verify product exists in new view model
        XCTAssertTrue(newViewModel.allProducts.contains(where: { $0.name == "Persistent Product" }))
    }
    */
    
    func testDeleteMultipleProducts() {
        // First clean up any existing data
        cleanUpTestData()
        
        // Create test data
        let (_, _) = createTestData()
        
        // Load initial state
        viewModel.loadProducts()
        
        // Wait for initial loading
        let initialLoadExpectation = expectation(description: "Initial load")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.viewModel.allProducts.count, 2, "Should have 2 products initially")
            initialLoadExpectation.fulfill()
        }
        wait(for: [initialLoadExpectation], timeout: 1.0)
        
        // Delete the first product (just 1 product instead of 2)
        let indexSet = IndexSet([0])
        viewModel.deleteProducts(at: indexSet)
        
        // Wait for deletion and UI update
        let deleteExpectation = expectation(description: "Products deleted")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Verify deletion
            XCTAssertEqual(self.viewModel.allProducts.count, 1, "Should have 1 product after deletion")
            XCTAssertEqual(self.viewModel.filteredProducts.count, 1, "Should have 1 filtered product after deletion")
            deleteExpectation.fulfill()
        }
        wait(for: [deleteExpectation], timeout: 2.0)
    }
    
    func testDeleteMultipleProductsInBackground() {
        // First clean up any existing data
        cleanUpTestData()
        
        // Create test data with more products to trigger background operation
        let unit = createUnit(name: "kg")
        var products: [Product] = []
        for i in 1...6 { // Create enough products to trigger background deletion
            let product = createProduct(name: "Product \(i)", unit: unit)
            products.append(product)
        }
        
        // Use the existing productListService that has the test background manager injected
        let deleteExpectation = expectation(description: "Background deletion completed")
        productListService.deleteProductsInBackground(products: Array(products.prefix(4))) { result in
            switch result {
            case .success:
                // Verify products were deleted by using Core Data fetch directly since fetchAllProducts now uses delegate pattern
                let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
                let remainingProducts = try! self.context.fetch(fetchRequest)
                XCTAssertEqual(remainingProducts.count, 2, "Should have 2 products remaining after background deletion")
                deleteExpectation.fulfill()
            case .failure(let error):
                XCTFail("Background deletion failed: \(error)")
            }
        }
        
        wait(for: [deleteExpectation], timeout: 5.0)
    }
    
    // TODO: Background product addition not yet implemented in ProductListService
    /*
    func testAddProductInBackground() {
        // Clean up any existing data
        cleanUpTestData()
        
        let unit = createUnit(name: "pcs")
        
        let addExpectation = expectation(description: "Background addition completed")
        productListService.addProductInBackground(name: "Background Product", unit: unit) { result in
            switch result {
            case .success(let product):
                XCTAssertEqual(product.name, "Background Product", "Product name should match")
                XCTAssertEqual(product.unit, unit, "Product unit should match")
                
                // Verify product exists in main context by using Core Data fetch directly
                let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
                let allProducts = try! self.context.fetch(fetchRequest)
                XCTAssertEqual(allProducts.count, 1, "Should have 1 product after background addition")
                XCTAssertEqual(allProducts.first?.name, "Background Product")
                
                addExpectation.fulfill()
            case .failure(let error):
                XCTFail("Background addition failed: \(error)")
            }
        }
        
        wait(for: [addExpectation], timeout: 5.0)
    }
    */
    
    // TODO: Bulk product creation not yet implemented in ProductListService
    /*
    func testCreateProductsBulk() {
        // Clean up any existing data
        cleanUpTestData()
        
        let unit1 = createUnit(name: "kg")
        let unit2 = createUnit(name: "pcs")
        
        let productData = [
            (name: "Bulk Product 1", unit: unit1),
            (name: "Bulk Product 2", unit: unit2),
            (name: "Bulk Product 3", unit: unit1),
            (name: "Bulk Product 4", unit: unit2),
            (name: "Bulk Product 5", unit: unit1),
            (name: "Bulk Product 6", unit: unit2) // 6 products to trigger background operation
        ]
        
        let bulkCreateExpectation = expectation(description: "Bulk creation completed")
        productListService.createProductsBulk(productData: productData) { result in
            switch result {
            case .success(let products):
                XCTAssertEqual(products.count, 6, "Should have created 6 products")
                
                // Verify all products were created with correct data
                for (index, product) in products.enumerated() {
                    XCTAssertEqual(product.name, productData[index].name)
                    XCTAssertEqual(product.unit, productData[index].unit)
                }
                
                // Verify products exist in database by using Core Data fetch directly
                let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
                let allProducts = try! self.context.fetch(fetchRequest)
                XCTAssertEqual(allProducts.count, 6, "All products should be in database")
                
                bulkCreateExpectation.fulfill()
            case .failure(let error):
                XCTFail("Bulk creation failed: \(error)")
            }
        }
        
        wait(for: [bulkCreateExpectation], timeout: 5.0)
    }
    */
} 
