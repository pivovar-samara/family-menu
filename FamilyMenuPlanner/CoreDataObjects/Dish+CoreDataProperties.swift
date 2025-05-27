//
//  Dish+CoreDataProperties.swift
//  FamilyMenuPlanner
//
//  Created by Pivovar 63 on 27.05.25.
//
//

import Foundation
import CoreData


extension Dish {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Dish> {
        return NSFetchRequest<Dish>(entityName: "Dish")
    }

    @NSManaged public var details: String?
    @NSManaged public var name: String?
    @NSManaged public var ingredientDetails: NSSet?
    @NSManaged public var mealTypes: NSSet?
    @NSManaged public var menus: NSSet?
    @NSManaged public var products: NSSet?

}

// MARK: Generated accessors for ingredientDetails
extension Dish {

    @objc(addIngredientDetailsObject:)
    @NSManaged public func addToIngredientDetails(_ value: IngredientDetail)

    @objc(removeIngredientDetailsObject:)
    @NSManaged public func removeFromIngredientDetails(_ value: IngredientDetail)

    @objc(addIngredientDetails:)
    @NSManaged public func addToIngredientDetails(_ values: NSSet)

    @objc(removeIngredientDetails:)
    @NSManaged public func removeFromIngredientDetails(_ values: NSSet)

}

// MARK: Generated accessors for mealTypes
extension Dish {

    @objc(addMealTypesObject:)
    @NSManaged public func addToMealTypes(_ value: MealType)

    @objc(removeMealTypesObject:)
    @NSManaged public func removeFromMealTypes(_ value: MealType)

    @objc(addMealTypes:)
    @NSManaged public func addToMealTypes(_ values: NSSet)

    @objc(removeMealTypes:)
    @NSManaged public func removeFromMealTypes(_ values: NSSet)

}

// MARK: Generated accessors for menus
extension Dish {

    @objc(addMenusObject:)
    @NSManaged public func addToMenus(_ value: Menu)

    @objc(removeMenusObject:)
    @NSManaged public func removeFromMenus(_ value: Menu)

    @objc(addMenus:)
    @NSManaged public func addToMenus(_ values: NSSet)

    @objc(removeMenus:)
    @NSManaged public func removeFromMenus(_ values: NSSet)

}

// MARK: Generated accessors for products
extension Dish {

    @objc(addProductsObject:)
    @NSManaged public func addToProducts(_ value: Product)

    @objc(removeProductsObject:)
    @NSManaged public func removeFromProducts(_ value: Product)

    @objc(addProducts:)
    @NSManaged public func addToProducts(_ values: NSSet)

    @objc(removeProducts:)
    @NSManaged public func removeFromProducts(_ values: NSSet)

}

extension Dish : Identifiable {

}
