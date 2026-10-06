//
//  WeekCalendarUnitTests.swift
//  FamilyMenuPlannerUnitTests
//
//  Verifies that week calculations are Monday-first and independent of the user's region,
//  and that week keys stored by older versions under en_US / ru_RU still resolve.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

/// Calendars as `Calendar.current` looked in each region before week calculations were unified.
private enum RegionCalendar {
    static let timeZone = TimeZone(identifier: "Europe/Berlin")!

    static func make(_ localeIdentifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: localeIdentifier)
        calendar.timeZone = timeZone
        return calendar
    }

    static var enUS: Calendar { make("en_US") }
    static var ruRU: Calendar { make("ru_RU") }
    static var all: [(name: String, calendar: Calendar)] { [("en_US", enUS), ("ru_RU", ruRU)] }
}

final class WeekCalendarUnitTests: XCTestCase {
    private let weekCalendar = CalendarHelper.weekCalendar(timeZone: RegionCalendar.timeZone)

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        weekCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    /// Every day from late 2024 through early 2028, covering years starting on every weekday
    /// that matters for week numbering (2025: Wed, 2026: Thu, 2027: Fri, 2028: Sat).
    private var sampleDays: [Date] {
        let start = date(2024, 12, 1)
        return (0..<(365 * 3 + 60)).map { weekCalendar.date(byAdding: .day, value: $0, to: start)! }
    }

    func testRegionCalendarsHaveDifferentWeekRules() {
        // Precondition for the tests below: these regions really disagree on week rules.
        XCTAssertEqual(RegionCalendar.enUS.firstWeekday, 1)
        XCTAssertEqual(RegionCalendar.enUS.minimumDaysInFirstWeek, 1)
        XCTAssertEqual(RegionCalendar.ruRU.firstWeekday, 2)
        XCTAssertEqual(RegionCalendar.ruRU.minimumDaysInFirstWeek, 4)
    }

    func testWeekCalendarIsMondayFirstISO() {
        XCTAssertEqual(CalendarHelper.weekCalendar.firstWeekday, 2)
        XCTAssertEqual(CalendarHelper.weekCalendar.minimumDaysInFirstWeek, 4)
        XCTAssertEqual(CalendarHelper.weekCalendar.timeZone, TimeZone.current)
    }

    func testStartOfWeekIsMondayContainingDateForEveryRegion() {
        for (name, regionCalendar) in RegionCalendar.all {
            for day in sampleDays {
                let start = CalendarHelper.startOfWeek(for: day, calendar: regionCalendar)
                XCTAssertEqual(regionCalendar.component(.weekday, from: start), 2, "\(name): \(day) should start on Monday")
                XCTAssertLessThanOrEqual(start, day, "\(name): \(day)")
                XCTAssertLessThan(day, regionCalendar.date(byAdding: .day, value: 7, to: start)!, "\(name): \(day)")
                XCTAssertEqual(start, CalendarHelper.startOfWeek(for: day, calendar: weekCalendar), "\(name): \(day)")
            }
        }
    }

    func testCurrentWeekOnSundayAndMondayInSundayFirstRegion() {
        // Tuesday Oct 6, 2026 previously resolved to the week of Sep 28 under en_US.
        XCTAssertEqual(CalendarHelper.startOfWeek(for: date(2026, 10, 6), calendar: weekCalendar), date(2026, 10, 5, hour: 0))
        // Sunday belongs to the week that started the previous Monday, not the next one.
        XCTAssertEqual(CalendarHelper.startOfWeek(for: date(2026, 10, 11), calendar: weekCalendar), date(2026, 10, 5, hour: 0))
        XCTAssertEqual(CalendarHelper.startOfWeek(for: date(2026, 10, 12), calendar: weekCalendar), date(2026, 10, 12, hour: 0))
    }

    func testDateForDayIndex() {
        let wednesday = date(2026, 10, 7)
        XCTAssertEqual(CalendarHelper.date(forDayIndex: 0, inWeekOf: wednesday, calendar: weekCalendar), date(2026, 10, 5, hour: 0))
        XCTAssertEqual(CalendarHelper.date(forDayIndex: 6, inWeekOf: wednesday, calendar: weekCalendar), date(2026, 10, 11, hour: 0))
    }

