//
//  FamilyMenuPlannerUITestsLaunchTests.swift
//  FamilyMenuPlannerUITests
//
//  Created by Ilya Khokhlov on 17.12.24.
//

import XCTest

final class FamilyMenuPlannerUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        // Disable running for each UI configuration to reduce overhead
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        // Add explicit cleanup
        try super.tearDownWithError()
    }

    func testLaunch() throws {
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

        // Wait for either a tab bar (iPhone) or a sidebar-like container (iPad/macCatalyst) to appear
        let tabBar = app.tabBars.firstMatch
        // Common sidebar containers in SwiftUI apps: a collection view or a table with identifier "Sidebar"
        let sidebarCollection = app.collectionViews["Sidebar"].firstMatch
        let sidebarTable = app.tables["Sidebar"].firstMatch

        let uiElementAppeared: Bool
        if tabBar.exists {
            uiElementAppeared = tabBar.waitForExistence(timeout: 10)
        } else if sidebarCollection.exists {
            uiElementAppeared = sidebarCollection.waitForExistence(timeout: 10)
        } else if sidebarTable.exists {
            uiElementAppeared = sidebarTable.waitForExistence(timeout: 10)
        } else {
            // Fall back to other common containers that indicate primary navigation is present
            let maybeNavBar = app.navigationBars.firstMatch
            let maybeOutline = app.outlines.firstMatch
            if maybeNavBar.exists {
                uiElementAppeared = maybeNavBar.waitForExistence(timeout: 10)
            } else {
                uiElementAppeared = maybeOutline.waitForExistence(timeout: 10)
            }
        }

        XCTAssertTrue(uiElementAppeared, "App should launch and show primary navigation (tab bar on iPhone or sidebar on iPad)")

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        // Use deleteOnSuccess to reduce overhead and prevent background processing
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .deleteOnSuccess  // Changed from .keepAlways
        add(attachment)
        
        // Ensure screenshot is processed before termination using XCTWaiter
        let screenshotExpectation = XCTestExpectation(description: "Wait for screenshot processing")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            screenshotExpectation.fulfill()
        }
        _ = XCTWaiter.wait(for: [screenshotExpectation], timeout: 1.0)
        
        // Properly terminate the app to prevent it from running indefinitely
        app.terminate()
        
        // Give time for termination to complete using XCTWaiter
        let terminationExpectation = XCTestExpectation(description: "Wait for app termination")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            terminationExpectation.fulfill()
        }
        _ = XCTWaiter.wait(for: [terminationExpectation], timeout: 1.0)
        
        // Verify app was terminated
        XCTAssertFalse(app.state == .runningForeground, "App should be terminated")
    }
}
