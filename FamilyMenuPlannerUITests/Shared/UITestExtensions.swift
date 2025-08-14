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
    if ProcessInfo.processInfo.environment["CI"] == "true" {
        // Ensure visibility in GitHub Actions logs
        XCTExpectFailure(formatted, strict: false) {
            XCTFail(formatted, file: file, line: line)
        }
    } else {
        NSLog("%@", formatted)
        XCTContext.runActivity(named: formatted) { _ in }
    }
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