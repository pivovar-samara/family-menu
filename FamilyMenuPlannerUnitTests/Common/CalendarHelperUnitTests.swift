//
//  CalendarHelperUnitTests.swift
//  FamilyMenuPlannerUnitTests
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
        let names = CalendarHelper.localizedWeekdayNamesStartingFromMonday(locale: locale)
        let expectedNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        XCTAssertEqual(names, expectedNames, "Should return weekday names starting from Monday in English")
    }
    
    func testLocalizedWeekdayNamesStartingFromMondayFrench() {
        let frenchLocale = Locale(identifier: "fr_FR")
        let names = CalendarHelper.localizedWeekdayNamesStartingFromMonday(locale: frenchLocale)
        XCTAssertEqual(names.count, 7, "Should return 7 weekday names")
        XCTAssertEqual(names.first, "lundi", "First weekday in French should be 'lundi'")
        XCTAssertEqual(names.last, "dimanche", "Last weekday in French should be 'dimanche'")
    }
    
    func testLocalizedWeekdayNamesStartingFromMondayGerman() {
        let germanLocale = Locale(identifier: "de_DE")
        let names = CalendarHelper.localizedWeekdayNamesStartingFromMonday(locale: germanLocale)
        XCTAssertEqual(names.count, 7, "Should return 7 weekday names")
        XCTAssertEqual(names.first, "Montag", "First weekday in German should be 'Montag'")
        XCTAssertEqual(names.last, "Sonntag", "Last weekday in German should be 'Sonntag'")
    }
    
    func testLocalizedWeekdayNamesDefaultLocale() {
        let names = CalendarHelper.localizedWeekdayNamesStartingFromMonday()
        XCTAssertEqual(names.count, 7, "Should return 7 weekday names with default locale")
        XCTAssertFalse(names.isEmpty, "Should not return empty array")
        XCTAssertFalse(names.contains(""), "Should not contain empty strings")
    }
    
    // MARK: - Test startOfWeek
    
    func testStartOfWeekSaturday() {
        // testDate is Saturday 2024-01-27 18:30:22
        let startOfWeekResult = CalendarHelper.startOfWeek(for: testDate, calendar: calendar)
        let expectedDate = Date(timeIntervalSince1970: 1705881600.0) // Monday, 2024-01-22 00:00:00 +0000
        XCTAssertEqual(startOfWeekResult, expectedDate, "Start of week for Saturday should be previous Monday at midnight")
    }
    
    func testStartOfWeekMonday() {
        let mondayDate = Date(timeIntervalSince1970: 1705881600.0 + 3600 * 10) // Monday 10:00 AM
        let startOfWeekResult = CalendarHelper.startOfWeek(for: mondayDate, calendar: calendar)
        let expectedDate = Date(timeIntervalSince1970: 1705881600.0) // Monday, 2024-01-22 00:00:00 +0000
        XCTAssertEqual(startOfWeekResult, expectedDate, "Start of week for Monday should be same Monday at midnight")
    }
    
    func testStartOfWeekSunday() {
        let sundayDate = Date(timeIntervalSince1970: 1705881600.0 + 6 * 24 * 3600) // Sunday of the same week
        let startOfWeekResult = CalendarHelper.startOfWeek(for: sundayDate, calendar: calendar)
        let expectedDate = Date(timeIntervalSince1970: 1705881600.0) // Monday, 2024-01-22 00:00:00 +0000
        XCTAssertEqual(startOfWeekResult, expectedDate, "Start of week for Sunday should be Monday of the same week")
    }
    
    func testStartOfWeekDifferentTimeZones() {
        var tokyoCalendar = Calendar(identifier: .gregorian)
        tokyoCalendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        
        let date = Date(timeIntervalSince1970: 1706375822.0) // 2024-01-27 in UTC
        let startTokyo = CalendarHelper.startOfWeek(for: date, calendar: tokyoCalendar)
        
        // Should handle timezone correctly
        XCTAssertNotNil(startTokyo, "Should handle Tokyo timezone")
        
        let hour = tokyoCalendar.component(.hour, from: startTokyo)
        XCTAssertEqual(hour, 0, "Start of week should be at midnight in local timezone")
    }
    
    func testStartOfWeekYearBoundary() {
        let newYearDate = Date(timeIntervalSince1970: 1704067200.0) // 2024-01-01 00:00:00 +0000 (Monday)
        let startOfWeekResult = CalendarHelper.startOfWeek(for: newYearDate, calendar: calendar)
        XCTAssertEqual(startOfWeekResult, newYearDate, "Start of week for New Year Monday should be same date")
        
        let lastDayOfYear = Date(timeIntervalSince1970: 1704067200.0 - 24 * 3600) // 2023-12-31 (Sunday)
        let startOfLastWeekResult = CalendarHelper.startOfWeek(for: lastDayOfYear, calendar: calendar)
        let expectedLastWeekStart = Date(timeIntervalSince1970: 1703462400.0) // 2023-12-25 00:00:00 +0000 (Monday)
        XCTAssertEqual(startOfLastWeekResult, expectedLastWeekStart, "Should handle year boundary correctly")
    }
    
    // MARK: - Test formattedWeek
    
    func testFormattedWeekSameMonth() {
        let formattedWeek = CalendarHelper.formattedWeek(testDate, calendar: calendar, locale: locale)
        let start = CalendarHelper.startOfWeek(for: testDate, calendar: calendar)
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
        XCTAssertEqual(formattedWeek, expected, "Should show single month for same-month range")
    }
    
    func testFormattedWeekSpanningMonths() {
        let dateSpanningMonths = Date(timeIntervalSince1970: 1706486400.0) // 2024-01-29 (Monday)
        let formattedWeek = CalendarHelper.formattedWeek(dateSpanningMonths, calendar: calendar, locale: locale)
        let start = CalendarHelper.startOfWeek(for: dateSpanningMonths, calendar: calendar)
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
        XCTAssertEqual(formattedWeek, expected, "Should format week spanning two months without year component")
    }
    
    func testFormattedWeekSpanningYears() {
        // A date whose week spans two different years (Mon Dec 30, 2024 – Sun Jan 5, 2025)
        let yearEndDate = calendar.date(from: DateComponents(year: 2024, month: 12, day: 31))!
        let formattedWeek = CalendarHelper.formattedWeek(yearEndDate, calendar: calendar, locale: locale)
        let start = CalendarHelper.startOfWeek(for: yearEndDate, calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 6, to: start)!
        let dif = DateIntervalFormatter()
        dif.calendar = calendar
        dif.locale = locale
        dif.timeZone = calendar.timeZone
        dif.dateStyle = .medium
        dif.timeStyle = .none
        let expected = dif.string(from: start, to: end)
        XCTAssertEqual(formattedWeek, expected, "Should include years when spanning different years")
    }
    
    func testFormattedWeekDifferentLocales() {
        let germanLocale = Locale(identifier: "de_DE")
        let formattedWeek = CalendarHelper.formattedWeek(testDate, calendar: calendar, locale: germanLocale)
        let start = CalendarHelper.startOfWeek(for: testDate, calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 6, to: start)!

        let orderFormat = DateFormatter.dateFormat(fromTemplate: "dMMM", options: 0, locale: germanLocale) ?? "d MMM"
        let dayIndex = orderFormat.firstIndex(of: "d")
        let monthIndex = orderFormat.firstIndex(of: "M")
        let isDayFirst: Bool = {
            guard let d = dayIndex, let m = monthIndex else { return true }
            return d < m
        }()

        let leftTemplate = isDayFirst ? "d" : "MMMd"
        let rightTemplate = isDayFirst ? "MMMd" : "d"

        let left = DateFormatter()
        left.calendar = calendar
        left.locale = germanLocale
        left.dateFormat = DateFormatter.dateFormat(fromTemplate: leftTemplate, options: 0, locale: germanLocale)
        let right = DateFormatter()
        right.calendar = calendar
        right.locale = germanLocale
        right.dateFormat = DateFormatter.dateFormat(fromTemplate: rightTemplate, options: 0, locale: germanLocale)
        let expected = "\(left.string(from: start)) – \(right.string(from: end))"
        XCTAssertEqual(formattedWeek, expected, "Should follow locale order (day-first vs month-first) without year for same-year range")
    }
    
    func testFormattedWeekLeapYear() {
        let leapYearDate = Calendar.current.date(from: DateComponents(year: 2024, month: 2, day: 29))!
        let formattedWeek = CalendarHelper.formattedWeek(leapYearDate, calendar: calendar, locale: locale)
        let start = CalendarHelper.startOfWeek(for: leapYearDate, calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 6, to: start)!
        let sameMonth = calendar.component(.month, from: start) == calendar.component(.month, from: end)
        let left = DateFormatter()
        left.calendar = calendar
        left.locale = locale
        left.dateFormat = DateFormatter.dateFormat(fromTemplate: "MMMd", options: 0, locale: locale)
        let right = DateFormatter()
        right.calendar = calendar
        right.locale = locale
        right.dateFormat = DateFormatter.dateFormat(fromTemplate: sameMonth ? "d" : "MMMd", options: 0, locale: locale)
        let expected = "\(left.string(from: start)) – \(right.string(from: end))"
        XCTAssertEqual(formattedWeek, expected, "Should format according to same-month vs cross-month rule without year when same year")
    }
    
    // MARK: - Test isSameMonths
    
    func testIsSameMonthsSameMonth() {
        let date1 = testDate
        let date2 = Date(timeInterval: 60 * 60 * 24, since: date1) // Next day
        let result = CalendarHelper.isSameMonths(for: date1, and: date2, calendar: calendar)
        XCTAssertTrue(result, "Dates in same month should return true")
    }
    
    func testIsSameMonthsDifferentMonths() {
        let date1 = testDate
        let date2 = Date(timeInterval: 60 * 60 * 24 * 30, since: date1) // ~30 days later
        let result = CalendarHelper.isSameMonths(for: date1, and: date2, calendar: calendar)
        XCTAssertFalse(result, "Dates in different months should return false")
    }
    
    func testIsSameMonthsSameMonthDifferentYears() {
        let date1 = Date(timeIntervalSince1970: 1703980800.0) // 2023-12-31
        let date2 = Date(timeIntervalSince1970: 1735516800.0) // 2024-12-31
        let result = CalendarHelper.isSameMonths(for: date1, and: date2, calendar: calendar)
        XCTAssertFalse(result, "Same month in different years should return false")
    }
    
    func testIsSameMonthsIdenticalDates() {
        let result = CalendarHelper.isSameMonths(for: testDate, and: testDate, calendar: calendar)
        XCTAssertTrue(result, "Identical dates should return true")
    }
    
    func testIsSameMonthsLastAndFirstDayOfSameMonth() {
        let firstDay = Date(timeIntervalSince1970: 1704067200.0) // 2024-01-01
        let lastDay = Date(timeIntervalSince1970: 1706659199.0) // 2024-01-31 23:59:59
        let result = CalendarHelper.isSameMonths(for: firstDay, and: lastDay, calendar: calendar)
        XCTAssertTrue(result, "First and last day of same month should return true")
    }
    
    func testIsSameMonthsDifferentTimeZones() {
        var tokyoCalendar = Calendar(identifier: .gregorian)
        tokyoCalendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        
        // Use dates that might be in different months depending on timezone
        let utcDate = Date(timeIntervalSince1970: 1704067200.0) // 2024-01-01 00:00:00 UTC
        let sameUtcDate = Date(timeIntervalSince1970: 1704067200.0)
        
        let result = CalendarHelper.isSameMonths(for: utcDate, and: sameUtcDate, calendar: tokyoCalendar)
        XCTAssertTrue(result, "Same UTC time should be same month even in different calendar timezone")
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testCalendarHelperWithDifferentCalendarSystems() {
        var buddhistCalendar = Calendar(identifier: .buddhist)
        buddhistCalendar.timeZone = timeZone
        
        let startDate = CalendarHelper.startOfWeek(for: testDate, calendar: buddhistCalendar)
        XCTAssertNotNil(startDate, "Should handle Buddhist calendar system")
        
        let formatted = CalendarHelper.formattedWeek(testDate, calendar: buddhistCalendar, locale: locale)
        XCTAssertFalse(formatted.isEmpty, "Should format dates with Buddhist calendar")
    }
    
    func testCalendarHelperWithExtremeDate() {
        let extremeDate = Date.distantPast
        let startDate = CalendarHelper.startOfWeek(for: extremeDate, calendar: calendar)
        XCTAssertNotNil(startDate, "Should handle extreme past date")
        
        let formatted = CalendarHelper.formattedWeek(extremeDate, calendar: calendar, locale: locale)
        XCTAssertFalse(formatted.isEmpty, "Should format extreme date")
    }
    
    func testLocalizedWeekdayNamesWithInvalidLocale() {
        // Test with a theoretically invalid locale identifier
        let invalidLocale = Locale(identifier: "xx_XX")
        let names = CalendarHelper.localizedWeekdayNamesStartingFromMonday(locale: invalidLocale)
        
        XCTAssertEqual(names.count, 7, "Should still return 7 weekday names")
        XCTAssertFalse(names.isEmpty, "Should not return empty array even with invalid locale")
    }
    
    // MARK: - Performance Tests
    
    func testCalendarHelperPerformance() {
        measure {
            for _ in 0..<1000 {
                let _ = CalendarHelper.startOfWeek(for: testDate, calendar: calendar)
                let _ = CalendarHelper.formattedWeek(testDate, calendar: calendar, locale: locale)
                let _ = CalendarHelper.isSameMonths(for: testDate, and: testDate, calendar: calendar)
            }
        }
    }
    
    func testLocalizedWeekdayNamesPerformance() {
        measure {
            for _ in 0..<100 {
                let _ = CalendarHelper.localizedWeekdayNamesStartingFromMonday(locale: locale)
            }
        }
    }
} 
