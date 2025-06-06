import XCTest

final class MenuManagementUITests: XCTestCase {
    var app: XCUIApplication!
    var menuPageObject: MenuPageObject!
    var dishListPageObject: DishListPageObject!
    
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
