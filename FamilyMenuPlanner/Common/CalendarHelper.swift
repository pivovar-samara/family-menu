//
//  CalendarHelper.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.12.24.
//

import Foundation

func localizedWeekdayNamesStartingFromMonday() -> [String] {
    var calendar = Calendar.current
    calendar.firstWeekday = 2 // Set Monday as the first week day

    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale.current

    let weekdays = formatter.weekdaySymbols
    let firstWeekdayIndex = calendar.firstWeekday - 1
    let reorderedWeekdays = Array((weekdays?[firstWeekdayIndex...] ?? []) + (weekdays?[..<firstWeekdayIndex] ?? []))
    return reorderedWeekdays
}

func startOfWeek(for date: Date, timezone: TimeZone = .current) -> Date {
    var calendar = Calendar.current
    calendar.firstWeekday = 2
    calendar.timeZone = timezone
    let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
    return calendar.date(from: components) ?? date
}

func formattedWeek(_ date: Date) -> String {
    let start = startOfWeek(for: date)
    let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
    
    let formatterRight = DateFormatter()
    formatterRight.dateFormat = "d MMM"
    let formatterLeft = DateFormatter()
    if (isSameMonths(for: start, and: end)) {
        formatterLeft.dateFormat = "d"
    } else {
        formatterLeft.dateFormat = "d MMM"
    }
    return "\(formatterLeft.string(from: start)) - \(formatterRight.string(from: end))"
}

func isSameMonths(for date1: Date, and date2: Date) -> Bool {
    let calendar = Calendar.current
    let components1 = calendar.dateComponents([.month], from: date1)
    let components2 = calendar.dateComponents([.month], from: date2)
    return components1.month == components2.month
}
