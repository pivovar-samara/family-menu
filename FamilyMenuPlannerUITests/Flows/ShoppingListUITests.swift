import XCTest

final class ShoppingListUITests: XCTestCase {
    var app: XCUIApplication!
    var productListPageObject: ProductListPageObject!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        productListPageObject = ProductListPageObject(app: app)
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
        productListPageObject = nil
    }
} 
