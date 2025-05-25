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
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZ"
        df.timeZone = TimeZone(secondsFromGMT: 0)
        return df
    }()
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testFormattingDoubleForUnits() throws {
        let input: Double = 1.23456789
        let formattedValue = formattedDoubleForUnits(input)
        
        XCTAssert(formattedValue == "1.23", "Formatted Double 1.23456789 should be 1.23, not \(formattedValue)")
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }
    
    func testLocalizedWeekdayNamesStartingFromMonday() throws {
        let names = localizedWeekdayNamesStartingFromMonday()
        
        XCTAssert(names == ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], "Localized weekday names starting from Monday not \(names)")
    }
    
    func testStartOfWeek() throws {
        let startOfWeek = startOfWeek(for: inputDate)
        
        let correctResult = Date(timeIntervalSince1970: 1705881600.0)
        
        XCTAssert(startOfWeek == correctResult, "Start of week for \(dateFormatter.string(from: inputDate)) is \(dateFormatter.string(from: correctResult)), not \(startOfWeek)")
    }
    
    func testFormattingWeek() throws {
        let formattedWeek = formattedWeek(inputDate)
        
        let correctResult = "22 - 28 Jan"
        
        XCTAssert(formattedWeek == correctResult, "Formatted week for \(dateFormatter.string(from: inputDate)) is \(correctResult), not \(formattedWeek)")
    }
    
    func testIsSameMonths() throws {
        let date1 = inputDate
        let dateTwoMonthsLater = Date(timeInterval: 60.0*60.0*24.0*30.0*2.0, since: date1)
        
        XCTAssert(isSameMonths(for: date1, and: dateTwoMonthsLater) == false, "Date1: \(dateFormatter.string(from: date1)) and Date2: \(dateFormatter.string(from: dateTwoMonthsLater)) are not from same months")
        
        let dateTwoMonthsBefore = Date(timeInterval: -60.0*60.0*24.0*30.0*2.0, since: date1)
        
        XCTAssert(isSameMonths(for: date1, and: dateTwoMonthsBefore) == false, "Date1: \(dateFormatter.string(from: date1)) and Date2: \(dateFormatter.string(from: dateTwoMonthsBefore)) are not from same months")
        
        let dateMinuteLater = Date(timeInterval: 60.0, since: date1)
        
        XCTAssert(isSameMonths(for: date1, and: dateMinuteLater) == true, "Date1: \(dateFormatter.string(from: date1)) and Date2: \(dateFormatter.string(from: dateMinuteLater)) are from same months")
    }
}
