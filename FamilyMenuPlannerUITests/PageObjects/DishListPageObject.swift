import XCTest

class DishListPageObject {
    let app: XCUIApplication
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    var addDishButton: XCUIElement {
        app.buttons["add_dish_button"]
    }
    
    var dishList: XCUIElement {
        app.tables["dish_list"]
    }
    
    var searchField: XCUIElement {
        app.searchFields["dish_search_field"]
    }
    
    var filterButton: XCUIElement {
        app.buttons["filter_button"]
    }
    
    func addNewDish() {
        addDishButton.tap()
    }
    
    func searchForDish(name: String) {
        searchField.tap()
        searchField.typeText(name)
    }
    
    func selectDish(at index: Int) {
        dishList.cells.element(boundBy: index).tap()
    }
    
    func verifyDishExists(name: String) -> Bool {
        return dishList.cells.containing(.staticText, identifier: name).firstMatch.exists
    }
    
    func verifyDishCount(_ expectedCount: Int) -> Bool {
        return dishList.cells.count == expectedCount
    }
    
    func longPressDish(name: String) {
        let dishCell = dishList.cells.containing(.staticText, identifier: name).firstMatch
        dishCell.press(forDuration: 1.0)
    }
} 