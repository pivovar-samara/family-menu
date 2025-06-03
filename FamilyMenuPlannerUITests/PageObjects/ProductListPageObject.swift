import XCTest

class ProductListPageObject {
    let app: XCUIApplication
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    var addProductButton: XCUIElement {
        app.buttons["add_product_button"]
    }
    
    var productList: XCUIElement {
        app.tables["product_list"]
    }
    
    var searchField: XCUIElement {
        app.searchFields["product_search_field"]
    }
    
    var sortButton: XCUIElement {
        app.buttons["sort_button"]
    }
    
    func addNewProduct() {
        addProductButton.tap()
    }
    
    func searchForProduct(name: String) {
        searchField.tap()
        searchField.typeText(name)
    }
    
    func selectProduct(at index: Int) {
        productList.cells.element(boundBy: index).tap()
    }
    
    func selectProduct(name: String) {
        let productCell = productList.cells.containing(.staticText, identifier: name).firstMatch
        productCell.tap()
    }
    
    func verifyProductExists(name: String) -> Bool {
        return productList.cells.containing(.staticText, identifier: name).firstMatch.exists
    }
    
    func verifyProductCount(_ expectedCount: Int) -> Bool {
        return productList.cells.count == expectedCount
    }
    
    func swipeToDelete(productName: String) {
        let productCell = productList.cells.containing(.staticText, identifier: productName).firstMatch
        productCell.swipeLeft()
    }
    
    func editProduct(name: String) {
        let productCell = productList.cells.containing(.staticText, identifier: name).firstMatch
        productCell.tap()
    }
} 