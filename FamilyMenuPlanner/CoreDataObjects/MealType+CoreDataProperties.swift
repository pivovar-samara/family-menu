//
//  MealType+CoreDataProperties.swift
//  FamilyMenuPlanner
//
//  Created by Pivovar 63 on 27.05.25.
//
//

import Foundation
import CoreData


extension MealType {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MealType> {
        return NSFetchRequest<MealType>(entityName: "MealType")
    }

    @NSManaged public var name: String?
    @NSManaged public var sortOrder: Int16
    @NSManaged public var dishes: NSSet?

}

// MARK: Generated accessors for dishes
extension MealType {

    @objc(addDishesObject:)
    @NSManaged public func addToDishes(_ value: Dish)

    @objc(removeDishesObject:)
    @NSManaged public func removeFromDishes(_ value: Dish)

    @objc(addDishes:)
    @NSManaged public func addToDishes(_ values: NSSet)

    @objc(removeDishes:)
    @NSManaged public func removeFromDishes(_ values: NSSet)

}

extension MealType : Identifiable {

}
