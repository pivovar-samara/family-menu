//
//  FamilyMenuPlannerUITests.swift
//  FamilyMenuPlannerUITests
//
//  Created by Ilya Khokhlov on 17.12.24.
//

import XCTest

final class FamilyMenuPlannerUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it's important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        
        // Ensure all apps are terminated
        let app = XCUIApplication()
        if app.state == .runningForeground || app.state == .runningBackground {
            app.terminate()
            Thread.sleep(forTimeInterval: 0.3)
        }
        
        try super.tearDownWithError()
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                let app = XCUIApplication()
                
                // Add launch arguments to disable CloudKit and indicate UI test environment
                app.launchArguments = [
                    "-UITests",
                    "-DisableCloudKit", 
                    "-XCTest",
                    "-InMemoryStore"
                ]
                
                // Add environment variables for test detection
                app.launchEnvironment = [
                    "UI_TESTS": "1",
                    "DISABLE_CLOUDKIT": "1",
                    "XCTestBundlePath": "UITests",
                    "TESTING_ENVIRONMENT": "1"
                ]
                
                app.launch()
                
                // Wait for app to fully load to ensure measurement accuracy
                let tabBar = app.tabBars.firstMatch
                _ = tabBar.waitForExistence(timeout: 10)
                
                // Ensure app is ready before termination
                Thread.sleep(forTimeInterval: 0.2)
                
                // Terminate app to ensure clean measurement cycles
                app.terminate()
                
                // Wait for termination to complete before next iteration
                Thread.sleep(forTimeInterval: 0.3)
            }
        }
    }
}
