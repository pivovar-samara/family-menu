//
//  UITestExtensions.swift
//  FamilyMenuPlannerUITests
//
//  Created by Critical Test Review on 28.01.25.
//

import XCTest
import Foundation

// MARK: - XCUIElement Extensions for UI Testing

extension XCUIElement {
    func clearText() {
        guard let stringValue = self.value as? String else {
            return
        }
        
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        typeText(deleteString)
    }
}

// MARK: - CI-visible logging helpers

/// Logs a message that is visible in CI (xcodebuild output) and attaches it to the test activity.
/// In CI, emits an expected failure so the message is printed to standard output without failing the test.
@inline(__always)
func ciLog(_ message: String, file: StaticString = #filePath, line: UInt = #line) {
    let formatted = "CI_LOG: " + message
    // 1) Write to stdout/stderr so it appears even with xcodebuild -quiet
    if let data = (formatted + "\n").data(using: .utf8) {
        FileHandle.standardOutput.write(data)
        FileHandle.standardError.write(data)
    }
    // 2) Emit GitHub Actions notice command (parsed by runner when possible)
    if let data = ("::notice::" + formatted + "\n").data(using: .utf8) {
        FileHandle.standardOutput.write(data)
    }
    // 3) Keep activity/NSLog for local debugging and result bundles
    NSLog("%@", formatted)
    XCTContext.runActivity(named: formatted) { _ in }
}

/// Attaches text content to the current test with keepAlways lifetime so it's visible in CI artifacts.
@inline(__always)
func ciAttach(_ name: String, text: String) {
    XCTContext.runActivity(named: "CI_ATTACHMENT: \(name)") { activity in
        let attachment = XCTAttachment(string: text)
        attachment.lifetime = .keepAlways
        activity.add(attachment)
    }
}

/// Captures a screenshot and keeps it in artifacts; also logs a CI notice line
@inline(__always)
func ciScreenshot(_ name: String) {
    let shot = XCUIScreen.main.screenshot()
    let attachment = XCTAttachment(screenshot: shot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    ciLog("Screenshot: \(name)")
    XCTContext.runActivity(named: "CI_SCREENSHOT: \(name)") { activity in
        activity.add(attachment)
    }
}

/// Dumps the current UI hierarchy using debugDescription and attaches it
@inline(__always)
func ciDumpHierarchy(_ name: String, app: XCUIApplication = XCUIApplication()) {
    let dump = app.debugDescription
    ciAttach(name, text: dump)
    ciLog("Attached UI hierarchy: \(name)")
}