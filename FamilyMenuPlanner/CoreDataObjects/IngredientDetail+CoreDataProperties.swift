//
//  IngredientDetail+CoreDataProperties.swift
//  FamilyMenuPlanner
//
//  Created by Pivovar 63 on 27.05.25.
//
//

import Foundation
import CoreData


extension IngredientDetail {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<IngredientDetail> {
        return NSFetchRequest<IngredientDetail>(entityName: "IngredientDetail")
    }

    @NSManaged public var quantity: Double
    @NSManaged public var sortOrder: Int16
    @NSManaged public var dish: Dish?
    @NSManaged public var product: Product?

}

extension IngredientDetail : Identifiable {

}
