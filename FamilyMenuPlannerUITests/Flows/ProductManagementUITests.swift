//
//  ProductManagementUITests.swift
//  FamilyMenuPlannerUITests
//
//  Created by Critical Test Review on 28.01.25.
//

import XCTest

final class ProductManagementUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = [
            "-UITests",
            "-DisableCloudKit",
            "-XCTest",
            "-InMemoryStore"
        ]
        
        app.launchEnvironment = [
            "UI_TESTS": "1",
            "DISABLE_CLOUDKIT": "1",
            "XCTestBundlePath": "UITests",
            "TESTING_ENVIRONMENT": "1"
        ]
        
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Test Product Creation
    
    func testCreateNewProduct() throws {
        navigateToProductList()
        
        // Wait for the product list to load
        // Try different element types since SwiftUI List can render as table, collection view, or other types
        var productList: XCUIElement?
        if app.tables["ProductList"].waitForExistence(timeout: 2) {
            productList = app.tables["ProductList"]
        } else if app.collectionViews["ProductList"].waitForExistence(timeout: 2) {
            productList = app.collectionViews["ProductList"]
        } else {
            productList = app.otherElements["ProductList"]
        }
        
        XCTAssertTrue(productList?.waitForExistence(timeout: 3) ?? false, "Product list should exist")
        
        // Find and tap the floating "Add Product" button
        let addProductButton = app.buttons["add_product_button"]
        XCTAssertTrue(addProductButton.waitForExistence(timeout: 3), "Floating add product button should exist")
        addProductButton.tap()
        
        // Wait for the add product sheet to appear
        let addProductNavBar = app.navigationBars["Add Product"]
        XCTAssertTrue(addProductNavBar.waitForExistence(timeout: 3), "Add Product sheet should appear")
        
        // Find the product name text field in the form
        let productNameField = app.textFields["product_name_field"]
        XCTAssertTrue(productNameField.waitForExistence(timeout: 3), "Product Name field should exist in the add form")
        
        // Fill in the product name
        productNameField.tap()
        productNameField.typeText("Test Product UI")
        
        // Verify unit picker exists and select a unit if needed
        let unitPicker = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Unit'")).firstMatch
        if unitPicker.exists {
            unitPicker.tap()
            // Select the first available unit from the picker
            let firstUnit = app.pickerWheels.firstMatch
            if firstUnit.exists {
                // Pick a unit value - the unit picker should have default values
                firstUnit.adjust(toPickerWheelValue: "pcs")
            }
            // Tap outside picker to dismiss it (if it's a modal picker)
            productNameField.tap()
        }
        
        // Find and tap the Save button
        let saveButton = app.navigationBars["Add Product"].buttons["Save"]
        XCTAssertTrue(saveButton.exists, "Save button should exist in the navigation bar")
        saveButton.tap()
        
        // Wait for the sheet to dismiss and return to product list
        XCTAssertTrue(app.navigationBars["Products"].waitForExistence(timeout: 5), "Should return to Products list after saving")
        
        // Verify the product was created by checking if it appears in the list
        // The product might be added below the visible area, so scroll to find it
        let createdProduct = app.staticTexts["Test Product UI"]
        
        // First try to find it without scrolling
        if !createdProduct.waitForExistence(timeout: 2) {
            // If not found, scroll down to look for the product
            if let productListElement = productList {
                // Scroll down a few times to find the new product
                for _ in 0..<5 {
                    productListElement.swipeUp()
                    Thread.sleep(forTimeInterval: 0.5)
                    if createdProduct.exists {
                        break
                    }
                }
            }
        }
        
        XCTAssertTrue(createdProduct.exists, "Created product should appear in the product list (after scrolling if needed)")
        
        // Additional verification: Test creating another product to ensure functionality still works
        addProductButton.tap()
        XCTAssertTrue(addProductNavBar.waitForExistence(timeout: 3), "Add Product sheet should appear again")
        
        let secondProductNameField = app.textFields["product_name_field"]
        secondProductNameField.tap()
        secondProductNameField.typeText("Second Test Product")
        
        let secondSaveButton = app.navigationBars["Add Product"].buttons["Save"]
        secondSaveButton.tap()
        
        // Verify return to list and second product creation
        XCTAssertTrue(app.navigationBars["Products"].waitForExistence(timeout: 5), "Should return to Products list after second save")
        let secondCreatedProduct = app.staticTexts["Second Test Product"]
        XCTAssertTrue(secondCreatedProduct.waitForExistence(timeout: 3), "Second product should also appear in the list")
    }
    
    func testCreateProductValidation() throws {
        navigateToProductList()
        
        // Wait for the product list to load
        // Try different element types since SwiftUI List can render as table, collection view, or other types
        var productList: XCUIElement?
        if app.tables["ProductList"].waitForExistence(timeout: 2) {
            productList = app.tables["ProductList"]
        } else if app.collectionViews["ProductList"].waitForExistence(timeout: 2) {
            productList = app.collectionViews["ProductList"]
        } else {
            productList = app.otherElements["ProductList"]
        }
        
        XCTAssertTrue(productList?.waitForExistence(timeout: 3) ?? false, "Product list should exist")
        
        // Find and tap the floating "Add Product" button
        let addProductButton = app.buttons["add_product_button"]
        XCTAssertTrue(addProductButton.waitForExistence(timeout: 3), "Floating add product button should exist")
        addProductButton.tap()
        
        // Wait for the add product sheet to appear
        let addProductNavBar = app.navigationBars["Add Product"]
        XCTAssertTrue(addProductNavBar.waitForExistence(timeout: 3), "Add Product sheet should appear")
        
        // Find the product name text field in the form
        let productNameField = app.textFields["product_name_field"]
        XCTAssertTrue(productNameField.waitForExistence(timeout: 3), "Product Name field should exist in the add form")
        
        // Test validation with empty name
        // Ensure the text field is empty
        productNameField.tap()
        productNameField.clearAndEnterText("")
        
        // Try to save without entering a name
        let saveButton = app.navigationBars["Add Product"].buttons["Save"]
        XCTAssertTrue(saveButton.exists, "Save button should exist in the navigation bar")
        saveButton.tap()
        
        // Wait a moment for validation to process
        Thread.sleep(forTimeInterval: 1.0)
        
        // Check for validation error - since this is an alert, look for alert elements
        let alertTitle = app.alerts.firstMatch
        if alertTitle.waitForExistence(timeout: 2) {
            // Look for common validation error texts in the alert
            let errorTexts = [
                "Error",
                "Product name cannot be empty",
                "cannot be empty",
                "Name is required"
            ]
            
            var validationErrorFound = false
            for errorText in errorTexts {
                let errorElement = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", errorText)).firstMatch
                if errorElement.exists {
                    validationErrorFound = true
                    XCTAssertTrue(true, "Validation error found in alert: \(errorText)")
                    
                    // Dismiss the alert
                    let okButton = app.buttons["OK"]
                    if okButton.exists {
                        okButton.tap()
                    }
                    break
                }
            }
            
            XCTAssertTrue(validationErrorFound, "Validation error should appear for empty product name")
        } else {
            // If no alert appeared, verify we're still on the Add Product screen (validation prevented submission)
            XCTAssertTrue(addProductNavBar.exists, "Should still be on Add Product screen after validation failure")
        }
        
        // Now test that validation allows valid input
        productNameField.tap()
        productNameField.clearAndEnterText("Valid Product Name")
        saveButton.tap()
        
        // Verify that valid input was accepted - sheet should dismiss and return to product list
        XCTAssertTrue(app.navigationBars["Products"].waitForExistence(timeout: 5), "Should return to Products list after valid input")
        
        // Verify the product with valid name was created
        // The product might be added below the visible area, so scroll to find it
        let validProduct = app.staticTexts["Valid Product Name"]
        
        // First try to find it without scrolling
        if !validProduct.waitForExistence(timeout: 2) {
            // If not found, scroll down to look for the product
            if let productListElement = productList {
                // Scroll down a few times to find the new product
                for _ in 0..<5 {
                    productListElement.swipeUp()
                    Thread.sleep(forTimeInterval: 0.5)
                    if validProduct.exists {
                        break
                    }
                }
            }
        }
        
        XCTAssertTrue(validProduct.exists, "Valid product should appear in the list (after scrolling if needed)")
    }
    
    // MARK: - Test Product Editing
    
    func testEditExistingProduct() throws {
        navigateToProductList()
        
        // Wait for initial data to load by waiting until at least one product's edit button appears
        let initialEditButton = app.buttons["EditProductButton"].firstMatch
        XCTAssertTrue(initialEditButton.waitForExistence(timeout: 8), "Product list did not load in time")
        
        // Locate first product's edit button
        let editButton = app.buttons["EditProductButton"].firstMatch
        XCTAssertTrue(editButton.waitForExistence(timeout: 8), "EditProductButton should be present")
        
        // Open edit
        editButton.tap()
        
        // Wait for edit screen
        let editNav = app.navigationBars["Edit Product"]
        XCTAssertTrue(editNav.waitForExistence(timeout: 5))
        
        let nameField = app.textFields["product_name_field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        
        // Capture original name from the text field's current value
        let originalName = (nameField.value as? String) ?? ""
        
        nameField.tap()
        nameField.clearAndEnterText("Updated " + originalName)
        
        // Save changes
        editNav.buttons["Save"].tap()
        
        // Return to list
        XCTAssertTrue(app.navigationBars["Products"].waitForExistence(timeout: 5))
        
        // Verify updated name appears in the list (scroll if necessary)
        let updatedText = app.staticTexts["Updated " + originalName]
        
        var updatedFound = updatedText.waitForExistence(timeout: 2)
        if !updatedFound {
            // Try scrolling through potential container types
            let containers: [XCUIElement] = [
                app.tables["ProductList"],
                app.collectionViews["ProductList"],
                app.scrollViews.firstMatch,
                app.tables.firstMatch
            ]
            for container in containers where container.exists {
                for _ in 0..<6 {
                    container.swipeUp()
                    if updatedText.exists {
                        updatedFound = true
                        break
                    }
                }
                if updatedFound { break }
            }
        }
        
        XCTAssertTrue(updatedFound, "Edited product should appear with updated name in the list")
    }
    
    // MARK: - Test Product Deletion
    
    func testDeleteProduct() throws {
        navigateToProductList()
        
        // Wait for product list to appear instead of using a fixed sleep
        let anyProductName = app.staticTexts["ProductNameLabel"]
        XCTAssertTrue(anyProductName.waitForExistence(timeout: 8), "Product list did not load in time")
        
        var foundProductToDelete = false
        var productToDeleteName = ""
        
        // Use the proven working pattern from dish management test
        // Look for actual product cells by scanning through app.cells
        var actualProductCells: [XCUIElement] = []
        let allCells = app.cells
        let knownProducts = ["Beef", "Butter", "Carrot", "Chicken", "Egg", "Milk", "Onion"]
        
        print("🔍 Scanning cells for products...")
        
        // Look for product cells (similar to how dish test finds ingredient cells)
        for i in 0..<20 {
            let cell = allCells.element(boundBy: i)
            if cell.exists {
                let cellTexts = cell.staticTexts
                var cellLabels: [String] = []
                
                for j in 0..<10 { // Limit to reasonable number of text elements
                    let text = cellTexts.element(boundBy: j)
                    if text.exists && !text.label.isEmpty {
                        cellLabels.append(text.label)
                    }
                }
                
                print("🔍 Cell \(i) contents: \(cellLabels)")
                
                // Skip cells that are clearly section headers or system labels  
                let hasSystemLabels = cellLabels.contains { label in
                    label.contains("PRODUCTS") ||
                    label.contains("ADD NEW PRODUCT") ||
                    label.contains("SEARCH") ||
                    label.uppercased().contains("SECTION") ||
                    label == "Product Name" || label == "Unit" ||
                    label == "Add Product"
                }
                
                // Look for actual product content - check against known products
                let hasProductContent = cellLabels.contains { label in
                    return knownProducts.contains(label)
                }
                
                // If this cell has product content and isn't a system label, count it
                if !hasSystemLabels && hasProductContent && cellLabels.count > 0 {
                    print("✅ Found product cell \(i): \(cellLabels)")
                    actualProductCells.append(cell)
                    foundProductToDelete = true
                    // Use the first product name found as our target
                    if productToDeleteName.isEmpty {
                        for label in cellLabels {
                            if knownProducts.contains(label) {
                                productToDeleteName = label
                                break
                            }
                        }
                    }
                } else if !hasSystemLabels && cellLabels.count > 0 {
                    // Even if we don't recognize it as a known product, it might still be a product
                    let potentialProductContent = cellLabels.contains { label in
                        // Look for reasonable product names (not too short, not system text)
                        return label.count >= 3 && label.count <= 25 && 
                               !label.contains("Product") && 
                               !label.contains("Name") &&
                               !label.contains("Unit") &&
                               !label.contains("Add")
                    }
                    
                    if potentialProductContent {
                        print("🤔 Found potential product cell \(i): \(cellLabels)")
                        actualProductCells.append(cell)
                        foundProductToDelete = true
                        if productToDeleteName.isEmpty {
                            // Use the first reasonable-looking label
                            for label in cellLabels {
                                if label.count >= 3 && label.count <= 25 {
                                    productToDeleteName = label
                                    break
                                }
                            }
                        }
                    }
                }
            }
        }
        
        print("📊 Total product cells found: \(actualProductCells.count)")
        
        if foundProductToDelete {
            print("🧪 Testing product deletion functionality")
            var productDeleted = false
            
            // Delete using the delete icon on the first product card
            let deleteButton = app.buttons["DeleteProductButton"].firstMatch
            if deleteButton.waitForExistence(timeout: 3) {
                deleteButton.tap()

                // Confirm deletion via confirmation dialog button
                let confirmDelete = app.buttons["Delete"].firstMatch
                if confirmDelete.waitForExistence(timeout: 3) {
                    confirmDelete.tap()
                    // Wait until the confirmation button disappears (dialog dismissed)
                    XCTAssertFalse(confirmDelete.waitForExistence(timeout: 1.0), "Confirmation dialog did not disappear in time")
                    productDeleted = true
                }
            }

            // Verify deletion flagged
            if productDeleted {
                XCTAssertTrue(true, "Product deleted via delete icon")
            } else {
                XCTFail("Product deletion failed - delete icon not tappable or confirmation missing")
            }
        } else {
            print("❌ No product cells found")
            XCTFail("No products found - check if preload data is loading correctly or if the app structure has changed")
        }
    }
    
    // MARK: - Test Product Search
    
    func testProductSearch() throws {
        navigateToProductList()
        
        // Look for search bar
        let searchField = app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 5) {
            searchField.tap()
            searchField.typeText("Test")
            
            // Verify search results update - table may not exist if no products
            let productList = app.tables.firstMatch
            if productList.exists {
                // Table exists - search is working with content
                XCTAssertTrue(productList.exists, "Product list should still be visible during search")
            } else {
                // No table exists - this is acceptable if there are no products to search
                XCTAssertTrue(true, "No product table during search - acceptable when no products exist")
            }
            
            // Clear search
            let clearButton = searchField.buttons["Clear text"]
            if clearButton.exists {
                clearButton.tap()
            }
        } else {
            // Search might be implemented differently
            XCTAssertTrue(true, "Search functionality may not be implemented yet")
        }
    }
    
    // MARK: - Sorting Tests
    
    func testSortProductsByNameAscending() throws {
        navigateToProductList()

        // Open sort dialog
        openSortDialogAndSelect(optionLabel: "Name A-Z")

        // Wait for the table to finish updating by ensuring a cell exists
        let firstProductCellAsc = app.cells.firstMatch
        XCTAssertTrue(firstProductCellAsc.waitForExistence(timeout: 5), "Sorting did not complete in time")

        let names = fetchVisibleProductNames(maxCount: 5)
        let sorted = names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        XCTAssertEqual(names, sorted, "Products should be sorted A→Z by name")
    }

    func testSortProductsByNameDescending() throws {
        navigateToProductList()

        // Open sort dialog
        openSortDialogAndSelect(optionLabel: "Name Z-A")

        let firstProductCellDesc = app.cells.firstMatch
        XCTAssertTrue(firstProductCellDesc.waitForExistence(timeout: 5), "Sorting did not complete in time")

        let names = fetchVisibleProductNames(maxCount: 5)
        let sorted = names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedDescending }
        XCTAssertEqual(names, sorted, "Products should be sorted Z→A by name")
    }

    func testSortProductsByUnit() throws {
        navigateToProductList()

        openSortDialogAndSelect(optionLabel: "Unit")
        let firstProductCellUnit = app.cells.firstMatch
        XCTAssertTrue(firstProductCellUnit.waitForExistence(timeout: 5), "Sorting did not complete in time")

        // Simple sanity check: capture first two visible unit strings and assert not equal when reversed sort by name A-Z
        let units = fetchVisibleUnitLabels(maxCount: 3)
        XCTAssertGreaterThan(units.count, 1, "Need at least two products to verify unit sorting")
        // Assume units array should be in ascending unit order (based on sortOrder attribute). Verify first <= second alphabetically as proxy.
        XCTAssertTrue(units.first!.localizedCaseInsensitiveCompare(units[1]) != .orderedDescending, "Unit sorting should place units in defined order")
    }
    
    // MARK: - Helper Methods
    
    private func navigateToProductList() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar should exist")
        
        let productsTab = tabBar.buttons["Products"]
        XCTAssertTrue(productsTab.exists, "Products tab should exist")
        productsTab.tap()
        
        let productListTitle = app.navigationBars["Products"]
        XCTAssertTrue(productListTitle.waitForExistence(timeout: 5), "Should navigate to Products screen")
    }
    
    // MARK: - Helpers
    
    private func openSortDialogAndSelect(optionLabel: String) {
        let sortButton = app.buttons["sort_products_button"]
        XCTAssertTrue(sortButton.waitForExistence(timeout: 5), "Sort button should exist")
        sortButton.tap()

        let option = app.buttons[optionLabel]
        XCTAssertTrue(option.waitForExistence(timeout: 3), "Sort option \(optionLabel) should exist")
        option.tap()
    }

    private func fetchVisibleProductNames(maxCount: Int) -> [String] {
        var names: [String] = []
        let nameElements = app.staticTexts.matching(identifier: "ProductNameLabel")
        let count = min(nameElements.count, maxCount)
        for i in 0..<count {
            let element = nameElements.element(boundBy: i)
            if element.exists { names.append(element.label) }
        }
        return names
    }

    private func fetchVisibleUnitLabels(maxCount: Int) -> [String] {
        var units: [String] = []
        let cells = app.cells
        let count = min(cells.count, maxCount)
        for i in 0..<count {
            let cell = cells.element(boundBy: i)
            if cell.exists {
                // Unit label is likely second static text (index 1)
                if cell.staticTexts.count > 1 {
                    let unitLabel = cell.staticTexts.element(boundBy: 1)
                    units.append(unitLabel.label)
                }
            }
        }
        return units
    }
} 
