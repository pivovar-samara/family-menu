//
//  XCUIElement+Extensions.swift
//  FamilyMenuPlannerUITests
//
//  Created by Critical Test Review on 28.01.25.
//

import XCTest

// MARK: - Fast waiting

/// Polling interval for the waits below. XCTest's own `waitForExistence` and `XCTNSPredicateExpectation`
/// evaluate their condition about once a second, which adds ~1s to every wait even when the element is already there.
private let fastWaitPollInterval: TimeInterval = 0.1

/// Checks `condition` immediately, then polls it until it is true or `timeout` elapses.
@discardableResult
func pollUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
    if condition() { return true }
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(fastWaitPollInterval))
        if condition() { return true }
    }
    return false
}

extension XCUIElement {
    
    /// Fast replacement for `waitForExistence(timeout:)`: returns as soon as the element exists.
    @discardableResult
    func waitToExist(timeout: TimeInterval = 5.0) -> Bool {
        pollUntil(timeout: timeout) { exists }
    }
    
    /// Waits until the element no longer exists.
    @discardableResult
    func waitToDisappear(timeout: TimeInterval = 5.0) -> Bool {
        pollUntil(timeout: timeout) { !exists }
    }
    
    /// Fast replacement for waiting on an `XCTNSPredicateExpectation` with this element as the object.
    @discardableResult
    func waitUntil(_ predicate: NSPredicate, timeout: TimeInterval) -> Bool {
        pollUntil(timeout: timeout) { predicate.evaluate(with: self) }
    }
}

// MARK: - XCUIElement Extensions for Test Helpers
extension XCUIElement {
    
    /// Clears existing text and enters new text in a text field or text view
    func clearAndEnterText(_ text: String) {
        guard self.elementType == .textField || self.elementType == .secureTextField || self.elementType == .textView else {
            XCTFail("Trying to clear and enter text on a non-text input element (elementType: \(self.elementType))")
            return
        }
        
        // Ensure the element is focused first
        self.tap()
        
        // Wait for keyboard to appear and element to be ready for input
        let keyboard = XCUIApplication().keyboards.firstMatch
        _ = keyboard.waitToExist(timeout: 3)
        
        // Prefer fast deletion via repeated delete key simulation to avoid selection UI/animations
        if let existingText = self.value as? String, !existingText.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: existingText.count)
            self.typeText(deleteString)
        }
        
        // Enter new text (allow empty text for clearing fields)
        self.typeText(text)
    }
    
    /// Clears text field content using multiple fallback strategies
    func clearTextWithFallback() {
        guard self.elementType == .textField || self.elementType == .secureTextField || self.elementType == .textView else {
            XCTFail("Trying to clear text on a non-text input element (elementType: \(self.elementType))")
            return
        }
        
        // First, ensure the element is focused
        self.tap()
        
        // Wait for keyboard to appear and element to be ready for input
        let keyboard = XCUIApplication().keyboards.firstMatch
        _ = keyboard.waitToExist(timeout: 3)
        
        // Check if there's any actual user-entered text to clear
        // Note: placeholder text (like "Enter product name") is not user-entered text
        if let currentValue = self.value as? String, !currentValue.isEmpty {
            // Check if this is placeholder text by comparing with placeholderValue
            let placeholderValue = self.placeholderValue ?? ""
            if currentValue == placeholderValue {
                // This is placeholder text, not user-entered text, so we don't need to clear it
                // Just ensure the field is focused and ready for input
                return
            }
            
            // This is actual user-entered text, so clear it
            // Try the built-in clearText method first
            self.clearText()
            
            // Wait for the text field to become empty
            let isFieldEmpty = waitUntil(NSPredicate(format: "value == '' OR value == %@", placeholderValue), timeout: 1.0)
            
            // If clearing didn't work, try alternative approaches
            if !isFieldEmpty {
                // Avoid selection UI as it can hang; just send delete keys again
                let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
                self.typeText(deleteString)
            }
        }
        
        // Verify the field is either empty or showing placeholder text
        let placeholderValue = self.placeholderValue ?? ""
        let finalCheck = waitUntil(NSPredicate(format: "value == '' OR value == %@", placeholderValue, NSNull()), timeout: 2.0)
        
        if !finalCheck {
            XCTFail("Failed to clear text field after multiple attempts")
        }
    }
    
    /// Waits for element to become hittable with specified timeout
    @discardableResult
    func waitForHittable(timeout: TimeInterval = 5.0) -> Bool {
        pollUntil(timeout: timeout) { exists && isHittable }
    }
    
    /// Waits for element to exist and become hittable, then scrolls to it if needed
    @discardableResult
    func waitAndScrollToElement(timeout: TimeInterval = 10.0) -> Bool {
        // First wait for existence
        guard self.waitToExist(timeout: timeout) else {
            return false
        }
        
        // If already hittable, we're done
        if self.isHittable {
            return true
        }
        
        // Try scrolling to make it visible
        return scrollToElementWithWaiting()
    }
    
    /// Scrolls to make this element visible on screen using proper waiting mechanisms
    private func scrollToElementWithWaiting() -> Bool {
        guard self.exists else { return false }
        
        // If element is already hittable, no need to scroll
        if self.isHittable {
            return true
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
            return performScrollToElement(in: scrollView)
        } else {
            return performFallbackScrolling()
        }
    }
    
    /// Performs scrolling within a specific scroll view container
    private func performScrollToElement(in scrollView: XCUIElement) -> Bool {
        let maxScrollAttempts = 10
        var attempts = 0
        
        while !self.isHittable && attempts < maxScrollAttempts {
            let elementFrame = self.frame
            let scrollFrame = scrollView.frame
            
            // If element is below the visible area, scroll down
            if elementFrame.minY > scrollFrame.maxY {
                let startPoint = CGPoint(x: scrollFrame.midX, y: scrollFrame.maxY - 50)
                let endPoint = CGPoint(x: scrollFrame.midX, y: scrollFrame.minY + 50)
                scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                    .withOffset(CGVector(dx: startPoint.x, dy: startPoint.y))
                    .press(forDuration: 0.1, thenDragTo: scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                        .withOffset(CGVector(dx: endPoint.x, dy: endPoint.y)))
            }
            // If element is above the visible area, scroll up
            else if elementFrame.maxY < scrollFrame.minY {
                let startPoint = CGPoint(x: scrollFrame.midX, y: scrollFrame.minY + 50)
                let endPoint = CGPoint(x: scrollFrame.midX, y: scrollFrame.maxY - 50)
                scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                    .withOffset(CGVector(dx: startPoint.x, dy: startPoint.y))
                    .press(forDuration: 0.1, thenDragTo: scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                        .withOffset(CGVector(dx: endPoint.x, dy: endPoint.y)))
            } else {
                // Element is in view but not hittable, try gentle scroll within the scrollView
                let startPoint = CGPoint(x: scrollFrame.midX, y: scrollFrame.maxY - 50)
                let endPoint = CGPoint(x: scrollFrame.midX, y: scrollFrame.minY + 50)
                scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                    .withOffset(CGVector(dx: startPoint.x, dy: startPoint.y))
                    .press(forDuration: 0.1, thenDragTo: scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                        .withOffset(CGVector(dx: endPoint.x, dy: endPoint.y)))
            }
            
            // Wait for scroll animation to complete using XCTWaiter
            waitForScrollCompletion()
            attempts += 1
        }
        
        return self.isHittable
    }
    
    /// Performs fallback scrolling when no scroll container is found
    private func performFallbackScrolling() -> Bool {
        let maxAttempts = 10
        var attempts = 0
        
        while !self.isHittable && attempts < maxAttempts {
            XCUIApplication().swipeUp()
            waitForScrollCompletion()
            attempts += 1
        }
        
        return self.isHittable
    }
    
    /// Waits for scroll animation to complete using XCTWaiter
    private func waitForScrollCompletion() {
        let scrollWaitExpectation = XCTestExpectation(description: "Wait for scroll animation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            scrollWaitExpectation.fulfill()
        }
        _ = XCTWaiter.wait(for: [scrollWaitExpectation], timeout: 1.0)
    }
}

