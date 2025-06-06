//
//  FamilyMenuPlannerUITestsLaunchTests.swift
//  FamilyMenuPlannerUITests
//
//  Created by Ilya Khokhlov on 17.12.24.
//

import XCTest

final class FamilyMenuPlannerUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        
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
        
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
