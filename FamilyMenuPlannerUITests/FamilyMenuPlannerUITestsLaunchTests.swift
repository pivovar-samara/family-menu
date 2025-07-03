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

        // Wait for app to fully load before taking screenshot
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "App should launch and show tab bar")

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
