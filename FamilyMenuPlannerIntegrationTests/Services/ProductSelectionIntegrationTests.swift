import XCTest
import CoreData
@testable import FamilyMenuPlanner

class ProductSelectionIntegrationTests: BaseIntegrationTest {
    var productSelectionService: ProductSelectionService!
    var viewModel: ProductSelectionViewModel!
    var productSelectedCallback: ((Product) -> Void)!
    var selectedProduct: Product?
    var onProductsSelected: (([Product]) -> Void)?
    
    override func setUp() {
        super.setUp()
        productSelectionService = ProductSelectionService(context: context)
        
        // Setup callback to capture selected product
        productSelectedCallback = { [weak self] product in
            self?.selectedProduct = product
        }
        
        viewModel = ProductSelectionViewModel(
            productSelectionService: productSelectionService,
            currentProduct: nil,
            onProductSelected: productSelectedCallback
        )
    }
    
    override func tearDown() {
        productSelectionService = nil
        viewModel = nil
        productSelectedCallback = nil
        selectedProduct = nil
        super.tearDown()
    }
    
    // Helper method to create test data
    private func createTestData() -> (products: [Product], units: [Unit]) {
        // Create units
        let pieces = createUnit(name: "pcs", sortOrder: 0)
        let grams = createUnit(name: "g", sortOrder: 1)
        let liters = createUnit(name: "l", sortOrder: 2)
        
        // Create products
        let apple = createProduct(name: "Apple", unit: pieces)
        let banana = createProduct(name: "Banana", unit: pieces)
        let flour = createProduct(name: "Flour", unit: grams)
        let milk = createProduct(name: "Milk", unit: liters)
        let apricot = createProduct(name: "Apricot", unit: pieces)
        
        context.refreshAllObjects()
        return ([apple, banana, flour, milk, apricot], [pieces, grams, liters])
    }
    
    // MARK: - Service Tests
    
    func testServiceFetchAllProducts() {
        let (products, _) = createTestData()
        
        // Fetch products using service
        let fetchedProducts = productSelectionService.fetchAllProducts()
        
        // Verify all products are fetched and sorted by name
        XCTAssertEqual(fetchedProducts.count, 5)
        XCTAssertEqual(fetchedProducts[0].name, "Apple")
        XCTAssertEqual(fetchedProducts[1].name, "Apricot")
        XCTAssertEqual(fetchedProducts[2].name, "Banana")
        XCTAssertEqual(fetchedProducts[3].name, "Flour")
        XCTAssertEqual(fetchedProducts[4].name, "Milk")
        
        // Verify all created products are included
        for product in products {
            XCTAssertTrue(fetchedProducts.contains(product))
        }
    }

    // MARK: - Draft Filtering Tests

    func testServiceFetchAllProductsExcludesDrafts() {
        // Create complete products
        let pieces = createUnit(name: "pcs")
        let completeProduct = createProduct(name: "Complete Product", unit: pieces)

        // Create draft product
        let draftProduct = createProduct(name: "Draft Product", unit: pieces)
        draftProduct.isDraft = true
        XCTAssertNoThrow(try context.save())

        // Fetch products using service
        let fetchedProducts = productSelectionService.fetchAllProducts()

        // Verify only non-draft product is returned
        XCTAssertTrue(fetchedProducts.contains(completeProduct))
        XCTAssertFalse(fetchedProducts.contains(draftProduct))
        XCTAssertEqual(fetchedProducts.count, 1)
    }
    
    func testServiceFetchProductsEmpty() {
        // No products created
        let fetchedProducts = productSelectionService.fetchAllProducts()
        
        // Verify empty result
        XCTAssertTrue(fetchedProducts.isEmpty)
    }
    
