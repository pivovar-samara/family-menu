import XCTest

final class ShoppingListUITests: XCTestCase {
    var app: XCUIApplication!
    var productListPageObject: ProductListPageObject!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Add launch arguments to disable CloudKit and indicate UI test environment
        app.launchArguments = [
            "-UITests",
            "-DisableCloudKit",
            "-XCTest"
        ]
        
        // Add environment variables for test detection
        app.launchEnvironment = [
            "UI_TESTS": "1",
            "DISABLE_CLOUDKIT": "1",
            "XCTestBundlePath": "UITests"
        ]
        
        productListPageObject = ProductListPageObject(app: app)
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
        productListPageObject = nil
    }
} 
