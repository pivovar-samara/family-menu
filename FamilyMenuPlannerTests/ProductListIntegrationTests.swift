//
//  ProductListIntegrationTests.swift
//  FamilyMenuPlannerTests
//
//  Created by Pivovar 63 on 28.05.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

class ProductListIntegrationTests: XCTestCase {
    var context: NSManagedObjectContext!
    var productListService: ProductListService!
    var viewModel: ProductListViewModel!
    
    override func setUp() {
        super.setUp()
        context = TestCoreDataStack.shared.viewContext
        productListService = ProductListService(context: context)
        viewModel = ProductListViewModel(productListService: productListService)
        
        cleanUpTestData()
    }
    
    override func tearDown() {
        cleanUpTestData()
        context = nil
        productListService = nil
        viewModel = nil
        super.tearDown()
    }
    
    private func cleanUpTestData() {
        let entities = ["Product", "Unit"]
        
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
        
        try? context.save()
    }
    
    // Helper method to create test data
    private func createTestData(createProducts: Bool = true) -> ([Product], [Unit]) {
        // Create units
        let pieces = Unit(context: context)
        pieces.name = "pcs"
        pieces.sortOrder = 0
        
        let grams = Unit(context: context)
        grams.name = "g"
        grams.sortOrder = 1
        
        var products: [Product] = []
        
        if createProducts {
            // Create products
            let eggs = Product(context: context)
            eggs.name = "Eggs"
            eggs.unit = pieces
            
            let flour = Product(context: context)
            flour.name = "Flour"
            flour.unit = grams
            
            products = [eggs, flour]
        }
        
        try? context.save()
        context.refreshAllObjects()
        
        return (products, [pieces, grams])
    }
    
    // MARK: - Tests
    
    func testLoadProducts() {
        let (products, _) = createTestData()
        
        // Load products
        viewModel.loadProducts()
        
        // Verify products are loaded
        XCTAssertEqual(viewModel.allProducts.count, 2)
        XCTAssertEqual(viewModel.filteredProducts.count, 2)
        XCTAssertTrue(viewModel.allProducts.contains(products[0])) // Eggs
        XCTAssertTrue(viewModel.allProducts.contains(products[1])) // Flour
    }
    
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
        
        // Verify product was added
        XCTAssertEqual(viewModel.allProducts.count, 1)
        XCTAssertEqual(viewModel.allProducts.first?.name, "Sugar")
        XCTAssertEqual(viewModel.allProducts.first?.unit, units[1])
    }
    
    func testDeleteProduct() {
        let (products, _) = createTestData()
        
        // Load products
        viewModel.loadProducts()
        
        // Delete first product
        viewModel.deleteProducts(at: IndexSet(integer: 0))
        
        // Verify product was deleted
        XCTAssertEqual(viewModel.allProducts.count, 1)
        XCTAssertFalse(viewModel.allProducts.contains(products[0]))
        XCTAssertTrue(viewModel.allProducts.contains(products[1]))
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
        
        // Test search
        let exp = expectation(description: "Search filtering")
        viewModel.searchText = "Apple"
        
        // Wait for debounce period
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            // Verify filtered products
            XCTAssertEqual(self.viewModel.filteredProducts.count, 1)
            XCTAssertEqual(self.viewModel.filteredProducts.first?.name, "Apple")
            
            // Search for non-existent product
            self.viewModel.searchText = "NonExistent"
            
            // Wait for second search to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                XCTAssertEqual(self.viewModel.filteredProducts.count, 0)
                
                // Clear search
                self.viewModel.searchText = ""
                
                // Wait for final search to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    XCTAssertEqual(self.viewModel.filteredProducts.count, 2)
                    exp.fulfill()
                }
            }
        }
        
        wait(for: [exp], timeout: 2)
    }
    
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
    
    // MARK: - Edge Cases and Error Handling
    
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            XCTAssertEqual(self.viewModel.filteredProducts.count, 1)
            XCTAssertEqual(self.viewModel.filteredProducts.first?.name, "Product!@#$%^&*()")
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 2)
    }
    
    func testBulkOperations() {
        // First clean up any existing data
        cleanUpTestData()
        
        // Create test data with only units, no products
        let (_, units) = createTestData(createProducts: false)
        
        // Load initial state
        viewModel.loadProducts()
        XCTAssertEqual(viewModel.allProducts.count, 0, "Should start with no products")
        
        // Add multiple products
        let productNames = ["Product1", "Product2", "Product3", "Product4", "Product5"]
        
        for name in productNames {
            viewModel.newProductName = name
            viewModel.selectedUnit = units[0]
            viewModel.addProduct()
        }
        
        // Verify all products were added
        viewModel.loadProducts()
        XCTAssertEqual(viewModel.allProducts.count, 5, "Should have exactly 5 products after adding")
        
        // Delete multiple products
        let indexSet = IndexSet(0..<3)
        viewModel.deleteProducts(at: indexSet)
        
        // Verify products were deleted
        XCTAssertEqual(viewModel.allProducts.count, 2, "Should have exactly 2 products after deleting 3")
    }
    
    func testProductListPersistence() {
        let (_, units) = createTestData()
        
        // Add a product
        viewModel.newProductName = "Persistent Product"
        viewModel.selectedUnit = units[0]
        viewModel.addProduct()
        
        // Create new view model instance
        let newViewModel = ProductListViewModel(productListService: ProductListService(context: context))
        
        // Load products in new view model
        newViewModel.loadProducts()
        
        // Verify product exists in new view model
        XCTAssertTrue(newViewModel.allProducts.contains(where: { $0.name == "Persistent Product" }))
    }
} 