// MARK: - XCUIApplication Extensions for Better Waiting
extension XCUIApplication {

    /// Finds a toolbar button by accessibility identifier or label.
    /// Not scoped to `navigationBars`: on wide iPhone layouts (e.g. iPhone Duo on iOS 27) toolbar items
    /// are rendered in a floating toolbar outside the navigation bar.
    func toolbarButton(_ identifierOrLabel: String) -> XCUIElement {
        buttons.matching(NSPredicate(format: "identifier == %@ OR label == %@", identifierOrLabel, identifierOrLabel)).firstMatch
    }

    /// Finds a main tab button by its identifier (`tab_menu`, `tab_products`, `tab_dishes`).
    /// Not scoped to `tabBars`: on wide iPhone layouts the tab bar is a side rail that is not exposed as a TabBar.
    func tabButton(_ identifier: String) -> XCUIElement {
        buttons.matching(identifier: identifier).firstMatch
    }

    /// Returns the search field, revealing it first when search is collapsed into a toolbar "Search" button
    /// (wide iPhone layouts on iOS 27).
    func revealedSearchField(timeout: TimeInterval = 3.0) -> XCUIElement {
        let searchField = searchFields.firstMatch
        if searchField.waitToExist(timeout: timeout) {
            return searchField
        }
        let searchButton = buttons.matching(NSPredicate(format: "label == %@ OR identifier == %@", "Search", "Search")).firstMatch
        if searchButton.exists && searchButton.isHittable {
            searchButton.tap()
            _ = searchField.waitToExist(timeout: timeout)
        }
        return searchField
    }

    /// Waits for an element to appear and become interactable
    @discardableResult
    func waitForElementToAppear(_ element: XCUIElement, timeout: TimeInterval = 5.0) -> Bool {
        return element.waitToExist(timeout: timeout) && element.waitForHittable(timeout: 1.0)
    }
    
    /// Waits for multiple elements to exist
    @discardableResult
    func waitForElements(_ elements: [XCUIElement], timeout: TimeInterval = 5.0) -> Bool {
        pollUntil(timeout: timeout) { elements.allSatisfy { $0.exists } }
    }
} 
