//
//  ProductSelectionService.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 26.01.25.
//

import CoreData

protocol ProductSelectionServiceProtocol {
    func fetchAllProducts() -> [Product]
}

extension ProductSelectionService: ProductSelectionServiceProtocol {}

class ProductSelectionService {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func fetchAllProducts() -> [Product] {
        let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Product.name, ascending: true)]
        
        // Configure batch fetching for better performance
        CoreDataFetchHelper.configure(fetchRequest, batchSize: CoreDataFetchHelper.standardBatchSize)

        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Error loading products: \(error)")
            return []
        }
    }
}
