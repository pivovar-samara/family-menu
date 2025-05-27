//
//  CommonUnitTests.swift
//  FamilyMenuPlannerTests
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
    func testFormattedDoubleForUnits() {
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
}
