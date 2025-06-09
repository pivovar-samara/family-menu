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
            let maxAcceptableLaunchTime: TimeInterval = 5.0 // 5 second hard limit
            let warningThreshold: TimeInterval = 4.0 // 4 second warning threshold
            var launchTimes: [TimeInterval] = []
            
            // Run 3 iterations for reliability
            for iteration in 1...3 {
                let startTime = CFAbsoluteTimeGetCurrent()
                
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
                
                // Wait for critical UI elements to appear
                let tabBar = app.tabBars.firstMatch
                let tabBarAppeared = tabBar.waitForExistence(timeout: 8)
                
                let launchTime = CFAbsoluteTimeGetCurrent() - startTime
                launchTimes.append(launchTime)
                
                XCTAssertTrue(tabBarAppeared, "App should launch successfully in iteration \(iteration)")
                XCTAssertLessThanOrEqual(launchTime, maxAcceptableLaunchTime, 
                    "Launch time (\(String(format: "%.2f", launchTime))s) should not exceed \(maxAcceptableLaunchTime)s in iteration \(iteration)")
                
                // Log warning if above warning threshold but below hard limit
                if launchTime > warningThreshold && launchTime <= maxAcceptableLaunchTime {
                    print("⚠️ Launch time (\(String(format: "%.2f", launchTime))s) exceeds warning threshold of \(warningThreshold)s in iteration \(iteration)")
                }
                
                app.terminate()
                Thread.sleep(forTimeInterval: 0.5)
            }
            
            // Test average launch time (should be well within limits)
            let averageLaunchTime = launchTimes.reduce(0, +) / Double(launchTimes.count)
            XCTAssertLessThanOrEqual(averageLaunchTime, warningThreshold, 
                "Average launch time (\(String(format: "%.2f", averageLaunchTime))s) should be below warning threshold (\(warningThreshold)s)")
            
            // Performance reporting
            print("🚀 Launch Performance Results:")
            print("   Individual times: \(launchTimes.map { String(format: "%.2f", $0) }.joined(separator: "s, "))s")
            print("   Average: \(String(format: "%.2f", averageLaunchTime))s")
            print("   Warning threshold: \(warningThreshold)s")
            print("   Hard limit: \(maxAcceptableLaunchTime)s")
            
            // Additional Apple measurement for baseline tracking
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
                
                let tabBar = app.tabBars.firstMatch
                _ = tabBar.waitForExistence(timeout: 8)
                
                Thread.sleep(forTimeInterval: 0.2)
                app.terminate()
                Thread.sleep(forTimeInterval: 0.3)
            }
        }
    }
}
