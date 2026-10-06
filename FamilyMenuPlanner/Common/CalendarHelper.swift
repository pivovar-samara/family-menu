//
//  CalendarHelper.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.12.24.
//

import Foundation

final class CalendarHelper {
    private init() {}
    
    // MARK: - Weekday Names
    /// Returns localized weekday names starting from Monday.
    static func localizedWeekdayNamesStartingFromMonday(locale: Locale = Locale(identifier: "en_US_POSIX")) -> [String] {
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
    
    // MARK: - Week Calendar
    /// The single calendar used for all week math (week boundaries and stored week keys),
    /// independent of the user's region.
    /// ISO 8601 rules: weeks start on Monday and week 1 is the week containing January 4th.
    /// This is the numbering ru_RU (and other ISO regions) produced via `Calendar.current`,
    /// so menus stored with those week keys keep resolving.
    static var weekCalendar: Calendar {
        weekCalendar(timeZone: .current)
    }

    static func weekCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // Monday
        calendar.minimumDaysInFirstWeek = 4
        calendar.timeZone = timeZone
        return calendar
    }

    // MARK: - Week Calculations
    /// Returns the start of the week (Monday, midnight) for a given date.
    static func startOfWeek(for date: Date, calendar: Calendar = weekCalendar) -> Date {
        var calendar = calendar
        calendar.firstWeekday = 2
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }

    /// Returns the start of the week `offset` weeks away from the week containing `date`.
    static func startOfWeek(offset: Int, from date: Date, calendar: Calendar = weekCalendar) -> Date {
        let start = startOfWeek(for: date, calendar: calendar)
        return calendar.date(byAdding: .weekOfYear, value: offset, to: start) ?? start
    }

    /// Returns the date of the day at `dayIndex` (0 = Monday) in the week containing `date`.
    static func date(forDayIndex dayIndex: Int, inWeekOf date: Date, calendar: Calendar = weekCalendar) -> Date {
        let start = startOfWeek(for: date, calendar: calendar)
        return calendar.date(byAdding: .day, value: dayIndex, to: start) ?? start
    }

    /// Returns the persisted key of the week containing `date`: `yearForWeekOfYear * 100 + weekOfYear`.
    static func weekKey(for date: Date, calendar: Calendar = weekCalendar) -> Int {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return (components.yearForWeekOfYear ?? 0) * 100 + (components.weekOfYear ?? 0)
    }

    /// Converts a week key written with another calendar's week rules (e.g. a Sunday-first
    /// `Calendar.current`) into the start of the matching week in the week calendar.
    /// The legacy week is mapped to the week of its first Monday, which shares 6 of 7 days with it.
    static func weekStart(forLegacyWeekKey key: Int, legacyCalendar: Calendar) -> Date? {
        let year = key / 100
        let week = key % 100
        guard year > 0, week > 0,
              let legacyStart = legacyCalendar.date(from: DateComponents(weekOfYear: week, yearForWeekOfYear: year)) else {
            return nil
        }
        let daysToMonday = (2 - legacyCalendar.firstWeekday + 7) % 7
        guard let monday = legacyCalendar.date(byAdding: .day, value: daysToMonday, to: legacyStart) else { return nil }
        return startOfWeek(for: monday, calendar: weekCalendar(timeZone: legacyCalendar.timeZone))
    }

    /// Returns a localized formatted string for the week of a given date.
    /// Hides the year when both dates are in the same year, shows it when spanning years.
    static func formattedWeek(_ date: Date, calendar: Calendar = weekCalendar, locale: Locale = Locale.current) -> String {
        let start = startOfWeek(for: date, calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start

        let sameYear = calendar.component(.year, from: start) == calendar.component(.year, from: end)
        let sameMonth = sameYear && (calendar.component(.month, from: start) == calendar.component(.month, from: end))

        if sameYear {
            // Determine if the locale prefers day-first or month-first order
            let orderFormat = DateFormatter.dateFormat(fromTemplate: "dMMM", options: 0, locale: locale) ?? "d MMM"
            let dayIndex = orderFormat.firstIndex(of: "d")
            let monthIndex = orderFormat.firstIndex(of: "M")
            let isDayFirst = {
                guard let d = dayIndex, let m = monthIndex else { return true }
                return d < m
            }()

            let leftTemplateSameMonth = isDayFirst ? "d" : "MMMd"
            let rightTemplateSameMonth = isDayFirst ? "MMMd" : "d"
            let leftTemplateCrossMonth = "MMMd"
            let rightTemplateCrossMonth = "MMMd"

            let leftFormatter = DateFormatter()
            leftFormatter.locale = locale
            leftFormatter.calendar = calendar
            leftFormatter.dateFormat = DateFormatter.dateFormat(fromTemplate: sameMonth ? leftTemplateSameMonth : leftTemplateCrossMonth, options: 0, locale: locale)

            let rightFormatter = DateFormatter()
            rightFormatter.locale = locale
            rightFormatter.calendar = calendar
            rightFormatter.dateFormat = DateFormatter.dateFormat(fromTemplate: sameMonth ? rightTemplateSameMonth : rightTemplateCrossMonth, options: 0, locale: locale)

            return "\(leftFormatter.string(from: start)) – \(rightFormatter.string(from: end))"
        } else {
            // Different years: include year for clarity using DateIntervalFormatter
            let intervalFormatter = DateIntervalFormatter()
            intervalFormatter.calendar = calendar
            intervalFormatter.locale = locale
            intervalFormatter.timeZone = calendar.timeZone
            intervalFormatter.dateStyle = .medium
            intervalFormatter.timeStyle = .none
            return intervalFormatter.string(from: start, to: end)
        }
    }
    
    /// Returns true if two dates are in the same month and year.
    static func isSameMonths(for date1: Date, and date2: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> Bool {
        let components1 = calendar.dateComponents([.month, .year], from: date1)
        let components2 = calendar.dateComponents([.month, .year], from: date2)
        return components1.month == components2.month && components1.year == components2.year
    }
}
