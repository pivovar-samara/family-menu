//
//  ProductListService.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 19.01.25.
//

import CoreData

class ProductListService {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func fetchAllProducts() -> [Product] {
        let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Product.name, ascending: true)]

        do {
            try context.setQueryGenerationFrom(.current)
            return try context.fetch(fetchRequest)
        } catch {
            print("Error loading products: \(error)")
            return []
        }
    }
    
    func fetchAllUnits() -> [Unit] {
        let fetchRequest: NSFetchRequest<Unit> = Unit.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Unit.sortOrder, ascending: true)]

        do {
            try context.setQueryGenerationFrom(.current)
            return try context.fetch(fetchRequest)
        } catch {
            print("Error loading units: \(error)")
            return []
        }
    }
    
    // Delete products from Core Data
    func deleteProducts(products: [Product]) throws {
        try context.setQueryGenerationFrom(.current)
        for product in products {
            context.delete(product)
        }
        try context.save()
    }
    
    func addProduct(name: String, unit: Unit) throws {
        try context.setQueryGenerationFrom(.current)
        
        let newProduct = Product(context: context)
        newProduct.name = name
        newProduct.unit = unit
        
        try context.save()
    }
}
