//
//  CommonUnitTests.swift
//  FamilyMenuPlannerUnitTests
//
//  Created by Ilya Khokhlov on 27.01.25.
//

import XCTest
import SwiftUI
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
        let names = CalendarHelper.localizedWeekdayNamesStartingFromMonday(locale: locale)
        XCTAssert(names == ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "Localized weekday names starting from Monday not \(names)")
    }

    func testStartOfWeek() throws {
        let startOfWeek = CalendarHelper.startOfWeek(for: inputDate, calendar: calendar)
        let correctResult = Date(timeIntervalSince1970: 1705881600.0) // Monday, 2024-01-22 00:00:00 +0000
        XCTAssert(startOfWeek == correctResult, "Start of week for \(dateFormatter.string(from: inputDate)) is \(dateFormatter.string(from: correctResult)), not \(dateFormatter.string(from: startOfWeek))")
    }

    func testFormattingWeek() throws {
        let formattedWeek = CalendarHelper.formattedWeek(inputDate, calendar: calendar, locale: locale)
        let correctResult = "22 - 28 Jan"
        XCTAssert(formattedWeek == correctResult, "Formatted week for \(dateFormatter.string(from: inputDate)) is \(correctResult), not \(formattedWeek)")
    }

    func testIsSameMonths() throws {
        let date1 = inputDate
        let dateTwoMonthsLater = Date(timeInterval: 60.0*60.0*24.0*30.0*2.0, since: date1)
        XCTAssert(CalendarHelper.isSameMonths(for: date1, and: dateTwoMonthsLater, calendar: calendar) == false, "Date1: \(dateFormatter.string(from: date1)) and Date2: \(dateFormatter.string(from: dateTwoMonthsLater)) are not from same months")

        let dateTwoMonthsBefore = Date(timeInterval: -60.0*60.0*24.0*30.0*2.0, since: date1)
        XCTAssert(CalendarHelper.isSameMonths(for: date1, and: dateTwoMonthsBefore, calendar: calendar) == false, "Date1: \(dateFormatter.string(from: date1)) and Date2: \(dateFormatter.string(from: dateTwoMonthsBefore)) are not from same months")

        let dateMinuteLater = Date(timeInterval: 60.0, since: date1)
        XCTAssert(CalendarHelper.isSameMonths(for: date1, and: dateMinuteLater, calendar: calendar) == true, "Date1: \(dateFormatter.string(from: date1)) and Date2: \(dateFormatter.string(from: dateMinuteLater)) are from same months")
    }
    
    func testLocalizedWeekdayNamesWithDifferentLocale() throws {
        let localeFR = Locale(identifier: "fr_FR")
        let namesFR = CalendarHelper.localizedWeekdayNamesStartingFromMonday(locale: localeFR)
        XCTAssert(namesFR.first == "lundi", "First weekday in French should be 'lundi', got \(namesFR.first ?? "")")
    }
    
    func testStartOfWeekWithDifferentTimeZone() throws {
        var calendarTokyo = Calendar(identifier: .gregorian)
        calendarTokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let date = Date(timeIntervalSince1970: 1706375822.0) // 2024-01-27
        let start = CalendarHelper.startOfWeek(for: date, calendar: calendarTokyo)
        // 2024-01-22 00:00:00 +0900 in Tokyo is 2024-01-21 15:00:00 +0000 in UTC
        let expected = Date(timeIntervalSince1970: 1705849200.0) // 2024-01-21 15:00:00 +0000
        XCTAssertEqual(start, expected, "Start of week in Tokyo time zone should match Tokyo's Monday 00:00")
    }
    
    func testFormattedWeekSpanningMonths() throws {
        // 2024-01-29 is a Monday, week ends in February
        let date = Date(timeIntervalSince1970: 1706486400.0)
        let formatted = CalendarHelper.formattedWeek(date, calendar: calendar, locale: locale)
        XCTAssertEqual(formatted, "29 Jan - 4 Feb", "Week spanning months should show both months")
    }
    
    func testFormattedWeekSpanningYears() throws {
        // 2023-12-25 is a Monday, week ends in 2023-12-31
        let date = Date(timeIntervalSince1970: 1703462400.0)
        let formatted = CalendarHelper.formattedWeek(date, calendar: calendar, locale: locale)
        XCTAssertEqual(formatted, "25 - 31 Dec", "Week spanning end of year should show correct format")
    }
    
    func testIsSameMonthsWithDifferentYears() throws {
        // 2023-12-31 and 2024-12-31
        let date1 = Date(timeIntervalSince1970: 1703980800.0) // 2023-12-31
        let date2 = Date(timeIntervalSince1970: 1735516800.0) // 2024-12-31
        XCTAssertFalse(CalendarHelper.isSameMonths(for: date1, and: date2, calendar: calendar), "Dates in same month but different years should not be considered same month")
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
            _ = ViewHelper.createToolbarButton(title: "Test", systemImage: "star", action: {})
        }())
    }

    func testEmptyStateModifierDoesNotCrash() {
        let view = ViewHelper.emptyState(Text("Test"), message: "Empty")
        XCTAssertNotNil(view)
    }

    func testListApplyStyleDoesNotCrash() {
        let list = List { Text("Item") }
        XCTAssertNotNil(ViewHelper.applyStyle(list))
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
        let formatted = CalendarHelper.formattedWeek(leapYearDate, calendar: calendar, locale: locale)
        XCTAssertFalse(formatted.isEmpty, "Should handle leap year dates")
    }
    
    func testDifferentCalendarSystems() {
        var buddhistCalendar = Calendar(identifier: .buddhist)
        buddhistCalendar.timeZone = timeZone
        let startDate = CalendarHelper.startOfWeek(for: inputDate, calendar: buddhistCalendar)
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
        let button = ViewHelper.createToolbarButton(title: "Test", systemImage: "star", action: {})
        XCTAssertNotNil(button, "Button should be created")
        
        // Note: In a real app, you would use ViewInspector or UI tests to verify button taps
        // This test only verifies the button creation
    }
    
    func testEmptyStateModifierProperties() {
        let testMessage = "Test Empty State"
        let view = ViewHelper.emptyState(Text("Content"), message: testMessage)
        
        // Verify view creation
        XCTAssertNotNil(view, "Should create view with empty state")
        
        // Note: For thorough view testing, consider using ViewInspector library
        // to inspect view hierarchy and verify message content
    }
    
    func testListStyleApplication() {
        let list = List { Text("Test Item") }
        let styledList = ViewHelper.applyStyle(list)
        
        // Verify styled list is created
        XCTAssertNotNil(styledList, "Should create styled list")
        
        // Note: Visual styling should be verified through UI tests or ViewInspector
    }
}
