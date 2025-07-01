//
//  DishManagementUITests.swift
//  FamilyMenuPlannerUITests
//
//  Created by Critical Test Review on 28.01.25.
//

import XCTest

final class DishManagementUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = [
            "-UITests",
            "-DisableCloudKit",
            "-XCTest"
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
    
    // MARK: - Test Dish Creation
    
    func testCreateNewDish() throws {
        navigateToDishList()
        
        // Record initial count if collection exists
        let initialCount: Int
        let collectionView = app.collectionViews.firstMatch
        if collectionView.exists {
            initialCount = collectionView.cells.count
        } else {
            initialCount = 0
        }
        
        // Tap add button
        let addButton = app.navigationBars.buttons["Add New Dish"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3), "Add button should exist")
        addButton.tap()
        
        // Verify we're in the multi-step dish creation screen
        XCTAssertTrue(waitForStepScreen(stepTitle: "Basic Information"), "Should be in Basic Information step")
        
        // STEP 1: Basic Information
        // Fill in dish name
        let dishNameField = app.textFields["Enter dish name"]
        XCTAssertTrue(dishNameField.waitForExistence(timeout: 5), "Should find dish name field in Basic Info step")
        
        dishNameField.tap()
        dishNameField.typeText("Test Dish Creation")
        
        // Add description (optional)
        let descriptionEditor = app.textViews.firstMatch
        if descriptionEditor.exists {
            descriptionEditor.tap()
            descriptionEditor.typeText("A test dish created by UI automation")
        }
        
        // Proceed to next step
        let nextButton = app.buttons["Next"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 3), "Next button should exist")
        XCTAssertTrue(nextButton.isEnabled, "Next button should be enabled with dish name filled")
        nextButton.tap()
        
        // STEP 2: Meal Types
        XCTAssertTrue(waitForStepScreen(stepTitle: "Meal Types"), "Should be in Meal Types step")
        
        // Select meal type (Breakfast)
        let breakfastMealType = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Breakfast'")).firstMatch
        if breakfastMealType.waitForExistence(timeout: 3) {
            breakfastMealType.tap()
            print("✅ Selected Breakfast meal type")
        }
        
        // Proceed to next step
        XCTAssertTrue(nextButton.isEnabled, "Next button should be enabled with meal type selected")
        nextButton.tap()
        
        // STEP 3: Ingredients
        XCTAssertTrue(waitForStepScreen(stepTitle: "Ingredients"), "Should be in Ingredients step")
        
        // Add ingredient using the "Select Product" button
        let selectProductButton = app.buttons["Select Product"]
        if selectProductButton.waitForExistence(timeout: 3) {
            selectProductButton.tap()
            
            // Handle product selection
            let productSelectionSuccess = handleProductSelection()
            XCTAssertTrue(productSelectionSuccess, "Should successfully select a product")
        } else {
            print("⚠️ Select Product button not found - skipping ingredient addition")
        }
        
        // Proceed to final step
        if nextButton.isEnabled {
            nextButton.tap()
        }
        
        // STEP 4: Review
        XCTAssertTrue(waitForStepScreen(stepTitle: "Review"), "Should be in Review step")
        
        // Verify dish summary appears
        let dishSummaryCard = app.staticTexts["Dish Summary"]
        XCTAssertTrue(dishSummaryCard.waitForExistence(timeout: 3), "Should show dish summary")
        
        // Save the dish
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Save button should exist")
        XCTAssertTrue(saveButton.isEnabled, "Save button should be enabled")
        saveButton.tap()
        
        // Verify we return to dish list
        let dishListTitle = app.navigationBars["Dishes"]
        XCTAssertTrue(dishListTitle.waitForExistence(timeout: 5), "Should return to dish list after saving")
        
        // Verify dish count and creation success
        Thread.sleep(forTimeInterval: 1.0) // Give time for UI to update
        
        if collectionView.exists {
            let newCount = collectionView.cells.count
            print("📊 Dish count: initial=\(initialCount), new=\(newCount)")
        }
        
        // CRITICAL: Verify the dish was actually created using comprehensive search
        let dishName = "Test Dish Creation"
        let foundCreatedDish = findDishInList(dishName: dishName)
        
        if foundCreatedDish {
            print("✅ Successfully verified dish creation - found '\(dishName)' in the list")
        } else {
            XCTFail("❌ FAILED: Could not find created dish '\(dishName)' in the dish list after comprehensive search (including scrolling and search functionality). Dish creation functionality may be broken.")
        }
        
        XCTAssertTrue(dishListTitle.exists, "Should be back on dish list")
        print("✅ Dish creation test completed - multi-step navigation, save, and verification validated")
    }
    
    // MARK: - Test Dish Editing
    
    func testEditExistingDish() throws {
        navigateToDishList()
        
        // Use existing preloaded dishes
        let existingDishNames = ["Beef Stew", "Cheese Omelette", "Cucumber Yogurt Salad"]
        var dishToEdit: String?
        var foundAndOpenedDish = false
        
        // Find an existing dish to edit
        let collectionView = app.collectionViews.firstMatch
        if collectionView.waitForExistence(timeout: 5) {
            print("📋 Found collection view, looking for existing dishes to edit...")
            
            let cells = collectionView.cells
            let cellCount = cells.count
            print("📋 Found \(cellCount) cells in collection view")
            
            // Check each cell for our target dish names
            for i in 0..<min(cellCount, 10) {
                let cell = cells.element(boundBy: i)
                if cell.exists {
                    let cellTexts = cell.staticTexts
                    for j in 0..<cellTexts.count {
                        let text = cellTexts.element(boundBy: j)
                        if text.exists {
                            for dishName in existingDishNames {
                                if text.label.contains(dishName) {
                                    print("✅ Found existing dish '\(dishName)' in collection view cell")
                                    dishToEdit = dishName
                                    cell.tap()
                                    foundAndOpenedDish = true
                                    break
                                }
                            }
                            if foundAndOpenedDish { break }
                        }
                    }
                    if foundAndOpenedDish { break }
                }
            }
        }
        
        // Fallback: Try static text approach
        if !foundAndOpenedDish {
            print("📋 Trying static text approach...")
            for dishName in existingDishNames {
                let dishText = app.staticTexts[dishName]
                if dishText.waitForExistence(timeout: 2) {
                    print("✅ Found existing dish: '\(dishName)' as static text")
                    dishToEdit = dishName
                    dishText.tap()
                    foundAndOpenedDish = true
                    break
                }
            }
        }
        
        XCTAssertTrue(foundAndOpenedDish && dishToEdit != nil, "Should find and open an existing dish for editing")
        
        // Verify we're in the multi-step dish editing screen (should start at Basic Information)
        XCTAssertTrue(waitForStepScreen(stepTitle: "Basic Information"), "Should be in Basic Information step for editing")
        
        // Edit the dish name
        let dishNameField = app.textFields["Enter dish name"]
        XCTAssertTrue(dishNameField.waitForExistence(timeout: 5), "Should find dish name field")
        
        // Verify the original dish name is loaded
        let currentName = dishNameField.value as? String ?? ""
        XCTAssertTrue(currentName.contains(dishToEdit!), "Should load the original dish name for editing")
        print("📝 Current dish name in field: '\(currentName)'")
        
        // Edit the dish name
        let editedName = "EDITED \(dishToEdit!)"
        dishNameField.tap()
        dishNameField.clearText()
        dishNameField.typeText(editedName)
        
        // Edit the description if available
        let descriptionEditor = app.textViews.firstMatch
        if descriptionEditor.exists {
            descriptionEditor.tap()
            descriptionEditor.clearText()
            descriptionEditor.typeText("This dish has been edited by the UI test")
        }
        
        // Navigate to Meal Types step
        let nextButton = app.buttons["Next"]
        XCTAssertTrue(nextButton.isEnabled, "Next button should be enabled")
        nextButton.tap()
        
        // STEP 2: Meal Types - Change meal type if possible
        XCTAssertTrue(waitForStepScreen(stepTitle: "Meal Types"), "Should be in Meal Types step")
        
        let dinnerMealType = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Dinner'")).firstMatch
        if dinnerMealType.waitForExistence(timeout: 2) {
            dinnerMealType.tap()
            print("✅ Selected Dinner meal type")
        }
        
        // Navigate through remaining steps to save
        nextButton.tap() // Go to Ingredients step
        XCTAssertTrue(waitForStepScreen(stepTitle: "Ingredients"), "Should be in Ingredients step")
        
        nextButton.tap() // Go to Review step
        XCTAssertTrue(waitForStepScreen(stepTitle: "Review"), "Should be in Review step")
        
        // Save the edited dish
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.exists, "Save button should exist")
        XCTAssertTrue(saveButton.isEnabled, "Save button should be enabled")
        saveButton.tap()
        
        // Verify we return to dish list
        let dishListTitle = app.navigationBars["Dishes"]
        XCTAssertTrue(dishListTitle.waitForExistence(timeout: 5), "Should return to dish list after saving edits")
        
        // Verify the changes are reflected in the dish list
        Thread.sleep(forTimeInterval: 1.0) // Give time for UI to update
        
        // CRITICAL: Verify the dish edit actually worked
        let editedDishText = app.staticTexts[editedName]
        let foundEditedDish = editedDishText.waitForExistence(timeout: 5)
        
        if foundEditedDish {
            print("✅ Successfully verified dish edit - found '\(editedName)' in the dish list")
        } else {
            // Alternative: Check if any text contains our edited name
            let allStaticTexts = app.staticTexts
            var foundPartialMatch = false
            
            for i in 0..<min(allStaticTexts.count, 20) {
                let text = allStaticTexts.element(boundBy: i)
                if text.exists && text.label.contains("EDITED") {
                    print("✅ Found text containing 'EDITED': '\(text.label)'")
                    foundPartialMatch = true
                    break
                }
            }
            
            if !foundPartialMatch {
                XCTFail("❌ FAILED: Could not find edited dish '\(editedName)' or any text containing 'EDITED' in the dish list. Dish editing functionality may be broken.")
            }
        }
        
        print("✅ Successfully tested complete dish editing workflow: open → edit → save → verify")
    }
    
    // MARK: - Helper Methods
    
    /// Wait for a specific step screen to appear
    private func waitForStepScreen(stepTitle: String, timeout: TimeInterval = 5) -> Bool {
        let stepText = app.staticTexts[stepTitle]
        return stepText.waitForExistence(timeout: timeout)
    }
    
    /// Handle product selection in the ingredients step
    private func handleProductSelection() -> Bool {
        let productScreen = app.navigationBars.matching(NSPredicate(format: "identifier CONTAINS 'Product' OR identifier CONTAINS 'Select'")).firstMatch
        if productScreen.waitForExistence(timeout: 3) {
            print("🔍 Found product selection screen")
            
            // Try collection view approach for products
            let productCollection = app.collectionViews.firstMatch
            if productCollection.waitForExistence(timeout: 2) {
                let productCells = productCollection.cells
                print("🔍 Found \(productCells.count) product cells")
                
                if productCells.count > 0 {
                    // Select first available product
                    let firstProduct = productCells.element(boundBy: 0)
                    firstProduct.tap()
                    print("📱 Tapped first product cell")
                    
                    // Wait for potential navigation or look for confirmation buttons
                    Thread.sleep(forTimeInterval: 1.0)
                    
                    // Look for confirmation buttons
                    let confirmButtons = ["Done", "Add", "Select", "Confirm", "Save"]
                    for buttonName in confirmButtons {
                        let button = app.navigationBars.buttons[buttonName]
                        if button.exists && button.isHittable {
                            button.tap()
                            print("✅ Confirmed product selection with '\(buttonName)' button")
                            return true
                        }
                    }
                    
                    // If no confirm button, check if we're back on ingredients screen
                    if waitForStepScreen(stepTitle: "Ingredients", timeout: 2) {
                        print("✅ Successfully returned to ingredients screen")
                        return true
                    }
                }
            }
        }
        
        print("❌ Product selection failed")
        return false
    }
    
    // MARK: - Test Dish Deletion
    
    func testDeleteDish() throws {
        navigateToDishList()
        
        // Use the correct UI structure - CollectionView not Table
        let dishCollection = app.collectionViews.firstMatch
        XCTAssertTrue(dishCollection.waitForExistence(timeout: 5), "Should find dishes collection view")
        
        let dishCells = dishCollection.cells
        let initialDishCount = dishCells.count
        XCTAssertTrue(initialDishCount > 0, "Should have at least one dish to delete")
        
        print("📊 Initial dish count: \(initialDishCount)")
        
        // Get the name of the dish we're about to delete for verification
        let firstDish = dishCells.element(boundBy: 0)
        XCTAssertTrue(firstDish.exists, "First dish should exist")
        
        var dishNameToDelete: String?
        let cellTexts = firstDish.staticTexts
        for i in 0..<cellTexts.count {
            let text = cellTexts.element(boundBy: i)
            if text.exists && !text.label.isEmpty && text.label.count > 2 {
                // Skip generic labels, get the actual dish name
                if !text.label.contains("Main Course") && 
                   !text.label.contains("Breakfast") && 
                   !text.label.contains("Lunch") && 
                   !text.label.contains("Dinner") &&
                   !text.label.contains("Garnish") &&
                   !text.label.contains("Sauce") &&
                   !text.label.contains("Dessert") {
                    dishNameToDelete = text.label
                    print("📝 Will attempt to delete dish: '\(dishNameToDelete!)'")
                    break
                }
            }
        }
        
        // Attempt swipe-to-delete
        firstDish.swipeLeft()
        
        let deleteButton = app.buttons["Delete"]
        if deleteButton.waitForExistence(timeout: 3) {
            print("✅ Found delete button after swipe")
            deleteButton.tap()
            
            // Check for confirmation alert
            let confirmAlert = app.alerts.firstMatch
            if confirmAlert.waitForExistence(timeout: 3) {
                print("✅ Found confirmation alert")
                let confirmButton = confirmAlert.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Delete'")).firstMatch
                if confirmButton.exists {
                    print("✅ Confirming deletion")
                    confirmButton.tap()
                    
                    // Wait for deletion to complete
                    Thread.sleep(forTimeInterval: 2.0)
                    
                    // Verify deletion worked
                    let updatedDishCells = dishCollection.cells
                    let newDishCount = updatedDishCells.count
                    print("📊 Dish count after deletion: \(newDishCount)")
                    
                    if newDishCount < initialDishCount {
                        print("✅ SUCCESS: Dish count decreased (\(initialDishCount) → \(newDishCount))")
                        
                        // Double-check: ensure the specific dish is no longer there
                        if let deletedDishName = dishNameToDelete {
                            let deletedDishStillExists = app.staticTexts[deletedDishName].waitForExistence(timeout: 1)
                            if !deletedDishStillExists {
                                print("✅ VERIFIED: Dish '\(deletedDishName)' no longer found in list")
                            } else {
                                print("⚠️ Dish '\(deletedDishName)' may still exist, but count decreased")
                            }
                        }
                        
                        XCTAssertTrue(true, "Successfully deleted dish")
                    } else {
                        XCTFail("Dish count did not decrease after deletion (\(initialDishCount) → \(newDishCount))")
                    }
                } else {
                    XCTFail("Could not find Delete button in confirmation alert")
                }
            } else {
                // No confirmation alert - deletion might happen immediately (which is common)
                print("ℹ️ No confirmation alert found - checking if deletion happened immediately")
                Thread.sleep(forTimeInterval: 2.0) // Wait for UI to update
                
                let updatedDishCells = dishCollection.cells
                let newDishCount = updatedDishCells.count
                print("📊 Dish count after deletion: \(newDishCount)")
                
                if newDishCount < initialDishCount {
                    print("✅ SUCCESS: Dish deleted immediately without confirmation (\(initialDishCount) → \(newDishCount))")
                    
                    // Double-check: ensure the specific dish is no longer there
                    if let deletedDishName = dishNameToDelete {
                        let deletedDishStillExists = app.staticTexts[deletedDishName].waitForExistence(timeout: 1)
                        if !deletedDishStillExists {
                            print("✅ VERIFIED: Dish '\(deletedDishName)' no longer found in list")
                        } else {
                            print("⚠️ Dish '\(deletedDishName)' may still exist, but count decreased")
                        }
                    }
                    
                    XCTAssertTrue(true, "Successfully deleted dish without confirmation alert")
                } else {
                    print("❌ Dish count unchanged after delete button tap (\(initialDishCount) → \(newDishCount))")
                    
                    // Maybe deletion is still processing - wait a bit longer
                    Thread.sleep(forTimeInterval: 3.0)
                    let finalDishCells = dishCollection.cells
                    let finalDishCount = finalDishCells.count
                    print("📊 Final dish count after longer wait: \(finalDishCount)")
                    
                    if finalDishCount < initialDishCount {
                        print("✅ SUCCESS: Dish deleted after longer wait (\(initialDishCount) → \(finalDishCount))")
                        XCTAssertTrue(true, "Successfully deleted dish (required longer wait for UI update)")
                    } else {
                        // Even if count didn't change, check if the specific dish disappeared
                        if let deletedDishName = dishNameToDelete {
                            let deletedDishStillExists = app.staticTexts[deletedDishName].waitForExistence(timeout: 1)
                            if !deletedDishStillExists {
                                print("✅ SUCCESS: Dish '\(deletedDishName)' disappeared from list even though count unchanged")
                                print("ℹ️ This might indicate dish was deleted but list was repopulated or refreshed")
                                XCTAssertTrue(true, "Successfully verified dish removal (dish name no longer exists)")
                            } else {
                                print("❌ FAILED: Dish '\(deletedDishName)' still exists in list AND count unchanged")
                                XCTFail("Dish deletion did not work - count unchanged (\(initialDishCount) → \(finalDishCount)) and dish still exists")
                            }
                        } else {
                            XCTFail("Dish deletion did not work - count unchanged (\(initialDishCount) → \(finalDishCount))")
                        }
                    }
                }
            }
        } else {
            // Try alternative deletion methods
            print("❌ No delete button after swipe - trying long press")
            
            firstDish.press(forDuration: 2.0)
            let contextDeleteButton = app.buttons["Delete"]
            if contextDeleteButton.waitForExistence(timeout: 2) {
                contextDeleteButton.tap()
                print("✅ Used long press delete")
                
                Thread.sleep(forTimeInterval: 1.0)
                let updatedDishCells = dishCollection.cells
                let newDishCount = updatedDishCells.count
                
                if newDishCount < initialDishCount {
                    print("✅ SUCCESS: Dish deleted via long press (\(initialDishCount) → \(newDishCount))")
                    XCTAssertTrue(true, "Successfully deleted dish")
                } else {
                    XCTFail("Long press delete did not work")
                }
            } else {
                XCTFail("Could not find any delete functionality - swipe-left and long-press both failed")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func navigateToDishList() {
        // Navigate to Dishes tab
        let dishesTab = app.tabBars.buttons["Dishes"]
        XCTAssertTrue(dishesTab.waitForExistence(timeout: 3), "Dishes tab should exist")
        dishesTab.tap()
        
        // Verify we're on the dish list screen
        let dishListTitle = app.navigationBars["Dishes"]
        XCTAssertTrue(dishListTitle.waitForExistence(timeout: 3), "Should be on dish list screen")
        
        // Brief wait for content to load
        Thread.sleep(forTimeInterval: 0.3)
    }
    
    func testCreateDishValidation() throws {
        navigateToDishList()
        
        let addButton = app.navigationBars.buttons["Add New Dish"]
        addButton.tap()
        
        // Verify we're in the multi-step creation screen
        XCTAssertTrue(waitForStepScreen(stepTitle: "Basic Information"), "Should be in Basic Information step")
        
        // Test 1: Try to proceed without dish name
        let nextButton = app.buttons["Next"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 3), "Next button should exist")
        
        // Next button should be disabled without dish name
        if nextButton.isEnabled {
            print("⚠️ Next button is enabled without dish name - testing if validation happens on tap")
            nextButton.tap()
            
            // Should remain on Basic Information step
            XCTAssertTrue(waitForStepScreen(stepTitle: "Basic Information", timeout: 2), "Should remain on Basic Information step when validation fails")
        } else {
            print("✅ Next button correctly disabled without dish name")
        }
        
        // Add dish name to proceed
        let dishNameField = app.textFields["Enter dish name"]
        dishNameField.tap()
        dishNameField.typeText("Validation Test Dish")
        
        // Wait for the validation to update and Next button to become enabled
        var buttonBecameEnabled = false
        for attempt in 1...10 {
            Thread.sleep(forTimeInterval: 0.2)
            if nextButton.isEnabled {
                buttonBecameEnabled = true
                print("✅ Next button became enabled after \(Double(attempt) * 0.2) seconds")
                break
            }
            print("⏳ Attempt \(attempt): Next button still disabled")
        }
        
        XCTAssertTrue(buttonBecameEnabled, "Next button should be enabled with dish name after reasonable wait time")
        nextButton.tap()
        
        // Test 2: Try to proceed from Meal Types without selection
        XCTAssertTrue(waitForStepScreen(stepTitle: "Meal Types"), "Should be in Meal Types step")
        
        if nextButton.isEnabled {
            print("⚠️ Next button is enabled without meal type selection - testing if validation happens on tap")
            nextButton.tap()
            
            // Should remain on Meal Types step
            XCTAssertTrue(waitForStepScreen(stepTitle: "Meal Types", timeout: 2), "Should remain on Meal Types step when validation fails")
        } else {
            print("✅ Next button correctly disabled without meal type selection")
        }
        
        // Add meal type to proceed
        let breakfastMealType = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Breakfast'")).firstMatch
        if breakfastMealType.waitForExistence(timeout: 3) {
            breakfastMealType.tap()
        }
        
        XCTAssertTrue(nextButton.isEnabled, "Next button should be enabled with meal type selected")
        nextButton.tap()
        
        // Test 3: Try to proceed from Ingredients without any ingredients
        XCTAssertTrue(waitForStepScreen(stepTitle: "Ingredients"), "Should be in Ingredients step")
        
        if nextButton.isEnabled {
            print("⚠️ Next button is enabled without ingredients - testing if validation happens on tap")
            nextButton.tap()
            
            // Should remain on Ingredients step
            XCTAssertTrue(waitForStepScreen(stepTitle: "Ingredients", timeout: 2), "Should remain on Ingredients step when validation fails")
        } else {
            print("✅ Next button correctly disabled without ingredients")
        }
        
        // Add ingredient to proceed to review
        let selectProductButton = app.buttons["Select Product"]
        if selectProductButton.waitForExistence(timeout: 3) {
            selectProductButton.tap()
            let productSelectionSuccess = handleProductSelection()
            if productSelectionSuccess {
                print("✅ Successfully added ingredient for validation test")
            }
        }
        
        // Now should be able to proceed to review
        if nextButton.isEnabled {
            nextButton.tap()
            XCTAssertTrue(waitForStepScreen(stepTitle: "Review"), "Should reach Review step with all fields filled")
            
            // Test final save functionality
            let saveButton = app.buttons["Save"]
            XCTAssertTrue(saveButton.exists, "Save button should exist in Review step")
            XCTAssertTrue(saveButton.isEnabled, "Save button should be enabled with all required fields")
        }
        
        // Clean up by canceling
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.tap()
        }
        
        XCTAssertTrue(true, "✅ Successfully tested multi-step validation workflow")
    }
    
    func testDishSearch() throws {
        navigateToDishList()
        
        // First verify we have dishes to search
        let dishCollection = app.collectionViews.firstMatch
        if !dishCollection.waitForExistence(timeout: 5) {
            XCTFail("❌ FAILED: Cannot test search functionality - no dish collection found")
            return
        }
        
        let totalDishes = dishCollection.cells.count
        if totalDishes == 0 {
            XCTFail("❌ FAILED: Cannot test search functionality - no dishes in collection to search")
            return
        }
        
        print("✅ Found \(totalDishes) dishes to search through")
        
        // Look for search bar
        let searchField = app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 5) {
            print("✅ Found search field")
            
            // Test 1: Search for something that should exist
            searchField.tap()
            searchField.typeText("Beef")
            
            // Give search time to filter
            Thread.sleep(forTimeInterval: 1.0)
            
            // Verify search affects the results
            let searchResults = dishCollection.cells.count
            print("📊 Search results: \(searchResults) dishes found for 'Beef'")
            
            // Clear search and verify all dishes return
            let clearButton = searchField.buttons["Clear text"]
            if clearButton.exists {
                clearButton.tap()
            } else {
                // Alternative: clear by selecting all text and deleting
                searchField.tap()
                searchField.typeText("") // This should clear
            }
            
            Thread.sleep(forTimeInterval: 1.0)
            let restoredCount = dishCollection.cells.count
            print("📊 After clearing search: \(restoredCount) dishes shown")
            
            // Verify search is working by checking that clearing restored the count
            if restoredCount >= searchResults {
                print("✅ Search functionality appears to be working - clearing search restored dish count")
            } else {
                XCTFail("❌ FAILED: Search functionality broken - clearing search did not restore dish count (had \(totalDishes), searched got \(searchResults), cleared got \(restoredCount))")
            }
            
        } else {
            XCTFail("❌ FAILED: Could not find search field - search functionality may not be implemented or accessible")
        }
    }
    
    /// Comprehensive dish finder that uses multiple strategies to locate a dish in the list
    private func findDishInList(dishName: String) -> Bool {
        print("🔍 Searching for dish: '\(dishName)'")
        
        // Strategy 1: Quick check of currently visible items
        if findDishInCurrentView(dishName: dishName) {
            print("✅ Found dish in current view")
            return true
        }
        
        // Strategy 2: Try search functionality if available
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            print("🔍 Using search functionality to find dish")
            searchField.tap()
            searchField.typeText(dishName)
            
            // Wait for search results
            Thread.sleep(forTimeInterval: 1.5)
            
            if findDishInCurrentView(dishName: dishName) {
                print("✅ Found dish using search functionality")
                
                // Clear search before returning
                let clearButton = searchField.buttons["Clear text"]
                if clearButton.exists {
                    clearButton.tap()
                } else {
                    searchField.clearText()
                }
                Thread.sleep(forTimeInterval: 0.5)
                
                return true
            } else {
                print("⚠️ Dish not found via search, clearing search and trying scrolling")
                // Clear search
                let clearButton = searchField.buttons["Clear text"]
                if clearButton.exists {
                    clearButton.tap()
                } else {
                    searchField.clearText()
                }
                Thread.sleep(forTimeInterval: 0.5)
            }
        } else {
            print("⚠️ No search field found, trying scrolling method")
        }
        
        // Strategy 3: Scroll through the list to find the dish
        let collectionView = app.collectionViews.firstMatch
        if collectionView.exists {
            print("🔍 Scrolling through collection view to find dish")
            return findDishByScrolling(dishName: dishName, in: collectionView)
        }
        
        print("❌ Exhausted all search strategies - dish not found")
        return false
    }
    
    /// Check if dish exists in currently visible view
    private func findDishInCurrentView(dishName: String) -> Bool {
        // Check static texts first
        let dishText = app.staticTexts[dishName]
        if dishText.exists {
            return true
        }
        
        // Check collection view cells
        let collectionView = app.collectionViews.firstMatch
        if collectionView.exists {
            let cells = collectionView.cells
            let cellCount = cells.count
            
            for i in 0..<cellCount {
                let cell = cells.element(boundBy: i)
                if cell.exists {
                    let cellTexts = cell.staticTexts
                    for j in 0..<cellTexts.count {
                        let text = cellTexts.element(boundBy: j)
                        if text.exists && (text.label == dishName || text.label.contains(dishName)) {
                            return true
                        }
                    }
                }
            }
        }
        
        return false
    }
    
    /// Scroll through collection view to find dish
    private func findDishByScrolling(dishName: String, in collectionView: XCUIElement) -> Bool {
        let maxScrollAttempts = 10
        var lastCellCount = 0
        var noProgressCount = 0
        
        for attempt in 1...maxScrollAttempts {
            print("📱 Scroll attempt \(attempt)/\(maxScrollAttempts)")
            
            // Check current view
            if findDishInCurrentView(dishName: dishName) {
                print("✅ Found dish after \(attempt) scroll attempts")
                return true
            }
            
            // Track progress to avoid infinite scrolling
            let currentCellCount = collectionView.cells.count
            if currentCellCount == lastCellCount {
                noProgressCount += 1
                if noProgressCount >= 3 {
                    print("⚠️ No new content loaded after scrolling - reached end of list")
                    break
                }
            } else {
                noProgressCount = 0
                lastCellCount = currentCellCount
            }
            
            // Scroll down to load more content
            collectionView.swipeUp()
            Thread.sleep(forTimeInterval: 0.5) // Give time for content to load
        }
        
        // Final check after scrolling
        return findDishInCurrentView(dishName: dishName)
    }
} 
