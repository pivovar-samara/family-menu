//
//  MenuService.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 14.01.25.
//

import CoreData

protocol MenuServiceProtocol {
    func fetchMenu(for weekIndex: Int) -> [DailyMenu]
    func generateMenu(for weekDate: Date)
    func removeOldWeeks()
    func replaceDishes(for day: String, mealType: String, selectedWeekDate: Date, with newDishes: [Dish]) throws
    func clearMealType(for day: String, selectedWeekDate: Date, mealType: String?) throws
}

extension MenuService: MenuServiceProtocol {}

class MenuService {
    private let context: NSManagedObjectContext
    private let calendar: Calendar
    private let now: () -> Date

    init(context: NSManagedObjectContext, calendar: Calendar = CalendarHelper.weekCalendar, now: @escaping () -> Date = Date.init) {
        self.context = context
        self.calendar = calendar
        self.now = now
    }

    func fetchMenu(for weekIndex: Int) -> [DailyMenu] {
        let selectedWeekDate = CalendarHelper.startOfWeek(offset: weekIndex, from: now(), calendar: calendar)
        let encodedWeek = encodeWeek(for: selectedWeekDate)

        do {
            let fetchRequest: NSFetchRequest<Menu> = Menu.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "calendarWeek == %d", encodedWeek)
            
            // Configure batch fetching for menu entries
            CoreDataFetchHelper.configureForSmallList(fetchRequest)
            
            let menuEntries = try context.fetch(fetchRequest)

            var initializedMenu: [DailyMenu] = []
            let weekdays = CalendarHelper.localizedWeekdayNamesStartingFromMonday()
            
            let mealTypeFetchRequest = MealType.fetchRequest()
            mealTypeFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MealType.sortOrder, ascending: true)]
            
            // Meal types are typically small datasets, use smaller batch size
            CoreDataFetchHelper.configureForSmallList(mealTypeFetchRequest)
            
            let mealTypes = try context.fetch(mealTypeFetchRequest)
            // Ensure unique meal types in case CloudKit temporarily duplicated them
            var uniqueMealTypes: [MealType] = []
            var seenKeys: Set<String> = []
            for mt in mealTypes {
                let key = (mt.key?.isEmpty == false ? mt.key! : (mt.name ?? "").lowercased())
                if !key.isEmpty && !seenKeys.contains(key) {
                    seenKeys.insert(key)
                    uniqueMealTypes.append(mt)
                }
            }

            for day in weekdays {
                var dailyMeals: [DailyMeal] = []
                for mealType in uniqueMealTypes {
                    // Match by normalized keys to avoid localized name drift
                    let mtName = (mealType.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let mtKey = !(mealType.key?.isEmpty ?? true) ? mealType.key! : mtName.lowercased()
                    let matches = menuEntries.filter {
                        guard $0.day == day else { return false }
                        let entryKey = ($0.mealTypeKey?.isEmpty == false) ? $0.mealTypeKey! : ($0.mealType ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        return entryKey == mtKey
                    }
                    var dishes: [Dish] = []
                    for entry in matches {
                        if let ds = entry.dishes?.allObjects as? [Dish] {
                            dishes.append(contentsOf: ds)
                        }
                    }
                    // Deduplicate dishes by objectID to avoid repeats across merged entries
                    let uniqueByID: [NSManagedObjectID: Dish] = dishes.reduce(into: [:]) { dict, dish in
                        dict[dish.objectID] = dish
                    }
                    let merged = Array(uniqueByID.values)
                    let sorted = merged.sorted { ($0.name ?? "") < ($1.name ?? "") }
                    dailyMeals.append(DailyMeal(meal: mealType.name ?? "", dishes: sorted))
                }
                initializedMenu.append(DailyMenu(day: day, dailyMeals: dailyMeals))
            }

            return initializedMenu
        } catch {
            AppLogger.error("Error loading menu for the selected week", error: error, category: AppLogger.service)
            AnalyticsManager.shared.trackError(error, domain: "Menu", category: "Error loading menu for the selected week", properties: [AnalyticsPropertyKey.week_index: weekIndex])
            return []
        }
    }

    func generateMenu(for weekDate: Date) {
        do {
            let dishFetchRequest = Dish.fetchRequest()
            
            // Configure batch fetching for dishes
            CoreDataFetchHelper.configure(dishFetchRequest, batchSize: CoreDataFetchHelper.standardBatchSize)
            
            let dishes = try context.fetch(dishFetchRequest)
            guard !dishes.isEmpty else {
                AppLogger.info("No dishes available to generate a menu.", category: AppLogger.service)
                return
            }
            
            let weekdays = CalendarHelper.localizedWeekdayNamesStartingFromMonday()
            
            let mealTypesFetchRequest = MealType.fetchRequest()
            mealTypesFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MealType.sortOrder, ascending: true)]
            
            // Meal types are typically small datasets, use smaller batch size
            CoreDataFetchHelper.configureForSmallList(mealTypesFetchRequest)
            
            let mealTypes = try context.fetch(mealTypesFetchRequest)
            
            let encodedWeek = encodeWeek(for: weekDate)

            let fetchRequest: NSFetchRequest<Menu> = Menu.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "calendarWeek == %d", encodedWeek)
            
            // Configure batch fetching for existing menu entries
            CoreDataFetchHelper.configureForSmallList(fetchRequest)

            let existingEntries = try context.fetch(fetchRequest)
            for entry in existingEntries {
                context.delete(entry)
            }

            for (dayIndex, day) in weekdays.enumerated() {
                for mealType in mealTypes {
                    let dishesForMealType = dishes.filter { dish in
                        guard let mealTypes = dish.mealTypes as? Set<MealType> else { return false }
                        return mealTypes.contains(mealType)
                    }

                    let newMenuEntry = Menu(context: context)
                    newMenuEntry.day = day
                    newMenuEntry.mealType = mealType.name
                    newMenuEntry.mealTypeKey = (mealType.key?.isEmpty == false) ? mealType.key : (mealType.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    newMenuEntry.calendarWeek = Int32(encodedWeek)
                    newMenuEntry.date = CalendarHelper.date(forDayIndex: dayIndex, inWeekOf: weekDate, calendar: calendar)

                    if let randomDish = dishesForMealType.randomElement() {
                        newMenuEntry.addToDishes(randomDish)
                    }
                }
            }

            try context.save()
        } catch {
            AppLogger.error("Error generating menu", error: error, category: AppLogger.service)
            AnalyticsManager.shared.trackError(error, domain: "Menu", category: "Error generating menu")
        }
    }

    private func encodeWeek(for weekDate: Date) -> Int {
        CalendarHelper.weekKey(for: weekDate, calendar: calendar)
    }

    private func dayDate(for day: String, inWeekOf weekDate: Date) -> Date {
        let dayIndex = CalendarHelper.localizedWeekdayNamesStartingFromMonday().firstIndex(of: day) ?? 0
        return CalendarHelper.date(forDayIndex: dayIndex, inWeekOf: weekDate, calendar: calendar)
    }

    /// Re-encodes menu entries written before week calculations were unified.
    ///
    /// Older versions stored `calendarWeek` using `Calendar.current`, whose week rules depend on
    /// the region (e.g. en_US: Sunday-first, week 1 contains Jan 1). Entries written by the
    /// current code always carry `date`, so a `nil` date marks a legacy entry; stamping `date`
    /// during migration makes this idempotent per entry, including entries synced via CloudKit.
    /// For ISO regions such as ru_RU the week key is unchanged.
    func migrateLegacyWeekKeys(legacyCalendar: Calendar = .current) {
        let fetchRequest: NSFetchRequest<Menu> = Menu.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date == nil")
        CoreDataFetchHelper.configureForLargeDataset(fetchRequest)

        do {
            let legacyEntries = try context.fetch(fetchRequest)
            guard !legacyEntries.isEmpty else { return }
            var migrated = 0
            for menu in legacyEntries {
                guard let weekStart = CalendarHelper.weekStart(forLegacyWeekKey: Int(menu.calendarWeek), legacyCalendar: legacyCalendar) else {
                    continue // Invalid key; removeOldWeeks() deletes it
                }
                let newKey = Int32(encodeWeek(for: weekStart))
                if menu.calendarWeek != newKey {
                    menu.calendarWeek = newKey
                    migrated += 1
                }
                menu.date = dayDate(for: menu.day ?? "", inWeekOf: weekStart)
            }
            if context.hasChanges { try context.save() }
            AppLogger.info("Stamped \(legacyEntries.count) legacy menu entries, re-encoded \(migrated) week keys", category: AppLogger.service)
        } catch {
            AppLogger.error("Error migrating legacy menu week keys", error: error, category: AppLogger.service)
            AnalyticsManager.shared.trackError(error, domain: "Menu", category: "Error migrating legacy menu week keys")
        }
    }
    
    func removeOldWeeks() {
        migrateLegacyWeekKeys()
        let currentWeekKey = Int32(encodeWeek(for: now()))
        let fetchRequest: NSFetchRequest<Menu> = Menu.fetchRequest()
        
        // Configure batch fetching for bulk operations
        CoreDataFetchHelper.configureForLargeDataset(fetchRequest)
        
        do {
            let allMenuEntries = try context.fetch(fetchRequest)
            for menu in allMenuEntries {
                if menu.calendarWeek < currentWeekKey {
                    context.delete(menu)
                }
            }
            try context.save()
        } catch {
            AppLogger.error("Error removing old menu entries", error: error, category: AppLogger.service)
            AnalyticsManager.shared.trackError(error, domain: "Menu", category: "Error removing old menu entries")
        }
    }
    
    func replaceDishes(for day: String, mealType: String, selectedWeekDate: Date, with newDishes: [Dish]) throws {
        let encodedWeek = encodeWeek(for: selectedWeekDate)
        
        let fetchRequest: NSFetchRequest<Menu> = Menu.fetchRequest()
        let mtKey = mealType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        fetchRequest.predicate = NSPredicate(format: "day == %@ AND (mealTypeKey == %@ OR mealType == %@) AND calendarWeek == %d", day, mtKey, mealType, encodedWeek)
        
        // Small specific query, use smaller batch size
        CoreDataFetchHelper.configureForSmallList(fetchRequest)
        
        let results = try context.fetch(fetchRequest)
        if let menuEntry = results.first {
            menuEntry.removeFromDishes(menuEntry.dishes ?? NSSet())
            menuEntry.dishes = NSSet(array: newDishes)
            if menuEntry.date == nil {
                menuEntry.date = dayDate(for: day, inWeekOf: selectedWeekDate)
            }
        } else {
            let newMenuEntry = Menu(context: context)
            newMenuEntry.day = day
            newMenuEntry.mealType = mealType
            newMenuEntry.mealTypeKey = mtKey
            newMenuEntry.calendarWeek = Int32(encodedWeek)
            newMenuEntry.date = dayDate(for: day, inWeekOf: selectedWeekDate)
            newMenuEntry.dishes = NSSet(array: newDishes)
        }
        try context.save()
    }
    
    func clearMealType(for day: String, selectedWeekDate: Date, mealType: String? = nil) throws {
        let encodedWeek = encodeWeek(for: selectedWeekDate)

        let fetchRequest: NSFetchRequest<Menu> = Menu.fetchRequest()
        if let mealType = mealType {
            fetchRequest.predicate = NSPredicate(format: "day == %@ AND mealType == %@ AND calendarWeek == %d", day, mealType, encodedWeek)
        } else {
            fetchRequest.predicate = NSPredicate(format: "day == %@ AND calendarWeek == %d", day, encodedWeek)
        }
        
        // Small specific query, use smaller batch size
        CoreDataFetchHelper.configureForSmallList(fetchRequest)
        
        let results = try context.fetch(fetchRequest)
        results.forEach { menuEntry in
            menuEntry.dishes = nil
        }
        try context.save()
    }
}


