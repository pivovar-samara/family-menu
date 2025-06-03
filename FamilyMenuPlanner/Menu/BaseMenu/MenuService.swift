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

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchMenu(for weekIndex: Int) -> [DailyMenu] {
        let calendar = Calendar.current
        let startOfCurrentWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        guard let selectedWeekDate = calendar.date(byAdding: .weekOfYear, value: weekIndex, to: startOfCurrentWeek) else { return [] }
        let selectedWeekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedWeekDate)
        let encodedWeek = encodeWeek(selectedWeekComponents)

        do {
            let fetchRequest: NSFetchRequest<Menu> = Menu.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "calendarWeek == %d", encodedWeek)
            let menuEntries = try context.fetch(fetchRequest)

            var initializedMenu: [DailyMenu] = []
            let weekdays = localizedWeekdayNamesStartingFromMonday()
            
            let mealTypeFetchRequest = MealType.fetchRequest()
            mealTypeFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MealType.sortOrder, ascending: true)]
            let mealTypes = try context.fetch(mealTypeFetchRequest)

            for day in weekdays {
                var dailyMeals: [DailyMeal] = []
                for mealType in mealTypes {
                    var dishes = menuEntries.filter({ $0.day == day && $0.mealType == mealType.name }).first?.dishes?.allObjects as? [Dish] ?? []
                    // sort dishes by name
                    dishes.sort { $0.name ?? "" < $1.name ?? "" }
                    dailyMeals.append(DailyMeal(meal: mealType.name ?? "", dishes: dishes))
                }
                initializedMenu.append(DailyMenu(day: day, dailyMeals: dailyMeals))
            }

            return initializedMenu
        } catch {
            print("Error loading menu for the selected week: \(error)")
            return []
        }
    }

    func generateMenu(for weekDate: Date) {
        do {
            guard let dishes = try context.fetch(Dish.fetchRequest()) as? [Dish],
                  !dishes.isEmpty else {
                print("No dishes available to generate a menu.")
                return
            }
            
            let weekdays = localizedWeekdayNamesStartingFromMonday()
            
            let mealTypesFetchRequest = MealType.fetchRequest()
            mealTypesFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MealType.sortOrder, ascending: true)]
            let mealTypes = try context.fetch(mealTypesFetchRequest)
            
            let weekComponents = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekDate)
            let encodedWeek = encodeWeek(weekComponents)

            let fetchRequest: NSFetchRequest<Menu> = Menu.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "calendarWeek == %d", encodedWeek)

            let existingEntries = try context.fetch(fetchRequest)
            for entry in existingEntries {
                context.delete(entry)
            }

            for day in weekdays {
                for mealType in mealTypes {
                    let dishesForMealType = dishes.filter { dish in
                        guard let mealTypes = dish.mealTypes as? Set<MealType> else { return false }
                        return mealTypes.contains(mealType)
                    }

                    let newMenuEntry = Menu(context: context)
                    newMenuEntry.day = day
                    newMenuEntry.mealType = mealType.name
                    newMenuEntry.calendarWeek = Int32(encodedWeek)

                    if let randomDish = dishesForMealType.randomElement() {
                        newMenuEntry.addToDishes(randomDish)
                    }
                }
            }

            try context.save()
        } catch {
            print("Error generating menu: \(error)")
        }
    }

    private func encodeWeek(_ weekComponents: DateComponents) -> Int {
        let year = weekComponents.yearForWeekOfYear ?? 0
        let week = weekComponents.weekOfYear ?? 0
        return year * 100 + week
    }
    
    func removeOldWeeks() {
        let currentWeek = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let fetchRequest: NSFetchRequest<Menu> = Menu.fetchRequest()
        do {
            let allMenuEntries = try context.fetch(fetchRequest)
            for menu in allMenuEntries {
                if menu.calendarWeek < Int32(encodeWeek(currentWeek)) {
                    context.delete(menu)
                }
            }
            try context.save()
        } catch {
            print("Error removing old menu entries.")
        }
    }
    
    func replaceDishes(for day: String, mealType: String, selectedWeekDate: Date, with newDishes: [Dish]) throws {
        let selectedWeekComponents = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedWeekDate)
        let encodedWeek = encodeWeek(selectedWeekComponents)
        
        let fetchRequest: NSFetchRequest<Menu> = Menu.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "day == %@ AND mealType == %@ AND calendarWeek == %d", day, mealType, encodedWeek)
        
        let results = try context.fetch(fetchRequest)
        if let menuEntry = results.first {
            menuEntry.removeFromDishes(menuEntry.dishes ?? NSSet())
            menuEntry.dishes = NSSet(array: newDishes)
        } else {
            let newMenuEntry = Menu(context: context)
            newMenuEntry.day = day
            newMenuEntry.mealType = mealType
            newMenuEntry.calendarWeek = Int32(encodedWeek)
            newMenuEntry.dishes = NSSet(array: newDishes)
        }
        try context.save()
    }
    
    func clearMealType(for day: String, selectedWeekDate: Date, mealType: String? = nil) throws {
        let selectedWeekComponents = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedWeekDate)
        let encodedWeek = encodeWeek(selectedWeekComponents)

        let fetchRequest: NSFetchRequest<Menu> = Menu.fetchRequest()
        if let mealType = mealType {
            fetchRequest.predicate = NSPredicate(format: "day == %@ AND mealType == %@ AND calendarWeek == %d", day, mealType, encodedWeek)
        } else {
            fetchRequest.predicate = NSPredicate(format: "day == %@ AND calendarWeek == %d", day, encodedWeek)
        }
        
        let results = try context.fetch(fetchRequest)
        results.forEach { menuEntry in
            menuEntry.dishes = nil
        }
        try context.save()
    }
}


