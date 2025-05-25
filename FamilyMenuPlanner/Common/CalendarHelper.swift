//
//  CalendarHelper.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.12.24.
//

import Foundation

func localizedWeekdayNamesStartingFromMonday() -> [String] {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return (2...8).map { weekday in
        formatter.weekdaySymbols[(weekday - 1) % 7]
    }
}

func startOfWeek(for date: Date) -> Date {
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    calendar.firstWeekday = 2 // Monday
    return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
}

func formattedWeek(_ date: Date) -> String {
    let calendar = Calendar(identifier: .iso8601)
    let start = startOfWeek(for: date)
    let end = calendar.date(byAdding: .day, value: 6, to: start)!
    let formatter = DateFormatter()
    formatter.dateFormat = "d"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    let startDay = formatter.string(from: start)
    let endDay = formatter.string(from: end)
    formatter.dateFormat = "MMM"
    let month = formatter.string(from: end)
    return "\(startDay) - \(endDay) \(month)"
}

func isSameMonths(for date1: Date, and date2: Date) -> Bool {
    let calendar = Calendar(identifier: .iso8601)
    let comp1 = calendar.dateComponents([.year, .month], from: date1)
    let comp2 = calendar.dateComponents([.year, .month], from: date2)
    return comp1.year == comp2.year && comp1.month == comp2.month
}