    func testStartOfWeekOffsetCrossesYearBoundary() {
        let start = CalendarHelper.startOfWeek(offset: 2, from: date(2026, 12, 23), calendar: weekCalendar)
        XCTAssertEqual(start, date(2027, 1, 4, hour: 0))
    }

    // MARK: - Week keys

    func testWeekKeyMatchesKeysStoredByRuRUVersions() {
        // ru_RU users stored keys using Calendar.current; those must resolve unchanged.
        for day in sampleDays {
            XCTAssertEqual(
                CalendarHelper.weekKey(for: day, calendar: weekCalendar),
                CalendarHelper.weekKey(for: day, calendar: RegionCalendar.ruRU),
                "\(day)"
            )
        }
    }

    func testWeekKeyIsIndependentOfRegionCalendarPassedForStartOfWeek() {
        for (name, regionCalendar) in RegionCalendar.all {
            for day in sampleDays {
                let start = CalendarHelper.startOfWeek(for: day, calendar: regionCalendar)
                XCTAssertEqual(
                    CalendarHelper.weekKey(for: start, calendar: weekCalendar),
                    CalendarHelper.weekKey(for: day, calendar: weekCalendar),
                    "\(name): \(day)"
                )
            }
        }
    }

    func testWeekKeyAtYearBoundaries() {
        XCTAssertEqual(CalendarHelper.weekKey(for: date(2026, 12, 28), calendar: weekCalendar), 202653)
        XCTAssertEqual(CalendarHelper.weekKey(for: date(2027, 1, 3), calendar: weekCalendar), 202653)
        XCTAssertEqual(CalendarHelper.weekKey(for: date(2027, 1, 4), calendar: weekCalendar), 202701)
        XCTAssertEqual(CalendarHelper.weekKey(for: date(2025, 12, 29), calendar: weekCalendar), 202601)
    }

    // MARK: - Legacy key conversion

    func testLegacyRuRUKeysMapToSameWeek() {
        let ruRU = RegionCalendar.ruRU
        for day in sampleDays {
            let legacyKey = CalendarHelper.weekKey(for: day, calendar: ruRU)
            let start = CalendarHelper.weekStart(forLegacyWeekKey: legacyKey, legacyCalendar: ruRU)
            XCTAssertEqual(start, CalendarHelper.startOfWeek(for: day, calendar: weekCalendar), "\(day)")
            XCTAssertEqual(start.map { CalendarHelper.weekKey(for: $0, calendar: weekCalendar) }, legacyKey, "\(day)")
        }
    }

    func testLegacyEnUSKeysMapToWeekOfTheirMonday() {
        let enUS = RegionCalendar.enUS
        for day in sampleDays where weekCalendar.component(.weekday, from: day) == 2 {
            // en_US stored the key of its Sunday-first week, which contains this Monday.
            let legacyKey = CalendarHelper.weekKey(for: day, calendar: enUS)
            let start = CalendarHelper.weekStart(forLegacyWeekKey: legacyKey, legacyCalendar: enUS)
            XCTAssertEqual(start, weekCalendar.startOfDay(for: day), "\(day)")
        }
    }

    func testLegacyEnUSKeysThatDifferFromISO() {
        let enUS = RegionCalendar.enUS
        // 2027 starts on Friday: en_US week 2 is ISO week 1.
        XCTAssertEqual(CalendarHelper.weekKey(for: date(2027, 1, 4), calendar: enUS), 202702)
        XCTAssertEqual(CalendarHelper.weekStart(forLegacyWeekKey: 202702, legacyCalendar: enUS), date(2027, 1, 4, hour: 0))
        // Late December: en_US already counts week 1 of the next year.
        XCTAssertEqual(CalendarHelper.weekKey(for: date(2026, 12, 28), calendar: enUS), 202701)
        XCTAssertEqual(CalendarHelper.weekStart(forLegacyWeekKey: 202701, legacyCalendar: enUS), date(2026, 12, 28, hour: 0))
    }

