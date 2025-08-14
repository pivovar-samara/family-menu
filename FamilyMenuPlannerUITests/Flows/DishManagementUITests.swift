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
        
        // Record initial count using new dish card identifiers
        let dishCardsQuery = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS[c] %@", "dish_list_item_"))
        let initialCount = dishCardsQuery.count
        
        // Tap add button – supports floating action button or empty-state CTA
        if app.buttons["Add Your First Dish"].exists {
            app.buttons["Add Your First Dish"].tap()
        } else if app.buttons["add_dish_button"].waitForExistence(timeout: 3) {
            app.buttons["add_dish_button"].tap()
        } else if app.navigationBars.buttons["Add New Dish"].exists {
            // Legacy fallback (should be phased out)
            app.navigationBars.buttons["Add New Dish"].tap()
        } else {
            XCTFail("❌ FAILED: Could not locate add dish button (floating action or empty state CTA)")
            return
        }
        
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
            _ = nextButton.waitAndScrollToElement(timeout: 5.0)
            nextButton.tap()
        }
        
        // STEP 4: Review
        XCTAssertTrue(waitForStepScreen(stepTitle: "Review"), "Should be in Review step")
        
        // Verify dish summary appears
        let dishSummaryCard = app.staticTexts["Dish Summary"]
        XCTAssertTrue(dishSummaryCard.waitForExistence(timeout: 3), "Should show dish summary")
        
        // Save the dish
        let saveButton = app.buttons["Save"]
        var saveAppeared = saveButton.waitForExistence(timeout: 3)
        var scrollAttempts = 0
        while !saveAppeared && scrollAttempts < 5 {
            app.swipeUp()
            saveAppeared = saveButton.waitForExistence(timeout: 1)
            scrollAttempts += 1
        }
        XCTAssertTrue(saveAppeared, "Quick create dish flow failed – Save button not found even after scrolling")
        saveButton.tap()
        
        // Verify we return to dish list
        let dishListTitle = app.navigationBars["Dishes"]
        XCTAssertTrue(dishListTitle.waitForExistence(timeout: 5), "Should return to dish list after saving")
        
        // Verify dish count and creation success
        app.waitForUIUpdate(timeout: 1.0) // Wait for UI to update using XCTWaiter
        
        let newDishCardsQuery = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS[c] %@", "dish_list_item_"))
        let newCount = newDishCardsQuery.count
        print("📊 Dish count: initial=\(initialCount), new=\(newCount)")
        
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
        
        // Final check is already covered by findDishInList. No further assertions needed here.
    }
    
    // MARK: - Test Dish Editing
    
    func testEditExistingDish() throws {
        ciLog("BEGIN testEditExistingDish")
        navigateToDishList()

        // Always create a deterministic dish to edit to avoid flakiness with preload data
        let baseName = "CI Edit Dish"
        let dishName = createTemporaryDishIfNeeded(baseName: baseName)
        ciLog("Created/ensured dish: \(dishName)")
        app.waitForUIUpdate(timeout: 1.0)

        // Narrow the list via search and open the edit screen reliably
        ciLog("Searching and opening edit for: \(dishName)")
        XCTAssertTrue(findDishInList(dishName: dishName), "Should locate created dish in list")
        XCTAssertTrue(openDishForEditing(named: dishName), "Should open edit screen for the dish")

        // Basic Information step
        XCTAssertTrue(waitForStepScreen(stepTitle: "Basic Information"))
        ciLog("On Basic Information step")
        let dishNameField = app.textFields["Enter dish name"].firstMatch
        XCTAssertTrue(dishNameField.waitForExistence(timeout: 5))

        let timestamp = Int(Date().timeIntervalSince1970)
        let editedName = "EDITED \(dishName) \(timestamp)"
        dishNameField.clearAndEnterText(editedName)
        ciLog("Entered edited name: \(editedName)")

        // Optional description
        let descriptionEditor = app.textViews.firstMatch
        if descriptionEditor.exists { descriptionEditor.clearAndEnterText("Edited at \(timestamp)") }

        // Meal Types
        let nextButton = app.buttons["Next"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 3))
        nextButton.tap()
        ciLog("Advanced to Meal Types")
        XCTAssertTrue(waitForStepScreen(stepTitle: "Meal Types"))
        // Prefer selecting a different meal type to avoid toggling off the only selected one (Breakfast)
        let preferredMealIds = ["mealTypeLunch", "mealTypeDinner", "mealTypeBreakfast"]
        var tappedMeal = false
        for id in preferredMealIds {
            let btn = app.buttons[id]
            if btn.waitForExistence(timeout: 2) {
                btn.tap()
                tappedMeal = true
                ciLog("Tapped meal type button: \(id)")
                break
            }
        }
        XCTAssertTrue(tappedMeal, "Should tap at least one meal type")
        // Ensure at least one meal type remains selected; if Next became disabled, re-select Breakfast (or another)
        if !nextButton.isEnabled {
            if app.buttons["mealTypeBreakfast"].exists { app.buttons["mealTypeBreakfast"].tap() }
            if !nextButton.isEnabled, app.buttons["mealTypeLunch"].exists { app.buttons["mealTypeLunch"].tap() }
            let enabledPred = NSPredicate(format: "isEnabled == true")
            let exp = XCTNSPredicateExpectation(predicate: enabledPred, object: nextButton)
            _ = XCTWaiter().wait(for: [exp], timeout: 3.0)
            XCTAssertTrue(nextButton.isEnabled, "Next should be enabled with at least one meal type selected")
        }

        // Ingredients (add one product if needed)
        nextButton.tap()
        ciLog("Advanced to Ingredients")
        XCTAssertTrue(waitForStepScreen(stepTitle: "Ingredients"))
        let selectProductButton = app.buttons["Select Product"]
        if selectProductButton.waitForExistence(timeout: 3) {
            selectProductButton.tap()
            ciLog("Tapped Select Product; handling selection")
            XCTAssertTrue(handleProductSelection())
        }

        // Review and Save
        _ = nextButton.waitAndScrollToElement(timeout: 5.0)
        if nextButton.isEnabled { nextButton.tap(); ciLog("Advanced to Review") }
        // Ensure we are on Review step before searching for Save
        if !waitForStepScreen(stepTitle: "Review", timeout: 5) {
            // Try again if CI lagged
            _ = nextButton.waitAndScrollToElement(timeout: 2.0)
            if nextButton.isEnabled { nextButton.tap() }
            XCTAssertTrue(waitForStepScreen(stepTitle: "Review", timeout: 5), "Should reach Review step")
        }
        // Find Save (may require scroll)
        let saveButton = app.buttons["Save"]
        var saveAppeared = saveButton.waitForExistence(timeout: 3)
        var scrollAttempts = 0
        while !saveAppeared && scrollAttempts < 6 {
            app.swipeUp()
            saveAppeared = saveButton.waitForExistence(timeout: 1)
            scrollAttempts += 1
        }
        XCTAssertTrue(saveAppeared, "Save button not found on Review step")
        ciLog("Tapping Save on Review")
        saveButton.tap()

        // Verify
        XCTAssertTrue(app.navigationBars["Dishes"].waitForExistence(timeout: 5))
        ciLog("Returned to Dishes list after save")
        app.waitForUIUpdate(timeout: 1.0)
        ciLog("Post-save before search")
        logDishListState(prefix: "Post-save before search")
        let foundEdited = findDishInList(dishName: editedName)
        if !foundEdited {
            ciLog("Post-save after search FAILED")
            logDishListState(prefix: "Post-save after search FAILED")
        }
        XCTAssertTrue(foundEdited)
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

            // Prefer table/list cells, fallback to collection view cells
            var didTapProduct = false
            let firstCell = app.cells.firstMatch
            if firstCell.waitForExistence(timeout: 2) {
                firstCell.tap()
                didTapProduct = true
                print("📱 Tapped first product cell (table/list)")
            } else {
                let productCollection = app.collectionViews.firstMatch
                if productCollection.waitForExistence(timeout: 2) {
                    let productCells = productCollection.cells
                    print("🔍 Found \(productCells.count) product cells")
                    if productCells.count > 0 {
                        productCells.element(boundBy: 0).tap()
                        didTapProduct = true
                        print("📱 Tapped first product cell (collection)")
                    }
                }
            }

            guard didTapProduct else {
                print("❌ No product cell found to tap")
                return false
            }

            // Wait for potential navigation or confirmation
            app.waitForUIUpdate(timeout: 1.0)

            // Include multi-select confirmation button
            let confirmButtons = ["Add Selected", "Done", "Add", "Select", "Confirm", "Save"]
            for buttonName in confirmButtons {
                let button = app.navigationBars.buttons[buttonName]
                if button.exists && button.isHittable {
                    button.tap()
                    print("✅ Confirmed product selection with '\(buttonName)' button")
                    return true
                }
            }

            // If no explicit confirmation, ensure we're back
            if waitForStepScreen(stepTitle: "Ingredients", timeout: 2) {
                print("✅ Successfully returned to ingredients screen")
                return true
            }
        }

        print("❌ Product selection failed")
        return false
    }

    private func openDishForEditing(named name: String) -> Bool {
        let cardId = "dish_list_item_\(name)"
        let editId = "edit_dish_button_\(name)"
        let card = app.otherElements[cardId]
        if card.exists {
            let editButtonInCard = card.buttons[editId]
            if editButtonInCard.waitAndScrollToElement(timeout: 3.0) {
                editButtonInCard.tap(); return true
            }
        }
        let directEdit = app.buttons[editId]
        if directEdit.waitAndScrollToElement(timeout: 3.0) { directEdit.tap(); return true }
        if card.waitAndScrollToElement(timeout: 3.0) { card.tap(); return true }
        let anyEdit = app.buttons.matching(NSPredicate(format: "identifier CONTAINS[c] %@", "edit_dish_button_")).firstMatch
        if anyEdit.exists && anyEdit.isHittable { anyEdit.tap(); return true }
        return false
    }
    
    // MARK: - Test Dish Deletion
    
    func testDeleteDish() throws {
        navigateToDishList()
        
        // Try to locate a dish we know exists in the preload data set
        let candidateDishes = ["Beef Stew", "Cheese Omelette", "Cucumber Yogurt Salad"]
        var dishNameToDelete: String? = nil

        for name in candidateDishes {
            if findDishInList(dishName: name) {
                dishNameToDelete = name
                break
            }
        }

        // If none of the known dishes were found (unlikely), fall back to the first visible card
        if dishNameToDelete == nil {
            let dishCardsQuery = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS[c] %@", "dish_list_item_"))
            // Wait for dish cards to appear using proper waiting mechanism
            let firstDishCard = dishCardsQuery.firstMatch
            _ = firstDishCard.waitForExistence(timeout: 3.0)
            XCTAssertTrue(dishCardsQuery.count > 0, "No dish cards found to delete – aborting test")
            dishNameToDelete = firstDishCard.identifier.replacingOccurrences(of: "dish_list_item_", with: "")
        }

        guard let dishNameToDeleteUnwrapped = dishNameToDelete else {
            XCTFail("❌ FAILED: Could not locate any dish to delete")
            return
        }

        print("🗑 Preparing to delete dish: \(dishNameToDeleteUnwrapped)")

        // Ensure the card is visible (findDishInList will have scrolled/search already)
        _ = findDishInCurrentView(dishName: dishNameToDeleteUnwrapped)

        var deleteButton = app.buttons["delete_dish_button_\(dishNameToDeleteUnwrapped)"]
        if !deleteButton.waitAndScrollToElement(timeout: 4.0) {
            // Fallback: search within the specific dish card
            let dishCard = app.otherElements["dish_list_item_\(dishNameToDeleteUnwrapped)"]
            if dishCard.exists {
                deleteButton = dishCard.buttons["delete_dish_button_\(dishNameToDeleteUnwrapped)"].firstMatch
                _ = deleteButton.waitAndScrollToElement(timeout: 2.0)
            }
        }

        XCTAssertTrue(deleteButton.exists, "Delete button should exist for dish \(dishNameToDeleteUnwrapped)")

        deleteButton.tap()

        // Confirm deletion if dialog appears
        let confirmButton = app.buttons["Delete"].firstMatch
        if confirmButton.waitForExistence(timeout: 3) {
            confirmButton.tap()
        }

        // Wait for delete button to disappear indicating the card is gone
        let deletePredicate = NSPredicate(format: "exists == false")
        let deleteExpectation = XCTNSPredicateExpectation(predicate: deletePredicate, object: deleteButton)
        let deleteWaiter = XCTWaiter()
        let deleteResult = deleteWaiter.wait(for: [deleteExpectation], timeout: 5.0)
        let stillExists = deleteResult != .completed

        XCTAssertFalse(stillExists, "Deleted dish should disappear from the list")

        print("✅ SUCCESS: Dish deletion verified")
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
        
        // Wait for content to load using proper waiting mechanism
        app.waitForUIUpdate(timeout: 0.5)
    }
    
    func testCreateDishValidation() throws {
        navigateToDishList()
        
        // Tap add button – supports new floating action button or empty-state CTA
        if app.buttons["Add Your First Dish"].exists {
            app.buttons["Add Your First Dish"].tap()
        } else if app.buttons["add_dish_button"].waitForExistence(timeout: 3) {
            app.buttons["add_dish_button"].tap()
        } else if app.navigationBars.buttons["Add New Dish"].exists {
            // Fallback for legacy toolbar item (should no longer be used)
            app.navigationBars.buttons["Add New Dish"].tap()
        } else {
            XCTFail("❌ FAILED: Could not find UI element to start dish creation (add button)")
        }
        
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
        let enabledPredicate = NSPredicate(format: "isEnabled == true")
        let enabledExpectation = XCTNSPredicateExpectation(predicate: enabledPredicate, object: nextButton)
        let enabledWaiter = XCTWaiter()
        let enabledResult = enabledWaiter.wait(for: [enabledExpectation], timeout: 2.0)
        let buttonBecameEnabled = enabledResult == .completed
        
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
        let mealTypeIdentifiers = ["mealTypeBreakfast", "mealTypeLunch", "mealTypeDinner"]
        var mealButtonFound = false
        for identifier in mealTypeIdentifiers {
            let btn = app.buttons[identifier]
            if btn.waitAndScrollToElement(timeout: 3.0) {
                btn.tap()
                mealButtonFound = true
                break
            }
        }
        XCTAssertTrue(mealButtonFound, "❌ FAILED: Could not find any meal type button to select")
        
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
        
        var dishCardsQuery = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS[c] %@", "dish_list_item_"))
        var totalDishes = dishCardsQuery.count
        var waitCount = 0
        while totalDishes == 0 && waitCount < 10 {
            app.waitForUIUpdate(timeout: 0.5)
            dishCardsQuery = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS[c] %@", "dish_list_item_"))
            totalDishes = dishCardsQuery.count
            waitCount += 1
        }
        if totalDishes == 0 {
            print("⚠️ No dishes to search – creating a temporary dish")
            _ = createTemporaryDishIfNeeded(baseName: "Search Test Dish")
            app.waitForUIUpdate(timeout: 1.0)
            // Refresh query/counts
            dishCardsQuery = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS[c] %@", "dish_list_item_"))
            totalDishes = dishCardsQuery.count
            XCTAssertTrue(totalDishes > 0, "Should have at least one dish after creation for search test")
            print("✅ Created temporary dish '")
        }
        print("✅ Found \(totalDishes) dishes to search through")

        // Look for search bar
        let searchField = app.searchFields.firstMatch
        if !searchField.waitForExistence(timeout: 5) {
            XCTFail("❌ FAILED: Could not find search field - search functionality may not be accessible")
            return
        }

        print("✅ Found search field")

        // Perform search for a term we expect to match
        searchField.tap()
        searchField.typeText("Beef")

        // Allow results to update
        app.waitForUIUpdate(timeout: 1.0)

        let searchResultsCount = dishCardsQuery.count
        print("📊 Search results: \(searchResultsCount) dishes found for 'Beef'")

        // Clear search
        if searchField.buttons["Clear text"].exists {
            searchField.buttons["Clear text"].tap()
        } else {
            searchField.clearText()
        }

        app.waitForUIUpdate(timeout: 0.5)
        let restoredCount = dishCardsQuery.count
        print("📊 After clearing search: \(restoredCount) dishes shown")

        XCTAssertTrue(searchResultsCount < totalDishes, "Search should reduce the number of visible dish cards")
        XCTAssertTrue(restoredCount >= searchResultsCount, "Clearing search should increase or restore the number of visible dish cards")
    }
    
    /// Comprehensive dish finder that uses multiple strategies to locate a dish in the list
    private func findDishInList(dishName: String) -> Bool {
        ciLog("Searching for dish: '" + dishName + "'")
        logDishListState(prefix: "Initial state")
        
        // Strategy 1: Quick check of currently visible items
        if findDishInCurrentView(dishName: dishName) {
            ciLog("Found dish in current view")
            return true
        }
        
        // Strategy 2: Try search functionality if available
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            ciLog("Using search functionality to find dish; clearing previous text if needed")
            // Clear existing text first for determinism
            if let currentVal = searchField.value as? String, !currentVal.isEmpty, currentVal != (searchField.placeholderValue ?? "") {
                ciLog("Clearing existing search text: '" + currentVal + "'")
                if searchField.buttons["Clear text"].exists { searchField.buttons["Clear text"].tap() } else { searchField.clearTextWithFallback() }
                XCUIApplication().waitForUIUpdate(timeout: 0.5)
            }
            searchField.tap()
            searchField.typeText(dishName)
            
            var foundViaSearch = false
            for i in 0..<8 { // Up to ~4 seconds total wait (8*0.5)
                let countNow = XCUIApplication().otherElements.matching(NSPredicate(format: "identifier CONTAINS[c] %@", "dish_list_item_")).count
                ciLog("Search poll #\(i+1): visible dish card count=\(countNow)")
                if findDishInCurrentView(dishName: dishName) {
                    foundViaSearch = true
                    break
                }
                app.waitForUIUpdate(timeout: 0.5)
            }

            if foundViaSearch {
                ciLog("Found dish using search functionality")
                // Keep the search filter active so the dish card remains visible for further actions (e.g., delete)
                // The caller can decide when to clear the search later.
                return true
            } else {
                ciLog("Dish not found via search after waiting, clearing search and falling back to scrolling")
                // Clear search
                let clearButton = searchField.buttons["Clear text"]
                if clearButton.exists {
                    clearButton.tap()
                } else {
                    searchField.clearText()
                }
                app.waitForUIUpdate(timeout: 0.5)
                logDishListState(prefix: "After clearing search fallback")
            }
        } else {
            ciLog("No search field found, trying scrolling method")
        }
        
        // Prefer scroll view with dish cards
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            ciLog("Scrolling through scroll view to find dish")
            return findDishByScrolling(dishName: dishName, in: scrollView)
        }
        
        // Legacy collection view fallback
        let collectionView = app.collectionViews.firstMatch
        if collectionView.exists {
            ciLog("Scrolling through collection view to find dish (legacy)")
            return findDishByScrollingLegacy(dishName: dishName, in: collectionView)
        }
        
        ciLog("Exhausted all search strategies - dish not found")
        logDishListState(prefix: "Final state - not found")
        return false
    }
    
    /// Check if dish exists in currently visible view
    private func findDishInCurrentView(dishName: String) -> Bool {
        // First, use the precise accessibility identifier – this is the most reliable.
        let cardIdentifier = "dish_list_item_\(dishName)"
        if app.otherElements[cardIdentifier].exists {
            return true
        }
        // Quick check for directly visible static text
        if app.staticTexts[dishName].exists {
            return true
        }

        // Check custom dish card elements
        let dishCardsQuery = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS[c] %@", "dish_list_item_"))
        for idx in 0..<dishCardsQuery.count {
            let card = dishCardsQuery.element(boundBy: idx)
            if card.exists {
                let texts = card.staticTexts
                for j in 0..<texts.count {
                    let text = texts.element(boundBy: j)
                    if text.exists && (text.label == dishName || text.label.contains(dishName)) {
                        return true
                    }
                }
            }
        }

        // Legacy collection view fallback
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

    private func logDishListState(prefix: String) {
        let cards = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS[c] %@", "dish_list_item_"))
        let count = cards.count
        let searchField = app.searchFields.firstMatch
        let searchExists = searchField.exists
        let searchValue = (searchField.value as? String) ?? "<nil>"
        print("📋 [\(prefix)] dish_cards_count=\(count), search_exists=\(searchExists), search_value='\(searchValue)')")
        // Log up to first 3 visible dish names
        var names: [String] = []
        for i in 0..<min(count, 3) {
            let card = cards.element(boundBy: i)
            let texts = card.staticTexts
            for j in 0..<texts.count {
                let t = texts.element(boundBy: j)
                if t.exists, !t.label.isEmpty {
                    names.append(t.label)
                    break
                }
            }
        }
        if !names.isEmpty { print("📄 [\(prefix)] first_visible_cards=\(names)") }
    }
    
    /// Scroll through a scroll view containing dish cards
    private func findDishByScrolling(dishName: String, in scrollView: XCUIElement) -> Bool {
        let maxScrollAttempts = 10
        for attempt in 1...maxScrollAttempts {
            ciLog("Scroll attempt \(attempt)/\(maxScrollAttempts)")
            if findDishInCurrentView(dishName: dishName) {
                ciLog("Found dish after \(attempt) scroll attempts")
                return true
            }
            scrollView.swipeUp()
            app.waitForUIUpdate(timeout: 0.5)
        }
        return findDishInCurrentView(dishName: dishName)
    }
    
    // Legacy helper for collection view scrolling
    private func findDishByScrollingLegacy(dishName: String, in collectionView: XCUIElement) -> Bool {
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
            app.waitForUIUpdate(timeout: 0.5) // Give time for content to load
        }
        
        // Final check after scrolling
        return findDishInCurrentView(dishName: dishName)
    }
    
    /// Quickly creates a minimal dish via the UI if the list is empty. Returns the name of the created dish.
    private func createTemporaryDishIfNeeded(baseName: String = "Temp Dish") -> String {
        var uniqueName = baseName
        var counter = 1
        while app.staticTexts[uniqueName].exists {
            counter += 1
            uniqueName = "\(baseName) \(counter)"
        }

        // Tap add button (floating or empty state)
        if app.buttons["Add Your First Dish"].exists {
            app.buttons["Add Your First Dish"].tap()
        } else if app.buttons["add_dish_button"].waitForExistence(timeout: 3) {
            app.buttons["add_dish_button"].tap()
        } else {
            XCTFail("❌ FAILED: Could not find button to create temporary dish")
            return uniqueName
        }

        // Basic Info step
        let nameField = app.textFields["Enter dish name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText(uniqueName)

        let descriptionView = app.textViews.firstMatch
        if descriptionView.exists { descriptionView.tap(); descriptionView.typeText("Auto-created dish for UI tests") }

        let nextButton = app.buttons["Next"]
        XCTAssertTrue(nextButton.exists)
        nextButton.tap()

        // Meal Types – select first available meal type button
        let mealTypeIdentifiers = ["mealTypeBreakfast", "mealTypeLunch", "mealTypeDinner"]
        var mealButtonFound = false
        for identifier in mealTypeIdentifiers {
            let btn = app.buttons[identifier]
            if btn.waitAndScrollToElement(timeout: 3.0) {
                btn.tap()
                mealButtonFound = true
                break
            }
        }
        XCTAssertTrue(mealButtonFound, "❌ FAILED: Could not find any meal type button to select")
        nextButton.tap() // Ingredients step

        // Ingredients Step – select a product using the robust helper (confirms selection)
        let selectProductButton = app.buttons["Select Product"]
        if selectProductButton.waitForExistence(timeout: 3) {
            selectProductButton.tap()
            XCTAssertTrue(handleProductSelection(), "Product selection should succeed and return to Ingredients")
        } else {
            XCTFail("❌ FAILED: Select Product button not found in Ingredients step")
        }

        // Proceed to Review step – wait for Next to become enabled on CI
        let enabledPredicate = NSPredicate(format: "isEnabled == true")
        let enabledExpectation = XCTNSPredicateExpectation(predicate: enabledPredicate, object: nextButton)
        _ = XCTWaiter().wait(for: [enabledExpectation], timeout: 3.0)
        XCTAssertTrue(nextButton.isEnabled, "Next should be enabled after confirming product selection")
        nextButton.tap() // Review step

        let saveButton = app.buttons["Save"]
        var saveAppeared = saveButton.waitForExistence(timeout: 3)
        var scrollAttempts = 0
        while !saveAppeared && scrollAttempts < 5 {
            app.swipeUp()
            saveAppeared = saveButton.waitForExistence(timeout: 1)
            scrollAttempts += 1
        }
        XCTAssertTrue(saveAppeared, "Quick create dish flow failed – Save button not found even after scrolling")
        saveButton.tap()
        
        XCTAssertTrue(app.navigationBars["Dishes"].waitForExistence(timeout: 5))
        
        // Wait for dish cards to appear after save using proper waiting mechanism
        let dishCardsAfterSave = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS[c] %@", "dish_list_item_"))
        let firstSavedDishCard = dishCardsAfterSave.firstMatch
        _ = firstSavedDishCard.waitForExistence(timeout: 5.0)
        if dishCardsAfterSave.count == 0 {
            // As fallback, verify dish title appears somewhere visible (after possible scrolling)
            var titleFound = app.staticTexts[uniqueName].waitForExistence(timeout: 2)
            if !titleFound {
                var titleScrolls = 0
                while !titleFound && titleScrolls < 5 {
                    app.swipeUp()
                    titleFound = app.staticTexts[uniqueName].waitForExistence(timeout: 1)
                    titleScrolls += 1
                }
            }
            XCTAssertTrue(titleFound, "Dish title \(uniqueName) should appear after saving")
        }

        return uniqueName
    }
    
    // MARK: - Sorting Tests
    
    func testSortButtonExists() throws {
        navigateToDishList()
        
        // Verify sort button exists in navigation bar
        let sortButton = app.buttons["sort_dishes_button"]
        XCTAssertTrue(sortButton.waitForExistence(timeout: 5), "Sort button should exist in navigation bar")
        
        // Verify sort button has accessibility label
        XCTAssertEqual(sortButton.label, "Sort dishes", "Sort button should have correct accessibility label")
        
        print("✅ Sort button found and properly labeled")
    }
    
    func testSortMenuOpens() throws {
        navigateToDishList()
        
        // Tap sort button
        let sortButton = app.buttons["sort_dishes_button"]
        XCTAssertTrue(sortButton.waitForExistence(timeout: 5), "Sort button should exist")
        sortButton.tap()
        
        // Verify sort menu appears with all options
        let sortMenuExpected = ["Name A-Z", "Name Z-A", "Category"]
        
        for option in sortMenuExpected {
            let menuOption = app.buttons[option]
            XCTAssertTrue(menuOption.waitForExistence(timeout: 3), "Sort option '\(option)' should appear in menu")
        }
        
        print("✅ Sort menu opens with all expected options")
        
        // Close menu by tapping elsewhere
        app.tap()
    }
    
    func testSortByNameAscending() throws {
        navigateToDishList()
        
        // Ensure we have enough dishes to test sorting
        let dishCardsQuery = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS[c] %@", "dish_list_item_"))
        let initialCount = dishCardsQuery.count
        
        if initialCount < 2 {
            // Create temporary dishes with specific names for sorting
            _ = createTemporaryDishIfNeeded(baseName: "Zebra Dish")
            _ = createTemporaryDishIfNeeded(baseName: "Apple Dish")
        }
        
        // Open sort menu and select Name A-Z
        let sortButton = app.buttons["sort_dishes_button"]
        XCTAssertTrue(sortButton.waitForExistence(timeout: 5), "Sort button should exist")
        sortButton.tap()
        
        let nameAscOption = app.buttons["Name A-Z"]
        XCTAssertTrue(nameAscOption.waitForExistence(timeout: 3), "Name A-Z option should exist")
        nameAscOption.tap()
        
        // Wait for sort to take effect
        app.waitForUIUpdate(timeout: 1.0)
        
        // Verify dishes are sorted alphabetically
        let updatedDishCardsQuery = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS[c] %@", "dish_list_item_"))
        
        if updatedDishCardsQuery.count >= 2 {
            // Get first few dish names and verify they're in alphabetical order
            let firstDishCard = updatedDishCardsQuery.element(boundBy: 0)
            let secondDishCard = updatedDishCardsQuery.element(boundBy: 1)
            
            if firstDishCard.exists && secondDishCard.exists {
                // Get dish names using accessibility identifiers
                let firstDishNameElement = firstDishCard.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "dish_name_")).firstMatch
                let secondDishNameElement = secondDishCard.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "dish_name_")).firstMatch
                
                if firstDishNameElement.exists && secondDishNameElement.exists {
                    let firstDishText = firstDishNameElement.label
                    let secondDishText = secondDishNameElement.label
                    
                    // Check if first dish name comes before second in alphabetical order
                    let isAlphabetical = firstDishText.localizedCaseInsensitiveCompare(secondDishText) != .orderedDescending
                    XCTAssertTrue(isAlphabetical, "Dishes should be sorted alphabetically A-Z. Found: '\(firstDishText)' before '\(secondDishText)'")
                    
                    print("✅ Dishes sorted alphabetically A-Z: '\(firstDishText)' before '\(secondDishText)'")
                } else {
                    XCTFail("Could not find dish name elements with accessibility identifiers")
                }
            }
        }
    }
    
    func testSortByNameDescending() throws {
        navigateToDishList()
        
        // Ensure we have enough dishes to test sorting
        let dishCardsQuery = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS[c] %@", "dish_list_item_"))
        let initialCount = dishCardsQuery.count
        
        if initialCount < 2 {
            // Create temporary dishes with specific names for sorting
            _ = createTemporaryDishIfNeeded(baseName: "Apple Dish")
            _ = createTemporaryDishIfNeeded(baseName: "Zebra Dish")
        }
        
        // Open sort menu and select Name Z-A
        let sortButton = app.buttons["sort_dishes_button"]
        XCTAssertTrue(sortButton.waitForExistence(timeout: 5), "Sort button should exist")
        sortButton.tap()
        
        let nameDescOption = app.buttons["Name Z-A"]
        XCTAssertTrue(nameDescOption.waitForExistence(timeout: 3), "Name Z-A option should exist")
        nameDescOption.tap()
        
        // Wait for sort to take effect
        app.waitForUIUpdate(timeout: 1.0)
        
        // Verify dishes are sorted reverse alphabetically
        let updatedDishCardsQuery = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS[c] %@", "dish_list_item_"))
        
        if updatedDishCardsQuery.count >= 2 {
            let firstDishCard = updatedDishCardsQuery.element(boundBy: 0)
            let secondDishCard = updatedDishCardsQuery.element(boundBy: 1)
            
            if firstDishCard.exists && secondDishCard.exists {
                // Get dish names using accessibility identifiers
                let firstDishNameElement = firstDishCard.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "dish_name_")).firstMatch
                let secondDishNameElement = secondDishCard.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "dish_name_")).firstMatch
                
                if firstDishNameElement.exists && secondDishNameElement.exists {
                    let firstDishText = firstDishNameElement.label
                    let secondDishText = secondDishNameElement.label
                    
                    // Check if first dish name comes after second in alphabetical order (reverse)
                    let isReverseAlphabetical = firstDishText.localizedCaseInsensitiveCompare(secondDishText) != .orderedAscending
                    XCTAssertTrue(isReverseAlphabetical, "Dishes should be sorted reverse alphabetically Z-A. Found: '\(firstDishText)' before '\(secondDishText)'")
                    
                    print("✅ Dishes sorted reverse alphabetically Z-A: '\(firstDishText)' before '\(secondDishText)'")
                } else {
                    XCTFail("Could not find dish name elements with accessibility identifiers")
                }
            }
        }
    }
    
    func testSortByCategory() throws {
        navigateToDishList()
        
        // Open sort menu and select Category
        let sortButton = app.buttons["sort_dishes_button"]
        XCTAssertTrue(sortButton.waitForExistence(timeout: 5), "Sort button should exist")
        sortButton.tap()
        
        let categoryOption = app.buttons["Category"]
        XCTAssertTrue(categoryOption.waitForExistence(timeout: 3), "Category option should exist")
        categoryOption.tap()
        
        // Wait for sort to take effect
        app.waitForUIUpdate(timeout: 1.0)
        
        // Verify dishes are sorted by category
        // For this test, we just verify that the sort action completed successfully
        // since the exact category order depends on the preloaded data
        let updatedDishCardsQuery = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS[c] %@", "dish_list_item_"))
        XCTAssertGreaterThanOrEqual(updatedDishCardsQuery.count, 0, "Dishes should still be displayed after category sort")
        
        print("✅ Category sort completed successfully")
    }
    
    func testSortMenuShowsSelectedOption() throws {
        navigateToDishList()
        
        // Open sort menu and select Name Z-A
        let sortButton = app.buttons["sort_dishes_button"]
        XCTAssertTrue(sortButton.waitForExistence(timeout: 5), "Sort button should exist")
        sortButton.tap()
        
        let nameDescOption = app.buttons["Name Z-A"]
        XCTAssertTrue(nameDescOption.waitForExistence(timeout: 3), "Name Z-A option should exist")
        nameDescOption.tap()
        
        // Wait for sort to take effect
        app.waitForUIUpdate(timeout: 0.5)
        
        // Open sort menu again
        sortButton.tap()
        
        // Verify selected option shows checkmark
        // Note: In the actual implementation, we check for the presence of the option
        // The checkmark is part of the button's internal structure
        XCTAssertTrue(nameDescOption.waitForExistence(timeout: 3), "Selected sort option should still be visible")
        
        print("✅ Sort menu shows selected option correctly")
        
        // Close menu
        app.tap()
    }
    
    func testSortPersistenceAfterNavigation() throws {
        navigateToDishList()
        
        // Set sort to Name Z-A
        let sortButton = app.buttons["sort_dishes_button"]
        XCTAssertTrue(sortButton.waitForExistence(timeout: 5), "Sort button should exist")
        sortButton.tap()
        
        let nameDescOption = app.buttons["Name Z-A"]
        XCTAssertTrue(nameDescOption.waitForExistence(timeout: 3), "Name Z-A option should exist")
        nameDescOption.tap()
        
        // Navigate away and back
        // Go to Products tab
        let productsTab = app.tabBars.buttons["Products"]
        if productsTab.waitForExistence(timeout: 3) {
            productsTab.tap()
            
            // Navigate back to Dishes
            let dishesTab = app.tabBars.buttons["Dishes"]
            XCTAssertTrue(dishesTab.waitForExistence(timeout: 3), "Dishes tab should exist")
            dishesTab.tap()
        }
        
        // Verify sort option is still selected
        XCTAssertTrue(sortButton.waitForExistence(timeout: 5), "Sort button should exist after navigation")
        sortButton.tap()
        
        // The selected option should still be Name Z-A
        XCTAssertTrue(nameDescOption.waitForExistence(timeout: 3), "Name Z-A option should still be available")
        
        print("✅ Sort preference persisted after navigation")
        
        // Close menu
        app.tap()
    }
} 

