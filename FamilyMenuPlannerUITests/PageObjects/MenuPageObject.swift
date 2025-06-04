import XCTest

class MenuPageObject {
    let app: XCUIApplication
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    var addDishButton: XCUIElement {
        app.buttons["add_dish_to_menu_button"]
    }
    
    var menuTable: XCUIElement {
        app.tables["menu_table"]
    }
    
    var weekNavigationButton: XCUIElement {
        app.buttons["week_navigation"]
    }
    
    var generateShoppingListButton: XCUIElement {
        app.buttons["generate_shopping_list"]
    }
    
    func addDish(name: String) {
        addDishButton.tap()
        
        // Select dish from the list (would need actual dish selection UI)
        let dishSelectionList = app.tables["dish_selection_list"]
        let dishCell = dishSelectionList.cells.containing(.staticText, identifier: name).firstMatch
        
        if dishCell.exists {
            dishCell.tap()
        }
        
        // Confirm addition
        let confirmButton = app.buttons["confirm_add_dish"]
        if confirmButton.exists {
            confirmButton.tap()
        }
    }
    
    func verifyDishExists(name: String) -> Bool {
        return menuTable.cells.containing(.staticText, identifier: name).firstMatch.exists
    }
    
    func removeDish(name: String) {
        let dishCell = menuTable.cells.containing(.staticText, identifier: name).firstMatch
        dishCell.swipeLeft()
        
        let deleteButton = app.buttons["Delete"]
        if deleteButton.exists {
            deleteButton.tap()
        }
    }
    
    func navigateToNextWeek() {
        weekNavigationButton.tap()
        app.buttons["next_week"].tap()
    }
    
    func navigateToPreviousWeek() {
        weekNavigationButton.tap()
        app.buttons["previous_week"].tap()
    }
    
    func generateShoppingList() {
        generateShoppingListButton.tap()
    }
    
    func verifyMenuIsEmpty() -> Bool {
        return menuTable.cells.count == 0
    }
    
    func verifyMenuItemCount(_ expectedCount: Int) -> Bool {
        return menuTable.cells.count == expectedCount
    }
} 