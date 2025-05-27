//
//  Unit+CoreDataProperties.swift
//  FamilyMenuPlanner
//
//  Created by Pivovar 63 on 27.05.25.
//
//

import Foundation
import CoreData


extension Unit {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Unit> {
        return NSFetchRequest<Unit>(entityName: "Unit")
    }

    @NSManaged public var name: String?
    @NSManaged public var sortOrder: Int16
    @NSManaged public var products: NSSet?

}

// MARK: Generated accessors for products
extension Unit {

    @objc(addProductsObject:)
    @NSManaged public func addToProducts(_ value: Product)

    @objc(removeProductsObject:)
    @NSManaged public func removeFromProducts(_ value: Product)

    @objc(addProducts:)
    @NSManaged public func addToProducts(_ values: NSSet)

    @objc(removeProducts:)
    @NSManaged public func removeFromProducts(_ values: NSSet)

}

extension Unit : Identifiable {

}
