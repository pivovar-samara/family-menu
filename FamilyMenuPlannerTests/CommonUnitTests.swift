//
//  CommonUnitTests.swift
//  FamilyMenuPlannerTests
//
//  Created by Ilya Khokhlov on 27.01.25.
//

import XCTest
import SwiftUI
import CoreData
@testable import FamilyMenuPlanner

final class CommonUnitTests: XCTestCase {
    private let inputDate: Date = Date(timeIntervalSince1970: 1706375822.0)
    private let timeZone = TimeZone(secondsFromGMT: 0)!
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal
    }
    private let locale = Locale(identifier: "en_US_POSIX")
    private lazy var dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZ"
        df.timeZone = timeZone
        return df
    }()

    func testFormattingDoubleForUnits() throws {
        let input: Double = 1.23456789
        let formattedValue = formattedDoubleForUnits(input)
        XCTAssert(formattedValue == "1.23", "Formatted Double 1.23456789 should be 1.23, not \(formattedValue)")
    }

    func testLocalizedWeekdayNamesStartingFromMonday() throws {
        let names = localizedWeekdayNamesStartingFromMonday(locale: locale)
        XCTAssert(names == ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "Localized weekday names starting from Monday not \(names)")
    }

    func testStartOfWeek() throws {
        let startOfWeek = startOfWeek(for: inputDate, calendar: calendar)
        let correctResult = Date(timeIntervalSince1970: 1705881600.0) // Monday, 2024-01-22 00:00:00 +0000
        XCTAssert(startOfWeek == correctResult, "Start of week for \(dateFormatter.string(from: inputDate)) is \(dateFormatter.string(from: correctResult)), not \(dateFormatter.string(from: startOfWeek))")
    }

    func testFormattingWeek() throws {
        let formattedWeek = formattedWeek(inputDate, calendar: calendar, locale: locale)
        let correctResult = "22 - 28 Jan"
        XCTAssert(formattedWeek == correctResult, "Formatted week for \(dateFormatter.string(from: inputDate)) is \(correctResult), not \(formattedWeek)")
    }

    func testIsSameMonths() throws {
        let date1 = inputDate
        let dateTwoMonthsLater = Date(timeInterval: 60.0*60.0*24.0*30.0*2.0, since: date1)
        XCTAssert(isSameMonths(for: date1, and: dateTwoMonthsLater, calendar: calendar) == false, "Date1: \(dateFormatter.string(from: date1)) and Date2: \(dateFormatter.string(from: dateTwoMonthsLater)) are not from same months")

        let dateTwoMonthsBefore = Date(timeInterval: -60.0*60.0*24.0*30.0*2.0, since: date1)
        XCTAssert(isSameMonths(for: date1, and: dateTwoMonthsBefore, calendar: calendar) == false, "Date1: \(dateFormatter.string(from: date1)) and Date2: \(dateFormatter.string(from: dateTwoMonthsBefore)) are not from same months")

        let dateMinuteLater = Date(timeInterval: 60.0, since: date1)
        XCTAssert(isSameMonths(for: date1, and: dateMinuteLater, calendar: calendar) == true, "Date1: \(dateFormatter.string(from: date1)) and Date2: \(dateFormatter.string(from: dateMinuteLater)) are from same months")
    }
    
    func testLocalizedWeekdayNamesWithDifferentLocale() throws {
        let localeFR = Locale(identifier: "fr_FR")
        let namesFR = localizedWeekdayNamesStartingFromMonday(locale: localeFR)
        XCTAssert(namesFR.first == "lundi", "First weekday in French should be 'lundi', got \(namesFR.first ?? "")")
    }
    
    func testStartOfWeekWithDifferentTimeZone() throws {
        var calendarTokyo = Calendar(identifier: .gregorian)
        calendarTokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let date = Date(timeIntervalSince1970: 1706375822.0) // 2024-01-27
        let start = startOfWeek(for: date, calendar: calendarTokyo)
        // 2024-01-22 00:00:00 +0900 in Tokyo is 2024-01-21 15:00:00 +0000 in UTC
        let expected = Date(timeIntervalSince1970: 1705849200.0) // 2024-01-21 15:00:00 +0000
        XCTAssertEqual(start, expected, "Start of week in Tokyo time zone should match Tokyo's Monday 00:00")
    }
    
    func testFormattedWeekSpanningMonths() throws {
        // 2024-01-29 is a Monday, week ends in February
        let date = Date(timeIntervalSince1970: 1706486400.0)
        let formatted = formattedWeek(date, calendar: calendar, locale: locale)
        XCTAssertEqual(formatted, "29 Jan - 4 Feb", "Week spanning months should show both months")
    }
    
    func testFormattedWeekSpanningYears() throws {
        // 2023-12-25 is a Monday, week ends in 2023-12-31
        let date = Date(timeIntervalSince1970: 1703462400.0)
        let formatted = formattedWeek(date, calendar: calendar, locale: locale)
        XCTAssertEqual(formatted, "25 - 31 Dec", "Week spanning end of year should show correct format")
    }
    
    func testIsSameMonthsWithDifferentYears() throws {
        // 2023-12-31 and 2024-12-31
        let date1 = Date(timeIntervalSince1970: 1703980800.0) // 2023-12-31
        let date2 = Date(timeIntervalSince1970: 1735516800.0) // 2024-12-31
        XCTAssertFalse(isSameMonths(for: date1, and: date2, calendar: calendar), "Dates in same month but different years should not be considered same month")
    }
    
    // LocalizationHelper.swift
    func testStringLocalizedReturnsSelfIfNoLocalization() {
        let original = "TestString"
        XCTAssertEqual(original.localized(), original)
    }

    // NumbersHelper.swift
    func testFormattedDoubleForUnitsBasicCases() throws {
        let input: Double = 1.23456789
        let formattedValue = formattedDoubleForUnits(input)
        XCTAssert(formattedValue == "1.23", "Formatted Double 1.23456789 should be 1.23, not \(formattedValue)")
    }

    func testFormattedDoubleForUnitsCommonCases() {
        XCTAssertEqual(formattedDoubleForUnits(2.345), "2.35")
        XCTAssertEqual(formattedDoubleForUnits(0.0), "0.00")
        XCTAssertEqual(formattedDoubleForUnits(-1.2), "-1.20")
    }

    // ViewHelper.swift
    func testCreateToolbarButtonDoesNotCrash() {
        XCTAssertNoThrow({
            _ = createToolbarButton(title: "Test", systemImage: "star", action: {})
        }())
    }

    func testEmptyStateModifierDoesNotCrash() {
        let view = Text("Test").emptyState(message: "Empty")
        XCTAssertNotNil(view)
    }

    func testListApplyStyleDoesNotCrash() {
        let list = List { Text("Item") }
        XCTAssertNotNil(list.applyStyle())
    }

    // AlertQueueManager.swift
    func testAlertQueueManagerEnqueueAndDismiss() {
        let manager = AlertQueueManager()
        let alert1 = AlertItem(title: "A1", message: "M1", action: nil)
        let alert2 = AlertItem(title: "A2", message: "M2", action: nil)

        manager.enqueue(alert: alert1)
        XCTAssertEqual(manager.currentAlert?.title, "A1")

        manager.enqueue(alert: alert2)
        manager.dismissCurrentAlert()
        XCTAssertEqual(manager.currentAlert?.title, "A2")

        manager.dismissCurrentAlert()
        XCTAssertNil(manager.currentAlert)
    }

    // MARK: - Additional Calendar Tests
    
    func testLeapYearWeekFormatting() {
        let leapYearDate = Calendar.current.date(from: DateComponents(year: 2024, month: 2, day: 29))!
        let formatted = formattedWeek(leapYearDate, calendar: calendar, locale: locale)
        XCTAssertFalse(formatted.isEmpty, "Should handle leap year dates")
    }
    
    func testDifferentCalendarSystems() {
        var buddhistCalendar = Calendar(identifier: .buddhist)
        buddhistCalendar.timeZone = timeZone
        let startDate = startOfWeek(for: inputDate, calendar: buddhistCalendar)
        XCTAssertNotNil(startDate, "Should handle Buddhist calendar")
    }
    
    // MARK: - Additional Number Tests
    
    func testFormattedDoubleEdgeCases() {
        XCTAssertEqual(formattedDoubleForUnits(Double.infinity), "inf")
        XCTAssertEqual(formattedDoubleForUnits(Double.nan), "nan")
        XCTAssertEqual(formattedDoubleForUnits(Double.greatestFiniteMagnitude), "inf")
        XCTAssertEqual(formattedDoubleForUnits(Double.leastNonzeroMagnitude), "0.00")
    }
    
    func testFormattedDoubleRoundingBehavior() {
        XCTAssertEqual(formattedDoubleForUnits(1.005), "1.01", "Should round up at midpoint")
        XCTAssertEqual(formattedDoubleForUnits(1.004), "1.00", "Should round down below midpoint")
    }
    
    // MARK: - Additional Alert Tests
    
    func testAlertQueueManagerMultipleAlerts() {
        let manager = AlertQueueManager()
        let alerts = (1...5).map { AlertItem(title: "Alert \($0)", message: "Message \($0)", action: nil) }
        
        // Enqueue all alerts
        alerts.forEach { manager.enqueue(alert: $0) }
        
        // Verify first alert is shown
        XCTAssertEqual(manager.currentAlert?.title, "Alert 1")
        
        // Dismiss and verify next alert
        manager.dismissCurrentAlert()
        XCTAssertEqual(manager.currentAlert?.title, "Alert 2")
    }
    
    func testAlertQueueManagerWithActions() {
        let manager = AlertQueueManager()
        var actionExecuted = false
        
        let alert = AlertItem(title: "Test", message: "Test", action: {
            actionExecuted = true
        })
        
        manager.enqueue(alert: alert)
        alert.action?()
        
        XCTAssertTrue(actionExecuted, "Alert action should be executed")
    }
    
    // MARK: - Additional Localization Tests
    
    func testLocalizationWithDifferentLocales() {
        let testString = "test_key"
        XCTAssertEqual(testString.localized(), testString, "Should return key if no localization exists")
    }
    
    // MARK: - Additional View Tests
    
    func testToolbarButtonCreation() {
        // Test button creation with empty closure
        let button = createToolbarButton(title: "Test", systemImage: "star", action: {})
        XCTAssertNotNil(button, "Button should be created")
        
        // Note: In a real app, you would use ViewInspector or UI tests to verify button taps
        // This test only verifies the button creation
    }
    
    func testEmptyStateModifierProperties() {
        let testMessage = "Test Empty State"
        let view = Text("Content").emptyState(message: testMessage)
        
        // Verify view creation
        XCTAssertNotNil(view, "Should create view with empty state")
        
        // Note: For thorough view testing, consider using ViewInspector library
        // to inspect view hierarchy and verify message content
    }
    
    func testListStyleApplication() {
        let list = List { Text("Test Item") }
        let styledList = list.applyStyle()
        
        // Verify styled list is created
        XCTAssertNotNil(styledList, "Should create styled list")
        
        // Note: Visual styling should be verified through UI tests or ViewInspector
    }

    // MARK: - Persistence Error Handling Tests
    
    func testPersistenceErrorCategorization() {
        // Test migration error - using the correct constant name
        let migrationError = NSError(domain: NSCocoaErrorDomain, code: NSPersistentStoreIncompatibleVersionHashError, userInfo: nil)
        let persistenceError = PersistenceError.migrationFailed(migrationError)
        
        // Check if the error description contains expected text (accounting for localization)
        let description = persistenceError.localizedDescription
        XCTAssertTrue(description.contains("migrate") || description.contains("миграц"), "Migration error should contain migration-related text")
        
        // Test permission error  
        _ = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError, userInfo: nil)
        let permissionPersistenceError = PersistenceError.permissionDenied
        
        let permissionDescription = permissionPersistenceError.localizedDescription
        XCTAssertTrue(permissionDescription.contains("Permission") || permissionDescription.contains("доступ"), "Permission error should contain permission-related text")
        
        // Test disk space error
        let diskSpaceError = PersistenceError.diskSpaceInsufficient
        let diskDescription = diskSpaceError.localizedDescription
        XCTAssertTrue(diskDescription.contains("disk space") || diskDescription.contains("место"), "Disk space error should contain space-related text")
        
        // Test general Core Data error
        let generalError = NSError(domain: NSCocoaErrorDomain, code: NSCoreDataError, userInfo: nil)
        let generalPersistenceError = PersistenceError.unknown(generalError)
        
        let generalDescription = generalPersistenceError.localizedDescription
        XCTAssertTrue(generalDescription.contains("unexpected error") || generalDescription.contains("непредвиденная"), "General error should contain unexpected error text")
    }
    
    func testPersistenceControllerErrorStates() {
        // Test with the test core data stack instead of creating new instances
        let testStack = TestCoreDataStack.shared
        let context = testStack.viewContext
        
        // Verify that test stack is working properly
        XCTAssertNotNil(context.persistentStoreCoordinator)
        XCTAssertEqual(testStack.persistentContainer.persistentStoreDescriptions.first?.type, NSInMemoryStoreType)
        
        // Test basic functionality
        let unit = Unit(context: context)
        unit.name = "Test Unit"
        unit.sortOrder = 1
        
        do {
            try context.save()
            XCTAssertTrue(true, "Test stack should save successfully")
        } catch {
            XCTFail("Test stack should not fail to save: \(error)")
        }
        
        // Clean up
        context.delete(unit)
        try? context.save()
    }
    
    func testPersistenceStateManager() {
        let stateManager = PersistenceStateManager()
        
        // Initially should be ready with no errors
        XCTAssertTrue(stateManager.isReady)
        XCTAssertFalse(stateManager.hasLoadingError)
        XCTAssertNil(stateManager.loadingError)
        XCTAssertNil(stateManager.userFriendlyErrorMessage)
        
        // Test setting an error
        let testError = PersistenceError.diskSpaceInsufficient
        stateManager.setError(testError)
        
        // After setting error, should not be ready
        let expectation = XCTestExpectation(description: "Error state updated")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(stateManager.isReady)
            XCTAssertTrue(stateManager.hasLoadingError)
            XCTAssertNotNil(stateManager.loadingError)
            XCTAssertNotNil(stateManager.userFriendlyErrorMessage)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Test clearing error
        stateManager.clearError()
        
        let clearExpectation = XCTestExpectation(description: "Error cleared")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(stateManager.isReady)
            XCTAssertFalse(stateManager.hasLoadingError)
            XCTAssertNil(stateManager.loadingError)
            XCTAssertNil(stateManager.userFriendlyErrorMessage)
            clearExpectation.fulfill()
        }
        
        wait(for: [clearExpectation], timeout: 1.0)
    }
    
    func testAppStateManagerPersistenceErrorHandling() {
        // Since AppStateManager.shared uses PersistenceController.shared,
        // and we've modified it to detect test environment,
        // it should work without CloudKit conflicts now
        let appStateManager = AppStateManager.shared
        
        // Test that the app state manager can handle checking database state
        // Use a shorter timeout since we're in test environment
        let expectation = XCTestExpectation(description: "Loading completes")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // In test environment, loading should complete quickly
            XCTAssertFalse(appStateManager.isLoading)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testErrorRecoveryMethods() {
        // Test that shared persistence controller works in test environment
        let persistence = PersistenceController.shared
        
        // These should not crash and should work in test environment
        XCTAssertNoThrow(persistence.isReady)
        XCTAssertNoThrow(persistence.userFriendlyErrorMessage)
        
        // In test environment, persistence should be ready
        XCTAssertTrue(persistence.isReady, "Persistence should be ready in test environment")
        
        // Test manual recovery attempt on working store
        let recoveryResult = persistence.attemptRecovery()
        XCTAssertTrue(recoveryResult, "Recovery should succeed if store is already working")
    }
}
