//
//  XCUIElement+Extensions.swift
//  FamilyMenuPlannerUITests
//
//  Created by Critical Test Review on 28.01.25.
//

import XCTest

// MARK: - XCUIElement Extensions for Test Helpers
extension XCUIElement {
    
    /// Clears existing text and enters new text in a text field
    func clearAndEnterText(_ text: String) {
        guard self.elementType == .textField || self.elementType == .secureTextField else {
            XCTFail("Trying to clear and enter text on a non-text field element")
            return
        }
        
        self.tap()
        
        // Select all text
        self.press(forDuration: 1.1)
        
        // Delete selected text
        if let existingText = self.value as? String, !existingText.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: existingText.count)
            self.typeText(deleteString)
        }
        
        // Enter new text
        self.typeText(text)
    }
    
    /// Scrolls to make this element visible on screen
    func scrollToElement() {
        guard self.exists else { return }
        
        // If element is already visible, no need to scroll
        if self.isHittable {
            return
        }
        
        // Try to find the nearest scrollable parent (List, ScrollView, etc.)
        var scrollView: XCUIElement?
        
        // Look for a table (List in SwiftUI becomes a table in UI tests)
        let tables = XCUIApplication().tables
        if tables.count > 0 {
            scrollView = tables.firstMatch
        }
        
        // If no table, look for scroll views
        if scrollView == nil {
            let scrollViews = XCUIApplication().scrollViews
            if scrollViews.count > 0 {
                scrollView = scrollViews.firstMatch
            }
        }
        
        // If we found a scrollable container, scroll to make this element visible
        if let scrollView = scrollView {
            // Get the frame of the element relative to the scroll view
            let elementFrame = self.frame
            let scrollFrame = scrollView.frame
            
            // If element is below the visible area, scroll down
            if elementFrame.minY > scrollFrame.maxY {
                // Scroll down by dragging from bottom to top
                let startPoint = CGPoint(x: scrollFrame.midX, y: scrollFrame.maxY - 50)
                let endPoint = CGPoint(x: scrollFrame.midX, y: scrollFrame.minY + 50)
                scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                    .withOffset(CGVector(dx: startPoint.x, dy: startPoint.y))
                    .press(forDuration: 0.1, thenDragTo: scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                        .withOffset(CGVector(dx: endPoint.x, dy: endPoint.y)))
            }
            // If element is above the visible area, scroll up
            else if elementFrame.maxY < scrollFrame.minY {
                // Scroll up by dragging from top to bottom
                let startPoint = CGPoint(x: scrollFrame.midX, y: scrollFrame.minY + 50)
                let endPoint = CGPoint(x: scrollFrame.midX, y: scrollFrame.maxY - 50)
                scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                    .withOffset(CGVector(dx: startPoint.x, dy: startPoint.y))
                    .press(forDuration: 0.1, thenDragTo: scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                        .withOffset(CGVector(dx: endPoint.x, dy: endPoint.y)))
            }
            
            // Wait a moment for the scroll to complete
            Thread.sleep(forTimeInterval: 0.5)
        } else {
            // Fallback: simple swipe up until element becomes hittable
            var attempts = 0
            let maxAttempts = 10
            
            while !self.isHittable && attempts < maxAttempts {
                XCUIApplication().swipeUp()
                Thread.sleep(forTimeInterval: 0.3)
                attempts += 1
            }
        }
    }
} 