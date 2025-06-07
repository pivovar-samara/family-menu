//
//  CalendarHelperUnitTests.swift
//  FamilyMenuPlannerTests
//
//  Created by Critical Test Review on 28.01.25.
//

import XCTest
@testable import FamilyMenuPlanner

class CalendarHelperUnitTests: XCTestCase {
    private let testDate = Date(timeIntervalSince1970: 1706375822.0) // 2024-01-27 18:30:22 +0000 (Saturday)
    private let timeZone = TimeZone(secondsFromGMT: 0)!
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal
    }
    private let locale = Locale(identifier: "en_US_POSIX")
    
    // MARK: - Test localizedWeekdayNamesStartingFromMonday
    
    func testLocalizedWeekdayNamesStartingFromMondayEnglish() {
        let names = localizedWeekdayNamesStartingFromMonday(locale: locale)
        let expectedNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        XCTAssertEqual(names, expectedNames, "Should return weekday names starting from Monday in English")
    }
    
    func testLocalizedWeekdayNamesStartingFromMondayFrench() {
        let frenchLocale = Locale(identifier: "fr_FR")
        let names = localizedWeekdayNamesStartingFromMonday(locale: frenchLocale)
        XCTAssertEqual(names.count, 7, "Should return 7 weekday names")
        XCTAssertEqual(names.first, "lundi", "First weekday in French should be 'lundi'")
        XCTAssertEqual(names.last, "dimanche", "Last weekday in French should be 'dimanche'")
    }
    
    func testLocalizedWeekdayNamesStartingFromMondayGerman() {
        let germanLocale = Locale(identifier: "de_DE")
        let names = localizedWeekdayNamesStartingFromMonday(locale: germanLocale)
        XCTAssertEqual(names.count, 7, "Should return 7 weekday names")
        XCTAssertEqual(names.first, "Montag", "First weekday in German should be 'Montag'")
        XCTAssertEqual(names.last, "Sonntag", "Last weekday in German should be 'Sonntag'")
    }
    
    func testLocalizedWeekdayNamesDefaultLocale() {
        let names = localizedWeekdayNamesStartingFromMonday()
        XCTAssertEqual(names.count, 7, "Should return 7 weekday names with default locale")
        XCTAssertFalse(names.isEmpty, "Should not return empty array")
        XCTAssertFalse(names.contains(""), "Should not contain empty strings")
    }
    
    // MARK: - Test startOfWeek
    
    func testStartOfWeekSaturday() {
        // testDate is Saturday 2024-01-27 18:30:22
        let startOfWeekResult = startOfWeek(for: testDate, calendar: calendar)
        let expectedDate = Date(timeIntervalSince1970: 1705881600.0) // Monday, 2024-01-22 00:00:00 +0000
        XCTAssertEqual(startOfWeekResult, expectedDate, "Start of week for Saturday should be previous Monday at midnight")
    }
    
    func testStartOfWeekMonday() {
        let mondayDate = Date(timeIntervalSince1970: 1705881600.0 + 3600 * 10) // Monday 10:00 AM
        let startOfWeekResult = startOfWeek(for: mondayDate, calendar: calendar)
        let expectedDate = Date(timeIntervalSince1970: 1705881600.0) // Monday, 2024-01-22 00:00:00 +0000
        XCTAssertEqual(startOfWeekResult, expectedDate, "Start of week for Monday should be same Monday at midnight")
    }
    
    func testStartOfWeekSunday() {
        let sundayDate = Date(timeIntervalSince1970: 1705881600.0 + 6 * 24 * 3600) // Sunday of the same week
        let startOfWeekResult = startOfWeek(for: sundayDate, calendar: calendar)
        let expectedDate = Date(timeIntervalSince1970: 1705881600.0) // Monday, 2024-01-22 00:00:00 +0000
        XCTAssertEqual(startOfWeekResult, expectedDate, "Start of week for Sunday should be Monday of the same week")
    }
    
    func testStartOfWeekDifferentTimeZones() {
        var tokyoCalendar = Calendar(identifier: .gregorian)
        tokyoCalendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        
        let date = Date(timeIntervalSince1970: 1706375822.0) // 2024-01-27 in UTC
        let startTokyo = startOfWeek(for: date, calendar: tokyoCalendar)
        
        // Should handle timezone correctly
        XCTAssertNotNil(startTokyo, "Should handle Tokyo timezone")
        
        let hour = tokyoCalendar.component(.hour, from: startTokyo)
        XCTAssertEqual(hour, 0, "Start of week should be at midnight in local timezone")
    }
    
    func testStartOfWeekYearBoundary() {
        let newYearDate = Date(timeIntervalSince1970: 1704067200.0) // 2024-01-01 00:00:00 +0000 (Monday)
        let startOfWeekResult = startOfWeek(for: newYearDate, calendar: calendar)
        XCTAssertEqual(startOfWeekResult, newYearDate, "Start of week for New Year Monday should be same date")
        
        let lastDayOfYear = Date(timeIntervalSince1970: 1704067200.0 - 24 * 3600) // 2023-12-31 (Sunday)
        let startOfLastWeekResult = startOfWeek(for: lastDayOfYear, calendar: calendar)
        let expectedLastWeekStart = Date(timeIntervalSince1970: 1703462400.0) // 2023-12-25 00:00:00 +0000 (Monday)
        XCTAssertEqual(startOfLastWeekResult, expectedLastWeekStart, "Should handle year boundary correctly")
    }
    
    // MARK: - Test formattedWeek
    
    func testFormattedWeekSameMonth() {
        let formattedWeek = formattedWeek(testDate, calendar: calendar, locale: locale)
        let expectedFormat = "22 - 28 Jan"
        XCTAssertEqual(formattedWeek, expectedFormat, "Should format week within same month correctly")
    }
    
    func testFormattedWeekSpanningMonths() {
        let dateSpanningMonths = Date(timeIntervalSince1970: 1706486400.0) // 2024-01-29 (Monday)
        let formattedWeek = formattedWeek(dateSpanningMonths, calendar: calendar, locale: locale)
        let expectedFormat = "29 Jan - 4 Feb"
        XCTAssertEqual(formattedWeek, expectedFormat, "Should format week spanning two months correctly")
    }
    
    func testFormattedWeekSpanningYears() {
        let yearEndDate = Date(timeIntervalSince1970: 1703980800.0) // 2023-12-31 (Sunday)
        let formattedWeek = formattedWeek(yearEndDate, calendar: calendar, locale: locale)
        let expectedFormat = "25 - 31 Dec" // Week starting 2023-12-25
        XCTAssertEqual(formattedWeek, expectedFormat, "Should format week at year end correctly")
    }
    
    func testFormattedWeekDifferentLocales() {
        let germanLocale = Locale(identifier: "de_DE")
        let formattedWeek = formattedWeek(testDate, calendar: calendar, locale: germanLocale)
        
        // German locale should use different month abbreviations
        XCTAssertTrue(formattedWeek.contains("Jan") || formattedWeek.contains("Jän"), "Should use German locale formatting")
        XCTAssertTrue(formattedWeek.contains(" - "), "Should contain date range separator")
        XCTAssertTrue(formattedWeek.contains("22") && formattedWeek.contains("28"), "Should contain correct dates")
    }
    
    func testFormattedWeekLeapYear() {
        let leapYearDate = Calendar.current.date(from: DateComponents(year: 2024, month: 2, day: 29))!
        let formattedWeek = formattedWeek(leapYearDate, calendar: calendar, locale: locale)
        
        XCTAssertFalse(formattedWeek.isEmpty, "Should handle leap year dates")
        XCTAssertTrue(formattedWeek.contains("Feb"), "Should contain February abbreviation")
    }
    
    // MARK: - Test isSameMonths
    
    func testIsSameMonthsSameMonth() {
        let date1 = testDate
        let date2 = Date(timeInterval: 60 * 60 * 24, since: date1) // Next day
        let result = isSameMonths(for: date1, and: date2, calendar: calendar)
        XCTAssertTrue(result, "Dates in same month should return true")
    }
    
    func testIsSameMonthsDifferentMonths() {
        let date1 = testDate
        let date2 = Date(timeInterval: 60 * 60 * 24 * 30, since: date1) // ~30 days later
        let result = isSameMonths(for: date1, and: date2, calendar: calendar)
        XCTAssertFalse(result, "Dates in different months should return false")
    }
    
    func testIsSameMonthsSameMonthDifferentYears() {
        let date1 = Date(timeIntervalSince1970: 1703980800.0) // 2023-12-31
        let date2 = Date(timeIntervalSince1970: 1735516800.0) // 2024-12-31
        let result = isSameMonths(for: date1, and: date2, calendar: calendar)
        XCTAssertFalse(result, "Same month in different years should return false")
    }
    
    func testIsSameMonthsIdenticalDates() {
        let result = isSameMonths(for: testDate, and: testDate, calendar: calendar)
        XCTAssertTrue(result, "Identical dates should return true")
    }
    
    func testIsSameMonthsLastAndFirstDayOfSameMonth() {
        let firstDay = Date(timeIntervalSince1970: 1704067200.0) // 2024-01-01
        let lastDay = Date(timeIntervalSince1970: 1706659199.0) // 2024-01-31 23:59:59
        let result = isSameMonths(for: firstDay, and: lastDay, calendar: calendar)
        XCTAssertTrue(result, "First and last day of same month should return true")
    }
    
    func testIsSameMonthsDifferentTimeZones() {
        var tokyoCalendar = Calendar(identifier: .gregorian)
        tokyoCalendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        
        // Use dates that might be in different months depending on timezone
        let utcDate = Date(timeIntervalSince1970: 1704067200.0) // 2024-01-01 00:00:00 UTC
        let sameUtcDate = Date(timeIntervalSince1970: 1704067200.0)
        
        let result = isSameMonths(for: utcDate, and: sameUtcDate, calendar: tokyoCalendar)
        XCTAssertTrue(result, "Same UTC time should be same month even in different calendar timezone")
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testCalendarHelperWithDifferentCalendarSystems() {
        var buddhistCalendar = Calendar(identifier: .buddhist)
        buddhistCalendar.timeZone = timeZone
        
        let startDate = startOfWeek(for: testDate, calendar: buddhistCalendar)
        XCTAssertNotNil(startDate, "Should handle Buddhist calendar system")
        
        let formatted = formattedWeek(testDate, calendar: buddhistCalendar, locale: locale)
        XCTAssertFalse(formatted.isEmpty, "Should format dates with Buddhist calendar")
    }
    
    func testCalendarHelperWithExtremeDate() {
        let extremeDate = Date.distantPast
        let startDate = startOfWeek(for: extremeDate, calendar: calendar)
        XCTAssertNotNil(startDate, "Should handle extreme past date")
        
        let formatted = formattedWeek(extremeDate, calendar: calendar, locale: locale)
        XCTAssertFalse(formatted.isEmpty, "Should format extreme date")
    }
    
    func testLocalizedWeekdayNamesWithInvalidLocale() {
        // Test with a theoretically invalid locale identifier
        let invalidLocale = Locale(identifier: "xx_XX")
        let names = localizedWeekdayNamesStartingFromMonday(locale: invalidLocale)
        
        XCTAssertEqual(names.count, 7, "Should still return 7 weekday names")
        XCTAssertFalse(names.isEmpty, "Should not return empty array even with invalid locale")
    }
    
    // MARK: - Performance Tests
    
    func testCalendarHelperPerformance() {
        measure {
            for _ in 0..<1000 {
                let _ = startOfWeek(for: testDate, calendar: calendar)
                let _ = formattedWeek(testDate, calendar: calendar, locale: locale)
                let _ = isSameMonths(for: testDate, and: testDate, calendar: calendar)
            }
        }
    }
    
    func testLocalizedWeekdayNamesPerformance() {
        measure {
            for _ in 0..<100 {
                let _ = localizedWeekdayNamesStartingFromMonday(locale: locale)
            }
        }
    }
} 