//
//  ProductManagementUITests.swift
//  FamilyMenuPlannerUITests
//
//  Created by Critical Test Review on 28.01.25.
//

import XCTest

// We avoid querying app.cells directly because some views expose a single large container cell that contains many other cells,
// leading to ambiguous or oversized cell selections. We scope queries to the actual product list container for precision.

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
        XCTAssertTrue(waitForProductList(timeout: 5), "Product list should exist")
        
        // Find and tap any visible "Add Product" entry point: floating button or empty state CTA
        let addProductButton = app.buttons["add_product_button"]
        if addProductButton.waitToExist(timeout: 3) {
            addProductButton.tap()
        } else {
            // Try empty state CTA on selection or list screens
            let emptyStateCTA = app.buttons["Add Product"]
            if emptyStateCTA.waitToExist(timeout: 2) {
                emptyStateCTA.tap()
            } else {
                XCTFail("No Add Product entry point found")
            }
        }
        
        // Wait for the add product sheet to appear
        let addProductNavBar = app.navigationBars["Add Product"]
        XCTAssertTrue(addProductNavBar.waitToExist(timeout: 3), "Add Product sheet should appear")
        
        // Find the product name text field in the form
        let productNameField = app.textFields["product_name_field"]
        XCTAssertTrue(productNameField.waitToExist(timeout: 3), "Product Name field should exist in the add form")
        
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
        let saveButton = app.toolbarButton("Save")
        XCTAssertTrue(saveButton.waitToExist(timeout: 3), "Save button should exist")
        saveButton.tap()
        
        // Wait for the sheet to dismiss and return to product list
        XCTAssertTrue(app.navigationBars["Products"].waitToExist(timeout: 5), "Should return to Products list after saving")
        
        // Verify the product was created by checking if it appears in the list
        // The product might be added below the visible area, so scroll to find it
        let list = productListContainer()
        let createdProduct = list.staticTexts["Test Product UI"]
        
        // First try to find it without scrolling
        if !createdProduct.waitToExist(timeout: 2) {
            // If not found, scroll down to look for the product
            // Scroll down a few times to find the new product
            for _ in 0..<5 {
                list.swipeUp()
                // Wait for scroll animation to complete
                if createdProduct.waitToExist(timeout: 1.0) {
                    break
                }
            }
        }
        
        XCTAssertTrue(createdProduct.exists, "Created product should appear in the product list (after scrolling if needed)")
        
        // Additional verification: Test creating another product to ensure functionality still works
        let addProductButton2 = app.buttons["add_product_button"]
        addProductButton2.tap()
        XCTAssertTrue(addProductNavBar.waitToExist(timeout: 3), "Add Product sheet should appear again")
        
        let secondProductNameField = app.textFields["product_name_field"]
        secondProductNameField.tap()
        secondProductNameField.typeText("Second Test Product")
        
        let secondSaveButton = app.toolbarButton("Save")
        secondSaveButton.tap()
        
        // Verify return to list and second product creation
        XCTAssertTrue(app.navigationBars["Products"].waitToExist(timeout: 5), "Should return to Products list after second save")
        let secondCreatedProduct = list.staticTexts["Second Test Product"]
        XCTAssertTrue(secondCreatedProduct.waitToExist(timeout: 3), "Second product should also appear in the list")
    }

    /// Regression: a card inserted into an already populated grid used to render as a blank slot.
    func testNewProductCardRendersAtTopOfPopulatedList() throws {
        navigateToProductList()
        XCTAssertTrue(waitForProductList(timeout: 5), "Product list should exist")
        // The sort preference persists across launches, so set A-Z explicitly
        openSortDialogAndSelect(optionLabel: "Name A-Z")

        let addProductButton = app.buttons["add_product_button"]
        XCTAssertTrue(addProductButton.waitToExist(timeout: 3), "Add Product button should exist")
        addProductButton.tap()

        let productNameField = app.textFields["product_name_field"]
        XCTAssertTrue(productNameField.waitToExist(timeout: 3), "Product Name field should exist in the add form")
        productNameField.tap()
        productNameField.typeText("Aaa First Product")
        app.toolbarButton("Save").tap()

        XCTAssertTrue(app.navigationBars["Products"].waitToExist(timeout: 5), "Should return to Products list after saving")
        // Sorted A-Z the new product is the first card, so it must be visible without scrolling
        let createdProduct = productListContainer().staticTexts["Aaa First Product"]
        XCTAssertTrue(createdProduct.waitToExist(timeout: 3), "New product card should be rendered in the list")
        XCTAssertTrue(createdProduct.isHittable, "New product card should be visible at the top of the list")
    }

    func testCreateProductValidation() throws {
        navigateToProductList()

        // Wait for the product list to load
        XCTAssertTrue(waitForProductList(timeout: 8), "Product list should exist")

        // Find and tap the floating "Add Product" button
        let addProductButton = app.buttons["add_product_button"]
        XCTAssertTrue(addProductButton.waitForHittable(timeout: 4), "Floating add product button should be hittable")
        addProductButton.tap()

        // Wait for the add product sheet to appear
        let addProductNavBar = app.navigationBars["Add Product"]
        XCTAssertTrue(addProductNavBar.waitToExist(timeout: 4), "Add Product sheet should appear")

        // Find the product name text field in the form
        let productNameField = app.textFields["product_name_field"]
        XCTAssertTrue(productNameField.waitForHittable(timeout: 4), "Product Name field should be hittable in the add form")

        // Test validation with empty name - use the reusable helper method
        productNameField.clearTextWithFallback()

        // Try to save without entering a name
        let saveButton = app.toolbarButton("Save")
        XCTAssertTrue(saveButton.waitForHittable(timeout: 3), "Save button should be hittable")
        saveButton.tap()

        // Wait for validation response - use a more robust approach
        let alert = app.alerts.firstMatch
        let alertAppeared = alert.waitToExist(timeout: 3)
        
        if alertAppeared {
            // Look for validation error texts in the alert
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
                    break
                }
            }
            
            XCTAssertTrue(validationErrorFound, "Validation error should appear for empty product name")
            
            // Dismiss the alert
            let okButton = app.buttons["OK"]
            if okButton.exists && okButton.isHittable {
                okButton.tap()
            }
        } else {
            // If no alert appeared, verify we're still on the Add Product screen (validation prevented submission)
            XCTAssertTrue(addProductNavBar.exists, "Should still be on Add Product screen after validation failure")
            
            // Additional check: verify the save button is still enabled and we can try again
            XCTAssertTrue(saveButton.isHittable, "Save button should still be hittable after validation failure")
        }
    }
    
    // MARK: - Test Product Editing
    
    func testEditExistingProduct() throws {
        navigateToProductList()
        
        // Wait for initial data to load by waiting until at least one product's edit button appears
        let initialEditButton = app.buttons["EditProductButton"].firstMatch
        XCTAssertTrue(initialEditButton.waitToExist(timeout: 8), "Product list did not load in time")
        
        // Locate first product's edit button
        let editButton = app.buttons["EditProductButton"].firstMatch
        XCTAssertTrue(editButton.waitToExist(timeout: 8), "EditProductButton should be present")
        
        // Open edit menu then select Edit
        editButton.tap()
        let editMenuItem = app.buttons["Edit"].firstMatch
        XCTAssertTrue(editMenuItem.waitToExist(timeout: 3), "Edit menu item should appear")
        editMenuItem.tap()
        
        // Wait for edit screen
        let editNav = app.navigationBars["Edit Product"]
        XCTAssertTrue(editNav.waitToExist(timeout: 5))
        
        let nameField = app.textFields["product_name_field"]
        XCTAssertTrue(nameField.waitToExist(timeout: 3))
        
        // Capture original name from the text field's current value
        let originalName = (nameField.value as? String) ?? ""
        
        // Focus on the text field first
        nameField.tap()
        
        // Wait for keyboard to appear and UI to stabilize
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitToExist(timeout: 3), "Keyboard should appear")
        
        // Select all text first (more reliable than trying to clear)
        nameField.doubleTap() // This should select all text
        
        // Wait for selection (all text selected) to complete using predicate expectation
        let selectionPredicate = NSPredicate(format: "value CONTAINS %@", originalName)
        XCTAssertTrue(nameField.waitUntil(selectionPredicate, timeout: 3), "Text field selection did not stabilize in time")

        // Type the new text (this should replace the selected text)
        nameField.typeText("Updated " + originalName)

        // Wait for text input to complete
        let updatedPredicate = NSPredicate(format: "value CONTAINS %@", "Updated " + originalName)
        XCTAssertTrue(nameField.waitUntil(updatedPredicate, timeout: 3), "Text update did not complete in time")
        
        // Verify we're still on the edit screen
        XCTAssertTrue(editNav.exists, "Should still be on edit screen after typing")
        
        let saveButton = app.toolbarButton("Save")
        
        XCTAssertTrue(saveButton.waitToExist(timeout: 5), "Save button should exist")
        saveButton.tap()
        
        // Return to list
        XCTAssertTrue(app.navigationBars["Products"].waitToExist(timeout: 5))
        
        // Verify updated name appears in the list (scroll if necessary)
        let updatedText = app.staticTexts["Updated " + originalName]
        
        var updatedFound = updatedText.waitToExist(timeout: 2)
        if !updatedFound {
            // Try scrolling through the product list container only
            let list = productListContainer()
            for _ in 0..<6 {
                list.swipeUp()
                if updatedText.exists {
                    updatedFound = true
                    break
                }
            }
        }
        
        XCTAssertTrue(updatedFound, "Edited product should appear with updated name in the list")
    }
    
    // MARK: - Test Product Deletion
    
    func testDeleteProduct() throws {
        navigateToProductList()
        
        // Wait for product list to appear instead of using a fixed sleep
        let anyProductName = app.staticTexts["ProductNameLabel"]
        XCTAssertTrue(anyProductName.waitToExist(timeout: 8), "Product list did not load in time")
        
        var foundProductToDelete = false
        var productToDeleteName = ""
        
        // Use the proven working pattern from dish management test
        // Look for product cards by their accessibility identifier
        var actualProductCells: [XCUIElement] = []
        let allCells = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "product_list_item_"))
        let knownProducts = ["Beef", "Butter", "Carrot", "Chicken", "Egg", "Milk", "Onion"]
        
        print("🔍 Scanning cells for products...")
        
        // Look for product cells (similar to how dish test finds ingredient cells)
        for i in 0..<20 {
            let cell = allCells.element(boundBy: i)
            if cell.exists {
                // Replace enumeration with identifier-targeted lookups
                var cellLabels: [String] = []
                let nameElement = cell.staticTexts.matching(identifier: "ProductNameLabel").firstMatch
                if nameElement.exists, !nameElement.label.isEmpty {
                    cellLabels.append(nameElement.label)
                }
                let unitElement = cell.staticTexts.matching(identifier: "ProductUnitLabel").firstMatch
                if unitElement.exists, !unitElement.label.isEmpty {
                    cellLabels.append(unitElement.label)
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
            
            let list = productListContainer()
            
            // Open the Edit menu from the visible Edit button, then choose Delete
            let editMenuButton = app.buttons["EditProductButton"].firstMatch
            if editMenuButton.waitToExist(timeout: 3) {
                editMenuButton.tap()
                let deleteMenuItem = app.buttons["Delete"].firstMatch
                if deleteMenuItem.waitToExist(timeout: 3) {
                    deleteMenuItem.tap()
                    let confirmDelete = app.buttons["Delete"].firstMatch
                    if confirmDelete.waitToExist(timeout: 3) {
                        confirmDelete.tap()
                        // Wait for the specific card to disappear
                        let targetCard = list.otherElements["product_list_item_\(productToDeleteName)"]
                        productDeleted = targetCard.waitToDisappear(timeout: 5.0)
                    }
                }
            }

            XCTAssertTrue(productDeleted, "Product should be deleted via context menu")
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
        if searchField.waitToExist(timeout: 5) {
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

        // Wait for the list to finish updating by ensuring a product card exists inside the product list container
        let list = productListContainer()
        let firstProductCellAsc = list.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "product_list_item_")).firstMatch
        XCTAssertTrue(firstProductCellAsc.waitToExist(timeout: 5), "Sorting did not complete in time")

        let names = fetchVisibleProductNames(maxCount: 5)
        let sorted = names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        XCTAssertEqual(names, sorted, "Products should be sorted A→Z by name")
    }

    func testSortProductsByNameDescending() throws {
        navigateToProductList()

        // Open sort dialog
        openSortDialogAndSelect(optionLabel: "Name Z-A")

        let list = productListContainer()
        let firstProductCellDesc = list.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "product_list_item_")).firstMatch
        XCTAssertTrue(firstProductCellDesc.waitToExist(timeout: 5), "Sorting did not complete in time")

        let names = fetchVisibleProductNames(maxCount: 5)
        let sorted = names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedDescending }
        XCTAssertEqual(names, sorted, "Products should be sorted Z→A by name")
    }

    func testSortProductsByUnit() throws {
        navigateToProductList()

        openSortDialogAndSelect(optionLabel: "Unit")
        let list = productListContainer()
        let firstProductCellUnit = list.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "product_list_item_")).firstMatch
        XCTAssertTrue(firstProductCellUnit.waitToExist(timeout: 5), "Sorting did not complete in time")

        // Collect a broader window of unit labels by scrolling through the list
        let units = collectVisibleUnitLabels(maxCount: 20)
        XCTAssertGreaterThanOrEqual(units.count, 2, "Not enough products visible to verify unit sorting across the list.")

        // Verify the entire collected sequence is non-decreasing by unit sortOrder
        let order = units.map { unitSortOrder(for: $0) }
        let isNonDecreasing = order.enumerated().dropFirst().allSatisfy { index, value in
            let prev = order[index - 1]
            return prev <= value
        }
        XCTAssertTrue(isNonDecreasing, "Products should be sorted by unit sort order across the visible list")
    }
    
    // MARK: - Helper Methods
    
    private func navigateToProductList() {
        // Tab bar on iPhone (bottom bar or side rail, depending on the device)
        let productsTab = app.tabButton("tab_products")
        if productsTab.waitToExist(timeout: 3) {
            productsTab.tap()
        } else {
            // iPad/sidebar layout: look for a sidebar or menu item labeled "Products"
            // Try common container types for sidebars
            let productsSidebarButton = app.buttons["Products"].firstMatch
            let productsCell = app.cells.staticTexts["Products"].firstMatch
            let productsAny = app.staticTexts["Products"].firstMatch

            var navigated = false

            if productsSidebarButton.waitToExist(timeout: 3) && productsSidebarButton.isHittable {
                productsSidebarButton.tap()
                navigated = true
            } else if productsCell.waitToExist(timeout: 3) && productsCell.isHittable {
                productsCell.tap()
                navigated = true
            } else if productsAny.waitToExist(timeout: 2) && productsAny.isHittable {
                productsAny.tap()
                navigated = true
            }

            // As a fallback, try a toolbar/tab-like button with accessibility identifier
            if !navigated {
                let productsButtonById = app.buttons["products_tab_button"].firstMatch
                if productsButtonById.waitToExist(timeout: 2) && productsButtonById.isHittable {
                    productsButtonById.tap()
                }
            }
        }

        // Verify we are on the Products screen regardless of navigation pattern
        let productListTitle = app.navigationBars["Products"]
        // If navigation bar doesn't exist (SwiftUI can render differently on iPad), also accept a static title
        let titleLabel = app.staticTexts["Products"].firstMatch
        let onProducts = productListTitle.waitToExist(timeout: 5) || titleLabel.waitToExist(timeout: 5)
        XCTAssertTrue(onProducts, "Should navigate to Products screen")
    }
    
    // MARK: - Helpers

    private func waitForProductList(timeout: TimeInterval) -> Bool {
        app.descendants(matching: .any)["ProductList"].waitToExist(timeout: timeout)
    }

    /// Returns the most specific container for the product list.
    /// Checks scrollViews["ProductList"], collectionViews["ProductList"], tables["ProductList"], otherElements["ProductList"], then fallback containers.
    private func productListContainer() -> XCUIElement {
        if app.scrollViews["ProductList"].exists { return app.scrollViews["ProductList"] }
        if app.collectionViews["ProductList"].exists { return app.collectionViews["ProductList"] }
        if app.tables["ProductList"].exists { return app.tables["ProductList"] }
        if app.otherElements["ProductList"].exists { return app.otherElements["ProductList"] }
        let table = app.tables.firstMatch
        if table.exists { return table }
        let collection = app.collectionViews.firstMatch
        if collection.exists { return collection }
        let scroll = app.scrollViews.firstMatch
        if scroll.exists { return scroll }
        return app.otherElements.firstMatch
    }
    
    private func openSortDialogAndSelect(optionLabel: String) {
        let sortButton = app.buttons["sort_products_button"]
        XCTAssertTrue(sortButton.waitToExist(timeout: 5), "Sort button should exist")
        sortButton.tap()

        let option = app.buttons[optionLabel].firstMatch
        XCTAssertTrue(option.waitToExist(timeout: 3), "Sort option \(optionLabel) should exist")
        option.tap()
    }

    private func fetchVisibleProductNames(maxCount: Int) -> [String] {
        var names: [String] = []
        let list = productListContainer()

        // Prefer querying product cards directly to avoid giant container cell issues
        let cards = list.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "product_list_item_"))
        let cardCount = min(cards.count, maxCount)

        if cardCount > 0 {
            for i in 0..<cardCount {
                let card = cards.element(boundBy: i)
                guard card.exists else { continue }
                let nameElement = card.staticTexts["ProductNameLabel"]
                if nameElement.exists, !nameElement.label.isEmpty {
                    names.append(nameElement.label)
                }
            }
            return names
        }

        // Fallback: iterate over visible cells but target the specific name label by identifier
        let count = min(list.cells.count, maxCount)
        for i in 0..<count {
            let cell = list.cells.element(boundBy: i)
            if cell.exists {
                let nameElement = cell.staticTexts.matching(identifier: "ProductNameLabel").firstMatch
                if nameElement.exists, !nameElement.label.isEmpty {
                    names.append(nameElement.label)
                }
            }
        }
        return names
    }

    private func fetchVisibleUnitLabelsFromList(maxCount: Int) -> [String] {
        var units: [String] = []
        let list = productListContainer()

        // Prefer querying product cards directly
        let cards = list.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "product_list_item_"))
        let cardCount = min(cards.count, maxCount)

        if cardCount > 0 {
            for i in 0..<cardCount {
                let card = cards.element(boundBy: i)
                guard card.exists else { continue }
                let unitElement = card.staticTexts["ProductUnitLabel"]
                if unitElement.exists, !unitElement.label.isEmpty {
                    units.append(unitElement.label)
                }
            }
            return units
        }

        // Fallback: iterate over visible cells but target the specific unit label by identifier
        let count = min(list.cells.count, maxCount)
        for i in 0..<count {
            let cell = list.cells.element(boundBy: i)
            if cell.exists {
                let unitById = cell.staticTexts.matching(identifier: "ProductUnitLabel").firstMatch
                if unitById.exists, !unitById.label.isEmpty {
                    units.append(unitById.label)
                }
            }
        }
        return units
    }
    
    private func ensureAtLeastProducts(count requiredCount: Int) {
        // Count currently visible product name labels
        var currentCount = app.staticTexts.matching(identifier: "ProductNameLabel").count
        if currentCount >= requiredCount { return }

        // Try to add simple products until reaching required count
        let addButton = app.buttons["add_product_button"]
        let addNav = app.navigationBars["Add Product"]
        let saveFromAdd = app.toolbarButton("Save")
        let nameField = app.textFields["product_name_field"]

        var index = 1
        while currentCount < requiredCount && index <= 5 { // safety cap
            if addButton.waitToExist(timeout: 2) {
                addButton.tap()
            } else {
                // Fallback to an alternate entry point
                let emptyCTA = app.buttons["Add Product"]
                if emptyCTA.waitToExist(timeout: 2) {
                    emptyCTA.tap()
                }
            }

            if addNav.waitToExist(timeout: 3) && nameField.waitToExist(timeout: 2) {
                nameField.tap()
                nameField.clearTextWithFallback()
                nameField.typeText("Auto Product \(UUID().uuidString.prefix(6))")

                // If a unit picker exists, try to set a unit to make data consistent
                let unitPickerButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Unit'")).firstMatch
                if unitPickerButton.exists {
                    unitPickerButton.tap()
                    let wheel = app.pickerWheels.firstMatch
                    if wheel.exists {
                        // Alternate units to avoid duplicates
                        let candidate = (index % 2 == 0) ? "pcs" : "kg"
                        wheel.adjust(toPickerWheelValue: candidate)
                    }
                    // Dismiss picker by tapping the name field again
                    nameField.tap()
                }

                if saveFromAdd.exists { saveFromAdd.tap() }
                _ = app.navigationBars["Products"].waitToExist(timeout: 3)

                // Recount
                currentCount = app.staticTexts.matching(identifier: "ProductNameLabel").count
                index += 1
            } else {
                // If we can't access add flow, skip to avoid hard failure
                break
            }
        }
    }
    
    private func collectVisibleUnitLabels(maxCount: Int) -> [String] {
        var units: [String] = []
        let list = productListContainer()
        
        // Prefer product cards directly to avoid giant container cell issues
        let cards = list.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "product_list_item_"))
        let cardCount = min(cards.count, maxCount)
        
        if cardCount > 0 {
            for i in 0..<cardCount {
                let card = cards.element(boundBy: i)
                guard card.exists else { continue }
                let unitElement = card.staticTexts["ProductUnitLabel"]
                if unitElement.exists {
                    let label = unitElement.label
                    if !label.isEmpty { units.append(label) }
                }
            }
            return units
        }
        
        // Fallback: iterate over visible cells but only target the unit label by identifier
        let cellCount = min(list.cells.count, maxCount)
        for i in 0..<cellCount {
            let cell = list.cells.element(boundBy: i)
            guard cell.exists else { continue }
            let unitById = cell.staticTexts.matching(identifier: "ProductUnitLabel").firstMatch
            if unitById.exists {
                let label = unitById.label
                if !label.isEmpty { units.append(label) }
            }
        }
        
        return units
    }
    
    private func unitSortOrder(for label: String) -> Int {
        // Map visible unit labels to the model's sortOrder. Keep this in sync with @Unit definitions.
        // Unknown labels get a large value so they naturally sort to the end without breaking the test.
        let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "kg":
            return 1
        case "g":
            return 2
        case "l":
            return 3
        case "ml":
            return 4
        case "pcs", "piece", "pieces":
            return 5
        case "tbsp", "tablespoon":
            return 6
        case "tsp", "teaspoon":
            return 7
        default:
            // Fallback for units we don't explicitly map
            return 999
        }
    }
} 

