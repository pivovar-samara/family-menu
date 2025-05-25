//
//  CommonUnitTests.swift
//  FamilyMenuPlannerTests
//
//  Created by Ilya Khokhlov on 27.01.25.
//

import XCTest
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
}
