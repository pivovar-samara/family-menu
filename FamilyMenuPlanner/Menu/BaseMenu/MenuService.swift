//
//  MenuService.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 14.01.25.
//

import CoreData

class MenuService {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchMenu(for weekIndex: Int) -> [String: [String: [Dish]]] {
        let calendar = Calendar.current
        let startOfCurrentWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        guard let selectedWeekDate = calendar.date(byAdding: .weekOfYear, value: weekIndex, to: startOfCurrentWeek) else { return [:] }
        let selectedWeekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedWeekDate)
        let encodedWeek = encodeWeek(selectedWeekComponents)

        let fetchRequest: NSFetchRequest<Menu> = Menu.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "calendarWeek == %d", encodedWeek)

        do {
            try context.setQueryGenerationFrom(.current)
            let menuEntries = try context.fetch(fetchRequest)

            var initializedMenu: [String: [String: [Dish]]] = [:]
            let weekdays = localizedWeekdayNamesStartingFromMonday()

            for day in weekdays {
                initializedMenu[day] = [:]
                for mealType in try context.fetch(MealType.fetchRequest()) as! [MealType] {
                    initializedMenu[day]?[mealType.name ?? ""] = []
                }
            }

            for entry in menuEntries {
                if let day = entry.day,
                   let mealType = entry.mealType,
                   let dishes = entry.dishes?.allObjects as? [Dish] {
                    initializedMenu[day]?[mealType] = dishes
                }
            }

            return initializedMenu
        } catch {
            print("Error loading menu for the selected week: \(error)")
            return [:]
        }
    }

    func generateMenu(for weekDate: Date) {
        do {
            guard let dishes = try context.fetch(Dish.fetchRequest()) as? [Dish],
                  !dishes.isEmpty else {
                print("No dishes available to generate a menu.")
                return
            }
            
            try context.setQueryGenerationFrom(.current)
            
            let weekdays = localizedWeekdayNamesStartingFromMonday()
            let mealTypes = try context.fetch(MealType.fetchRequest()) as! [MealType]
            
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
            try context.setQueryGenerationFrom(.current)
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
    
    func replaceDish(for day: String, mealType: String, selectedWeekDate: Date, with newDish: Dish) throws {
        let selectedWeekComponents = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedWeekDate)
        let encodedWeek = encodeWeek(selectedWeekComponents)
        
        let fetchRequest: NSFetchRequest<Menu> = Menu.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "day == %@ AND mealType == %@ AND calendarWeek == %d", day, mealType, encodedWeek)
        
        try context.setQueryGenerationFrom(.current)
        let results = try context.fetch(fetchRequest)
        if let menuEntry = results.first {
            menuEntry.removeFromDishes(menuEntry.dishes ?? NSSet())
            menuEntry.addToDishes(newDish)
        } else {
            let newMenuEntry = Menu(context: context)
            newMenuEntry.day = day
            newMenuEntry.mealType = mealType
            newMenuEntry.calendarWeek = Int32(encodedWeek)
            newMenuEntry.addToDishes(newDish)
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
        
        try context.setQueryGenerationFrom(.current)
        let results = try context.fetch(fetchRequest)
        results.forEach { menuEntry in
            menuEntry.dishes = nil
        }
        try context.save()
    }
}


