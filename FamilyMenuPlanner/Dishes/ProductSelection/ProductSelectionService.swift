//
//  ProductSelectionService.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 26.01.25.
//

import CoreData

class ProductSelectionService {
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
}
