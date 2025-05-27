//
//  Product+CoreDataProperties.swift
//  FamilyMenuPlanner
//
//  Created by Pivovar 63 on 27.05.25.
//
//

import Foundation
import CoreData


extension Product {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Product> {
        return NSFetchRequest<Product>(entityName: "Product")
    }

    @NSManaged public var isSelected: Bool
    @NSManaged public var name: String?
    @NSManaged public var dishes: NSSet?
    @NSManaged public var ingredientDetails: NSSet?
    @NSManaged public var unit: Unit?

}

// MARK: Generated accessors for dishes
extension Product {

    @objc(addDishesObject:)
    @NSManaged public func addToDishes(_ value: Dish)

    @objc(removeDishesObject:)
    @NSManaged public func removeFromDishes(_ value: Dish)

    @objc(addDishes:)
    @NSManaged public func addToDishes(_ values: NSSet)

    @objc(removeDishes:)
    @NSManaged public func removeFromDishes(_ values: NSSet)

}

// MARK: Generated accessors for ingredientDetails
extension Product {

    @objc(addIngredientDetailsObject:)
    @NSManaged public func addToIngredientDetails(_ value: IngredientDetail)

    @objc(removeIngredientDetailsObject:)
    @NSManaged public func removeFromIngredientDetails(_ value: IngredientDetail)

    @objc(addIngredientDetails:)
    @NSManaged public func addToIngredientDetails(_ values: NSSet)

    @objc(removeIngredientDetails:)
    @NSManaged public func removeFromIngredientDetails(_ values: NSSet)

}

extension Product : Identifiable {

}
