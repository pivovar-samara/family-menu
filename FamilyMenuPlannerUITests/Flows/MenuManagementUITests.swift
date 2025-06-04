import XCTest

final class MenuManagementUITests: XCTestCase {
    var app: XCUIApplication!
    var menuPageObject: MenuPageObject!
    var dishListPageObject: DishListPageObject!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        menuPageObject = MenuPageObject(app: app)
        dishListPageObject = DishListPageObject(app: app)
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
        menuPageObject = nil
        dishListPageObject = nil
    }
} 
