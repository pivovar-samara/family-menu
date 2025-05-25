//
//  CalendarHelper.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.12.24.
//

import Foundation

func localizedWeekdayNamesStartingFromMonday(locale: Locale = Locale(identifier: "en_US_POSIX")) -> [String] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = 2 // Monday

    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = locale

    let weekdays = formatter.weekdaySymbols
    let firstWeekdayIndex = calendar.firstWeekday - 1
    let reorderedWeekdays = Array((weekdays?[firstWeekdayIndex...] ?? []) + (weekdays?[..<firstWeekdayIndex] ?? []))
    return reorderedWeekdays
}

func startOfWeek(for date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> Date {
    var calendar = calendar
    calendar.firstWeekday = 2
    let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
    return calendar.date(from: components) ?? date
}

func formattedWeek(_ date: Date, calendar: Calendar = Calendar(identifier: .gregorian), locale: Locale = Locale(identifier: "en_US_POSIX")) -> String {
    let start = startOfWeek(for: date, calendar: calendar)
    let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start

    let formatterRight = DateFormatter()
    formatterRight.dateFormat = "d MMM"
    formatterRight.locale = locale
    formatterRight.calendar = calendar

    let formatterLeft = DateFormatter()
    formatterLeft.locale = locale
    formatterLeft.calendar = calendar
    if isSameMonths(for: start, and: end, calendar: calendar) {
        formatterLeft.dateFormat = "d"
    } else {
        formatterLeft.dateFormat = "d MMM"
    }
    return "\(formatterLeft.string(from: start)) - \(formatterRight.string(from: end))"
}

func isSameMonths(for date1: Date, and date2: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> Bool {
    let components1 = calendar.dateComponents([.month, .year], from: date1)
    let components2 = calendar.dateComponents([.month, .year], from: date2)
    return components1.month == components2.month && components1.year == components2.year
}