    func testInvalidLegacyKeys() {
        XCTAssertNil(CalendarHelper.weekStart(forLegacyWeekKey: 0, legacyCalendar: RegionCalendar.enUS))
        XCTAssertNil(CalendarHelper.weekStart(forLegacyWeekKey: 202600, legacyCalendar: RegionCalendar.ruRU))
    }
}

// MARK: - MenuViewModel

final class MenuViewModelWeekUnitTests: XCTestCase {
    private let weekCalendar = CalendarHelper.weekCalendar(timeZone: RegionCalendar.timeZone)

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: MenuViewModel.selectedWeekIndexKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: MenuViewModel.selectedWeekIndexKey)
        super.tearDown()
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        weekCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func makeViewModel(now: Date) -> MenuViewModel {
        MenuViewModel(menuService: MockMenuService(), calendar: weekCalendar, now: { now })
    }

    func testWeekOptionsStartOnMondayOfCurrentWeekForEveryWeekday() {
        let monday = date(2026, 10, 5, hour: 0)
        for offset in 0..<7 {
            let today = date(2026, 10, 5 + offset)
            let vm = makeViewModel(now: today)
            XCTAssertEqual(vm.weekOptions, [
                monday,
                date(2026, 10, 12, hour: 0),
                date(2026, 10, 19, hour: 0)
            ], "today: \(today)")
        }
    }

    @MainActor
    func testTodayIsNeverTreatedAsPastAndEarlierDaysAre() {
        for (today, todayIndex) in [(date(2026, 10, 5), 0), (date(2026, 10, 6), 1), (date(2026, 10, 11), 6), (date(2027, 1, 3), 6)] {
            let vm = makeViewModel(now: today)
            vm.updateSelectedWeekIndex(0)

            vm.prepareEditFor(day: vm.weekdays[todayIndex], mealType: "Breakfast", dishes: [])
            XCTAssertFalse(vm.showPastEditWarning, "today: \(today)")
            XCTAssertEqual(vm.selectedMealType, "Breakfast", "today: \(today)")

            if todayIndex > 0 {
                vm.selectedMealType = ""
                vm.prepareEditFor(day: vm.weekdays[todayIndex - 1], mealType: "Lunch", dishes: [])
                XCTAssertTrue(vm.showPastEditWarning, "today: \(today)")
                vm.cancelPendingEdit()
            }
        }
    }

    @MainActor
    func testFutureWeekDaysAreNotPast() {
        let vm = makeViewModel(now: date(2026, 10, 11))
        vm.updateSelectedWeekIndex(1)
        vm.prepareEditFor(day: vm.weekdays[0], mealType: "Dinner", dishes: [])
        XCTAssertFalse(vm.showPastEditWarning)
        XCTAssertEqual(vm.selectedMealType, "Dinner")
    }
}

// MARK: - MenuService

final class MenuServiceWeekUnitTests: XCTestCase {
    private var context: NSManagedObjectContext!
    private var factory: TestDataFactory!
    private let weekCalendar = CalendarHelper.weekCalendar(timeZone: RegionCalendar.timeZone)

    override func setUp() {
        super.setUp()
        context = TestCoreDataStack.shared.viewContext
        factory = TestDataFactory(context: context)
        factory.cleanUpTestData()
    }

