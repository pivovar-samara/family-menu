//
//  Menu+CoreDataProperties.swift
//  FamilyMenuPlanner
//
//  Created by Pivovar 63 on 27.05.25.
//
//

import Foundation
import CoreData


extension Menu {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Menu> {
        return NSFetchRequest<Menu>(entityName: "Menu")
    }

    @NSManaged public var calendarWeek: Int32
    @NSManaged public var date: Date?
    @NSManaged public var day: String?
    @NSManaged public var mealType: String?
    @NSManaged public var dishes: NSSet?

}

// MARK: Generated accessors for dishes
extension Menu {

    @objc(addDishesObject:)
    @NSManaged public func addToDishes(_ value: Dish)

    @objc(removeDishesObject:)
    @NSManaged public func removeFromDishes(_ value: Dish)

    @objc(addDishes:)
    @NSManaged public func addToDishes(_ values: NSSet)

    @objc(removeDishes:)
    @NSManaged public func removeFromDishes(_ values: NSSet)

}

extension Menu : Identifiable {

}