    func testServiceFetchProductsSorting() {
        // Create products in different order
        let unit = createUnit(name: "pcs")
        _ = createProduct(name: "Zebra Product", unit: unit)
        _ = createProduct(name: "Apple", unit: unit)
        _ = createProduct(name: "Banana", unit: unit)
        
        context.refreshAllObjects()
        
        // Fetch products
        let fetchedProducts = productSelectionService.fetchAllProducts()
        
        // Verify alphabetical sorting
        XCTAssertEqual(fetchedProducts.count, 3)
        XCTAssertEqual(fetchedProducts[0].name, "Apple")
        XCTAssertEqual(fetchedProducts[1].name, "Banana")
        XCTAssertEqual(fetchedProducts[2].name, "Zebra Product")
    }
    
    // MARK: - ViewModel Loading Tests
    
    func testViewModelLoadProducts() {
        let (_, _) = createTestData()
        
        // Load products through view model
        viewModel.loadProducts()
        
        // Wait for reactive bindings to complete
        let expectation = XCTestExpectation(description: "Products loaded and filtered")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Verify products are loaded
            XCTAssertEqual(self.viewModel.allProducts.count, 5)
            XCTAssertEqual(self.viewModel.filteredProducts.count, 5)
            
            // Verify sorting (Apple, Apricot, Banana, Flour, Milk)
            XCTAssertEqual(self.viewModel.allProducts[0].name, "Apple")
            XCTAssertEqual(self.viewModel.allProducts[1].name, "Apricot")
            XCTAssertEqual(self.viewModel.allProducts[2].name, "Banana")
            XCTAssertEqual(self.viewModel.allProducts[3].name, "Flour")
            XCTAssertEqual(self.viewModel.allProducts[4].name, "Milk")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testViewModelLoadProductsEmpty() {
        // No products created
        viewModel.loadProducts()
        
        // Verify empty state
        XCTAssertTrue(viewModel.allProducts.isEmpty)
        XCTAssertTrue(viewModel.filteredProducts.isEmpty)
    }
    
    // MARK: - Search/Filter Integration Tests
    
    func testViewModelSearchProducts() {
        let (_, _) = createTestData()
        viewModel.loadProducts()
        
        // Test search functionality with real Core Data
        let exp = expectation(description: "Search filtering")
        
        // Set search text - this should trigger the debounce mechanism
        viewModel.searchText = "Ap"
        
        // Wait for debounce period (0.3 seconds + buffer)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Verify Apple and Apricot are found (both contain "ap")
            XCTAssertEqual(self.viewModel.filteredProducts.count, 2)
            let foundNames = self.viewModel.filteredProducts.map { $0.name ?? "" }.sorted()
            XCTAssertEqual(foundNames, ["Apple", "Apricot"])
            
            // Test exact match
            self.viewModel.searchText = "Flour"
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                XCTAssertEqual(self.viewModel.filteredProducts.count, 1)
                XCTAssertEqual(self.viewModel.filteredProducts.first?.name, "Flour")
                
                // Test no results
                self.viewModel.searchText = "NonExistent"
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    XCTAssertTrue(self.viewModel.filteredProducts.isEmpty)
                    
                    // Test empty search - should show all
                    self.viewModel.searchText = ""
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        XCTAssertEqual(self.viewModel.filteredProducts.count, 5)
                        exp.fulfill()
                    }
                }
            }
        }
        
        wait(for: [exp], timeout: 3)
    }
    
    func testViewModelSearchCaseInsensitive() {
        let (_, _) = createTestData()
        viewModel.loadProducts()
        
        let exp = expectation(description: "Case insensitive search")
        
        // Test case insensitive search
        viewModel.searchText = "BANANA"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.viewModel.filteredProducts.count, 1)
            XCTAssertEqual(self.viewModel.filteredProducts.first?.name, "Banana")
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 2)
    }
    
    // MARK: - Product Selection Tests
    
    func testProductSelectionCallback() {
        let (products, _) = createTestData()
        viewModel.loadProducts()
        
        // Select a product
        let selectedProduct = products[0] // Apple
        viewModel.onProductSelected(selectedProduct)
        
        // Verify callback was called and product was captured
        XCTAssertEqual(self.selectedProduct, selectedProduct)
        XCTAssertEqual(self.selectedProduct?.name, "Apple")
    }
    
    func testCurrentProductHandling() {
        let (products, _) = createTestData()
        let currentProduct = products[1] // Banana
        
        // Create view model with current product
        viewModel = ProductSelectionViewModel(
            productSelectionService: productSelectionService,
            currentProduct: currentProduct,
            onProductSelected: productSelectedCallback
        )
        
        // Verify current product is set
        XCTAssertEqual(viewModel.currentProduct, currentProduct)
        XCTAssertEqual(viewModel.currentProduct?.name, "Banana")
    }
    
    // MARK: - Integration Flow Tests
    
    func testCompleteProductSelectionFlow() {
        let (_, _) = createTestData()
        
        // 1. Load products
        viewModel.loadProducts()
        
        // Wait for products to load before proceeding with search
        let loadExp = expectation(description: "Products loaded")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.viewModel.allProducts.count, 5)
            loadExp.fulfill()
        }
        wait(for: [loadExp], timeout: 1.0)
        
        // 2. Search for specific product
        let exp = expectation(description: "Complete flow")
        viewModel.searchText = "Flour"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 3. Verify search results
            XCTAssertEqual(self.viewModel.filteredProducts.count, 1)
            XCTAssertEqual(self.viewModel.filteredProducts.first?.name, "Flour")
            
            // 4. Select the product
            let productToSelect = self.viewModel.filteredProducts.first!
            self.viewModel.onProductSelected(productToSelect)
            
            // 5. Verify selection
            XCTAssertEqual(self.selectedProduct, productToSelect)
            XCTAssertEqual(self.selectedProduct?.name, "Flour")
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 2)
    }

    func testAddNewProductFromSelectionFlow() {
        // Ensure there is at least one unit to assign
        _ = createUnit(name: "pcs")
        context.refreshAllObjects()
        
        // 1. Start with empty products
        viewModel.loadProducts()
        XCTAssertTrue(viewModel.allProducts.isEmpty)
        
        // 2. Open add sheet via view model flag
        viewModel.isAddingNewProduct = true
        
        // 3. Simulate creating a product via EditProduct flow
        let editService = EditProductService(context: context)
        let editVM = EditProductViewModel(product: nil, editProductService: editService)
        editVM.loadProduct()
        editVM.product?.name = "Selection Created"
        var saved = false
        editVM.saveChanges { saved = true }
        XCTAssertTrue(saved)
        
        // 4. Notify selection VM about the saved product
        viewModel.handleNewProductSaved(editVM.product)
        
        // 5. Verify list updated and callback received
        XCTAssertEqual(viewModel.allProducts.count, 1)
        XCTAssertEqual(selectedProduct?.name, "Selection Created")
    }

    func testAddNewProductFromSelectionFlowMultipleSelection() {
        // Ensure units exist
        _ = createUnit(name: "pcs")
        context.refreshAllObjects()

        // Create view model in multiple selection mode
        viewModel = ProductSelectionViewModel(
            productSelectionService: productSelectionService,
            currentProduct: nil,
            selectionMode: .multiple,
            preselectedProducts: [],
            onProductSelected: { _ in },
            onProductsSelected: { _ in }
        )

        // Start with empty products
        viewModel.loadProducts()
        XCTAssertTrue(viewModel.allProducts.isEmpty)

        // Create a product via EditProduct flow
        let editService = EditProductService(context: context)
        let editVM = EditProductViewModel(product: nil, editProductService: editService)
        editVM.loadProduct()
        editVM.product?.name = "Multi Mode Product"
        var saved = false
        editVM.saveChanges { saved = true }
        XCTAssertTrue(saved)

        // Notify selection VM
        viewModel.handleNewProductSaved(editVM.product)

        // Verify list updated and product pre-selected
        XCTAssertEqual(viewModel.allProducts.count, 1)
        XCTAssertTrue(viewModel.selectedProducts.contains(where: { $0.name == "Multi Mode Product" }))
    }
    
    func testProductSelectionWithCurrentProduct() {
        let (products, _) = createTestData()
        let currentProduct = products[2] // Banana
        
        // Create view model with current product
        viewModel = ProductSelectionViewModel(
            productSelectionService: productSelectionService,
            currentProduct: currentProduct,
            onProductSelected: productSelectedCallback
        )
        
        viewModel.loadProducts()
        
        // Wait for reactive bindings to complete
        let loadExp = expectation(description: "Products loaded with current product")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Verify current product exists in loaded products
            XCTAssertTrue(self.viewModel.allProducts.contains(currentProduct))
            loadExp.fulfill()
        }
        wait(for: [loadExp], timeout: 1.0)
        
        // Select different product
        let newProduct = products[0] // Apple
        viewModel.onProductSelected(newProduct)
        
        // Verify new selection
        XCTAssertEqual(selectedProduct, newProduct)
        XCTAssertNotEqual(selectedProduct, currentProduct)
    }
    
    // MARK: - Data Consistency Tests
    
    func testProductPersistence() {
        // Create products
        let (_, _) = createTestData()
        
        // Load products in first view model
        viewModel.loadProducts()
        let initialCount = viewModel.allProducts.count
        
        // Create new view model instance
        let newViewModel = ProductSelectionViewModel(
            productSelectionService: ProductSelectionService(context: context),
            currentProduct: nil,
            onProductSelected: { _ in }
        )
        
        // Load products in new view model
        newViewModel.loadProducts()
        
        // Verify same products are loaded
        XCTAssertEqual(newViewModel.allProducts.count, initialCount)
        XCTAssertEqual(newViewModel.allProducts.count, 5)
        
        // Verify product names match
        let originalNames = viewModel.allProducts.map { $0.name ?? "" }.sorted()
        let newNames = newViewModel.allProducts.map { $0.name ?? "" }.sorted()
        XCTAssertEqual(originalNames, newNames)
    }
    
    // MARK: - Edge Cases
    
    func testProductsWithSpecialCharacters() {
        // Create products with special characters
        let unit = createUnit(name: "pcs")
        _ = createProduct(name: "Product!@#$%", unit: unit)
        _ = createProduct(name: "Ñandú", unit: unit)
        _ = createProduct(name: "Café", unit: unit)
        
        context.refreshAllObjects()
        
        // Load products
        viewModel.loadProducts()
        
        // Wait for reactive bindings to complete
        let loadExp = expectation(description: "Special character products loaded")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.viewModel.allProducts.count, 3)
            loadExp.fulfill()
        }
        wait(for: [loadExp], timeout: 1.0)
        
        // Test search with special characters
        let exp = expectation(description: "Special characters search")
        viewModel.searchText = "Café"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.viewModel.filteredProducts.count, 1)
            XCTAssertEqual(self.viewModel.filteredProducts.first?.name, "Café")
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 2)
    }
    
    func testLargeDataSet() {
        // Create large number of products
        let unit = createUnit(name: "pcs")
        for i in 1...100 {
            _ = createProduct(name: "Product \(i)", unit: unit)
        }
        
        context.refreshAllObjects()
        
        // Load products
        viewModel.loadProducts()
        
        // Wait for reactive bindings to complete
        let loadExpectation = expectation(description: "Large dataset loaded")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.viewModel.allProducts.count, 100)
            XCTAssertEqual(self.viewModel.filteredProducts.count, 100)
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 1.0)
        
        // Test search performance with large dataset
        let exp = expectation(description: "Large dataset search")
        viewModel.searchText = "Product 1"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Should find "Product 1", "Product 10", "Product 11", ..., "Product 19", "Product 100"
            let filteredCount = self.viewModel.filteredProducts.count
            XCTAssertTrue(filteredCount > 0)
            XCTAssertTrue(filteredCount <= 100)
            
            // Verify all results contain "Product 1"
            for product in self.viewModel.filteredProducts {
                XCTAssertTrue(product.name?.contains("Product 1") ?? false)
            }
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 2)
    }
} 