    override func tearDown() {
        factory.cleanUpTestData()
        factory = nil
        context = nil
        super.tearDown()
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        weekCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func makeService(now: Date) -> MenuService {
        MenuService(context: context, calendar: weekCalendar, now: { now })
    }

    /// Inserts an entry the way older versions did: key from the region calendar, no `date`.
    @discardableResult
    private func insertLegacyEntry(day: String, weekDate: Date, legacyCalendar: Calendar, dish: Dish) -> Menu {
        let menu = Menu(context: context)
        menu.day = day
        menu.mealType = "Dinner"
        menu.mealTypeKey = "dinner"
        menu.calendarWeek = Int32(CalendarHelper.weekKey(for: weekDate, calendar: legacyCalendar))
        menu.addToDishes(dish)
        try? context.save()
        return menu
    }

    private func allMenus() -> NSFetchRequest<Menu> {
        Menu.fetchRequest()
    }

    private func dinnerDishes(_ menu: [DailyMenu], day: String) -> [String] {
        menu.first { $0.day == day }?.dailyMeals.first { $0.meal == "Dinner" }?.dishes.compactMap(\.name) ?? []
    }

    func testCurrentWeekResolvesOnSunday() throws {
        let dinner = factory.createMealType(name: "Dinner", sortOrder: 1)
        let dish = factory.createDish(name: "Soup", mealTypes: [dinner])
        let sunday = date(2026, 10, 11)
        let service = makeService(now: sunday)

        try service.replaceDishes(for: "Sunday", mealType: "Dinner", selectedWeekDate: date(2026, 10, 5, hour: 0), with: [dish])

        XCTAssertEqual(dinnerDishes(service.fetchMenu(for: 0), day: "Sunday"), ["Soup"])
        XCTAssertEqual(dinnerDishes(service.fetchMenu(for: 1), day: "Sunday"), [])
    }

    func testNewEntriesCarryDayDate() throws {
        let dinner = factory.createMealType(name: "Dinner", sortOrder: 1)
        let dish = factory.createDish(name: "Soup", mealTypes: [dinner])
        let service = makeService(now: date(2026, 10, 6))

        try service.replaceDishes(for: "Wednesday", mealType: "Dinner", selectedWeekDate: date(2026, 10, 5, hour: 0), with: [dish])

        let menus = try context.fetch(allMenus())
        XCTAssertEqual(menus.count, 1)
        XCTAssertEqual(menus.first?.calendarWeek, 202641)
        XCTAssertEqual(menus.first?.date, date(2026, 10, 7, hour: 0))
    }

    func testMigrationKeepsRuRUEntries() {
        let dinner = factory.createMealType(name: "Dinner", sortOrder: 1)
        let dish = factory.createDish(name: "Borscht", mealTypes: [dinner])
        let ruRU = RegionCalendar.ruRU
        let now = date(2026, 12, 30)
        // ru_RU weekOptions used Monday starts.
        let legacy = insertLegacyEntry(day: "Wednesday", weekDate: date(2026, 12, 28, hour: 0), legacyCalendar: ruRU, dish: dish)
        let keyBefore = legacy.calendarWeek

        let service = makeService(now: now)
        service.migrateLegacyWeekKeys(legacyCalendar: ruRU)

        XCTAssertEqual(legacy.calendarWeek, keyBefore)
        XCTAssertEqual(legacy.date, date(2026, 12, 30, hour: 0))
        XCTAssertEqual(dinnerDishes(service.fetchMenu(for: 0), day: "Wednesday"), ["Borscht"])
    }

    func testMigrationReencodesEnUSEntriesAcrossYearBoundary() {
        let dinner = factory.createMealType(name: "Dinner", sortOrder: 1)
        let current = factory.createDish(name: "Current", mealTypes: [dinner])
        let next = factory.createDish(name: "Next", mealTypes: [dinner])
        let enUS = RegionCalendar.enUS
        let now = date(2026, 12, 29)
        // en_US weekOptions used Sunday starts: Dec 27, 2026 (key 202701) and Jan 3, 2027 (key 202702).
        insertLegacyEntry(day: "Monday", weekDate: date(2026, 12, 27, hour: 0), legacyCalendar: enUS, dish: current)
        insertLegacyEntry(day: "Monday", weekDate: date(2027, 1, 3, hour: 0), legacyCalendar: enUS, dish: next)

        let service = makeService(now: now)
        XCTAssertEqual(dinnerDishes(service.fetchMenu(for: 0), day: "Monday"), [], "Legacy en_US keys don't match ISO keys before migration")

        service.migrateLegacyWeekKeys(legacyCalendar: enUS)

        XCTAssertEqual(dinnerDishes(service.fetchMenu(for: 0), day: "Monday"), ["Current"])
        XCTAssertEqual(dinnerDishes(service.fetchMenu(for: 1), day: "Monday"), ["Next"])

        // Running again (e.g. on another device) must not shift entries a second time.
        service.migrateLegacyWeekKeys(legacyCalendar: enUS)
        XCTAssertEqual(dinnerDishes(service.fetchMenu(for: 0), day: "Monday"), ["Current"])
        XCTAssertEqual(dinnerDishes(service.fetchMenu(for: 1), day: "Monday"), ["Next"])
    }

    func testLegacyEntryEditedBeforeMigrationIsStillMigrated() throws {
        let dinner = factory.createMealType(name: "Dinner", sortOrder: 1)
        let old = factory.createDish(name: "Old", mealTypes: [dinner])
        let edited = factory.createDish(name: "Edited", mealTypes: [dinner])
        let enUS = RegionCalendar.enUS
        let service = makeService(now: date(2027, 1, 5))
        // Imported after the screen appeared: en_US key 202702 shows up in ISO week 202702 (next week).
        insertLegacyEntry(day: "Monday", weekDate: date(2027, 1, 3, hour: 0), legacyCalendar: enUS, dish: old)
        XCTAssertEqual(dinnerDishes(service.fetchMenu(for: 1), day: "Monday"), ["Old"])

        try service.replaceDishes(for: "Monday", mealType: "Dinner", selectedWeekDate: date(2027, 1, 11, hour: 0), with: [edited])
        service.migrateLegacyWeekKeys(legacyCalendar: enUS)

        XCTAssertEqual(dinnerDishes(service.fetchMenu(for: 0), day: "Monday"), ["Edited"])
        XCTAssertEqual(dinnerDishes(service.fetchMenu(for: 1), day: "Monday"), [])
    }

    func testDuplicateCleanupUsesLogicalSlotNotDayStamp() throws {
        let dinner = factory.createMealType(name: "Dinner", sortOrder: 1)
        let monday = factory.createDish(name: "Monday Dish", mealTypes: [dinner])
        let tuesday = factory.createDish(name: "Tuesday Dish", mealTypes: [dinner])
        let duplicate = factory.createDish(name: "Duplicate", mealTypes: [dinner])
        let localTuesday = Calendar.current.startOfDay(for: date(2026, 10, 6))

        func insert(day: String, date stamp: Date, dish: Dish) {
            let menu = Menu(context: context)
            menu.day = day
            menu.mealType = "Dinner"
            menu.mealTypeKey = "dinner"
            menu.calendarWeek = 202641
            menu.date = stamp
            menu.addToDishes(dish)
        }
        // A Monday entry stamped by a device in another time zone can fall on the local Tuesday.
        insert(day: "Tuesday", date: localTuesday, dish: tuesday)
        insert(day: "Monday", date: localTuesday.addingTimeInterval(3600), dish: monday)
        // Same logical slot with different stamps is a real duplicate.
        insert(day: "Tuesday", date: localTuesday.addingTimeInterval(-3600), dish: duplicate)
        try context.save()

        PersistenceController.shared.cleanupDuplicateMenus(context: context)

        let service = makeService(now: date(2026, 10, 6))
        XCTAssertEqual(dinnerDishes(service.fetchMenu(for: 0), day: "Monday"), ["Monday Dish"])
        XCTAssertEqual(dinnerDishes(service.fetchMenu(for: 0), day: "Tuesday"), ["Duplicate", "Tuesday Dish"])
        XCTAssertEqual(try context.fetch(allMenus()).count, 2)
    }

    func testRemoveOldWeeksKeepsCurrentWeek() {
        let dinner = factory.createMealType(name: "Dinner", sortOrder: 1)
        let dish = factory.createDish(name: "Stew", mealTypes: [dinner])
        let now = date(2026, 10, 6)
        let service = makeService(now: now)

        try? service.replaceDishes(for: "Monday", mealType: "Dinner", selectedWeekDate: date(2026, 9, 28, hour: 0), with: [dish])
        try? service.replaceDishes(for: "Tuesday", mealType: "Dinner", selectedWeekDate: date(2026, 10, 5, hour: 0), with: [dish])

        service.removeOldWeeks()

        let remaining = (try? context.fetch(allMenus())) ?? []
        XCTAssertEqual(remaining.map(\.calendarWeek), [202641])
    }
}
