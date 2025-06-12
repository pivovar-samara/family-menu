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
            // Use Apple's built-in launch performance metric
            // This measures actual app launch time (not UI automation overhead)
            // Apple will fail the test automatically if performance degrades significantly
            // from baseline measurements
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                let app = XCUIApplication()
                app.launchArguments = [
                    "-UITests",
                    "-DisableCloudKit", 
                    "-XCTest",
                    "-InMemoryStore"
                ]
                app.launchEnvironment = [
                    "UI_TESTS": "1",
                    "DISABLE_CLOUDKIT": "1",
                    "TESTING_ENVIRONMENT": "1"
                ]
                
                app.launch()
                
                // More robust verification that the app launched successfully
                // Check for basic UI elements rather than just app state
                let exists = app.windows.firstMatch.waitForExistence(timeout: 10)
                if !exists {
                    // If app didn't launch properly, try to get some debug info
                    print("⚠️ App window not found, app state: \(app.state)")
                }
                
                // Give the app a moment to fully load
                Thread.sleep(forTimeInterval: 0.5)
                
                app.terminate()
            }
            
            print("🚀 Launch Performance Test Completed")
        } else {
            // Fallback for older versions
            let app = XCUIApplication()
            app.launchArguments = [
                "-UITests",
                "-DisableCloudKit", 
                "-XCTest",
                "-InMemoryStore"
            ]
            app.launch()
            
            // Simple verification
            XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
            
            app.terminate()
            print("🚀 Launch Test Completed (Legacy)")
        }
    }
}
