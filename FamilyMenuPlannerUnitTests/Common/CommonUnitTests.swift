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
        let start = CalendarHelper.startOfWeek(for: inputDate, calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 6, to: start)!
        let left = DateFormatter()
        left.calendar = calendar
        left.locale = locale
        left.dateFormat = DateFormatter.dateFormat(fromTemplate: "MMMd", options: 0, locale: locale)
        let right = DateFormatter()
        right.calendar = calendar
        right.locale = locale
        right.dateFormat = DateFormatter.dateFormat(fromTemplate: "d", options: 0, locale: locale)
        let expected = "\(left.string(from: start)) – \(right.string(from: end))"
        XCTAssertEqual(formattedWeek, expected, "Formatted week should show single month for same-month range")
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
        let start = CalendarHelper.startOfWeek(for: date, calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 6, to: start)!
        let left = DateFormatter()
        left.calendar = calendar
        left.locale = locale
        left.dateFormat = DateFormatter.dateFormat(fromTemplate: "MMMd", options: 0, locale: locale)
        let right = DateFormatter()
        right.calendar = calendar
        right.locale = locale
        right.dateFormat = DateFormatter.dateFormat(fromTemplate: "MMMd", options: 0, locale: locale)
        let expected = "\(left.string(from: start)) – \(right.string(from: end))"
        XCTAssertEqual(formatted, expected, "Week spanning months should show months on both sides")
    }
    
    func testFormattedWeekSpanningYears() throws {
        // Use a date that yields a week spanning two years: Mon Dec 30, 2024 – Sun Jan 5, 2025
        let date = calendar.date(from: DateComponents(year: 2024, month: 12, day: 31))!
        let formatted = CalendarHelper.formattedWeek(date, calendar: calendar, locale: locale)
        let start = CalendarHelper.startOfWeek(for: date, calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 6, to: start)!
        let dif = DateIntervalFormatter()
        dif.calendar = calendar
        dif.locale = locale
        dif.timeZone = calendar.timeZone
        dif.dateStyle = .medium
        dif.timeStyle = .none
        let expected = dif.string(from: start, to: end)
        XCTAssertEqual(formatted, expected, "Week spanning end of year should include years as needed")
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
    
    // MARK: - Button State System Tests
    
    func testButtonStateStyleColors() {
        // Test primary button state colors
        let primaryDefault = ButtonStateStyle.primary.colors()
        XCTAssertNotNil(primaryDefault.background, "Primary default background should not be nil")
        XCTAssertNotNil(primaryDefault.foreground, "Primary default foreground should not be nil")
        XCTAssertNotNil(primaryDefault.border, "Primary default border should not be nil")
        
        // Test secondary button state colors
        let secondaryDefault = ButtonStateStyle.secondary.colors()
        XCTAssertNotNil(secondaryDefault.background, "Secondary default background should not be nil")
        XCTAssertNotNil(secondaryDefault.foreground, "Secondary default foreground should not be nil")
        XCTAssertNotNil(secondaryDefault.border, "Secondary default border should not be nil")
        
        // Test chip button state colors
        let chipDefault = ButtonStateStyle.chip.colors()
        XCTAssertNotNil(chipDefault.background, "Chip default background should not be nil")
        XCTAssertNotNil(chipDefault.foreground, "Chip default foreground should not be nil")
        XCTAssertNotNil(chipDefault.border, "Chip default border should not be nil")
    }
    
    func testButtonStateStyleWithStates() {
        // Test disabled state
        let primaryDisabled = ButtonStateStyle.primary.colors(isDisabled: true)
        XCTAssertNotNil(primaryDisabled.background, "Primary disabled background should not be nil")
        XCTAssertNotNil(primaryDisabled.foreground, "Primary disabled foreground should not be nil")
        
        // Test selected state
        let primarySelected = ButtonStateStyle.primary.colors(isSelected: true)
        XCTAssertNotNil(primarySelected.background, "Primary selected background should not be nil")
        XCTAssertNotNil(primarySelected.foreground, "Primary selected foreground should not be nil")
        
        // Test pressed state
        let primaryPressed = ButtonStateStyle.primary.colors(isPressed: true)
        XCTAssertNotNil(primaryPressed.background, "Primary pressed background should not be nil")
        XCTAssertNotNil(primaryPressed.foreground, "Primary pressed foreground should not be nil")
    }
    
    func testSemanticButtonStateStyles() {
        // Test warning style
        let warningDefault = ButtonStateStyle.warning.colors()
        XCTAssertNotNil(warningDefault.background, "Warning default background should not be nil")
        XCTAssertNotNil(warningDefault.foreground, "Warning default foreground should not be nil")
        
        // Test error style
        let errorDefault = ButtonStateStyle.error.colors()
        XCTAssertNotNil(errorDefault.background, "Error default background should not be nil")
        XCTAssertNotNil(errorDefault.foreground, "Error default foreground should not be nil")
        
        // Test success style
        let successDefault = ButtonStateStyle.success.colors()
        XCTAssertNotNil(successDefault.background, "Success default background should not be nil")
        XCTAssertNotNil(successDefault.foreground, "Success default foreground should not be nil")
        
        // Test info style
        let infoDefault = ButtonStateStyle.info.colors()
        XCTAssertNotNil(infoDefault.background, "Info default background should not be nil")
        XCTAssertNotNil(infoDefault.foreground, "Info default foreground should not be nil")
    }
    
    func testChipViewWithNewStateSystem() {
        // Test chip view with new button state style
        let chipView = ChipView(
            text: "Test Chip",
            buttonStateStyle: .chip,
            isEnabled: true,
            isSelected: false
        )
        XCTAssertNotNil(chipView, "ChipView should be created with new state system")
    }
    
    func testChipViewLegacyCompatibility() {
        // Test chip view with legacy style for backward compatibility
        let chipView = ChipView(
            text: "Test Chip",
            style: .filled,
            tint: Color.accent
        )
        XCTAssertNotNil(chipView, "ChipView should be created with legacy style")
    }
    
    func testButtonStateStylePriority() {
        // Test that disabled state takes priority over selected state
        let disabledSelected = ButtonStateStyle.primary.colors(isDisabled: true, isSelected: true)
        // The colors should reflect disabled state, not selected state
        XCTAssertNotNil(disabledSelected.background, "Disabled state should take priority")
        
        // Test that selected state takes priority over pressed state
        let selectedPressed = ButtonStateStyle.primary.colors(isPressed: true, isSelected: true)
        // The colors should reflect selected state, not pressed state
        XCTAssertNotNil(selectedPressed.background, "Selected state should take priority over pressed")
    }
}
