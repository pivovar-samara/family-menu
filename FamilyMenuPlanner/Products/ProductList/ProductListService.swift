//
//  ProductListService.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 19.01.25.
//

import CoreData

protocol ProductListServiceProtocol {
    func fetchAllProducts() -> [Product]
    func fetchAllUnits() -> [Unit]
    func deleteProducts(products: [Product]) throws
    func addProduct(name: String, unit: Unit) throws
}

extension ProductListService: ProductListServiceProtocol {}

class ProductListService {
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
    
    func fetchAllUnits() -> [Unit] {
        let fetchRequest: NSFetchRequest<Unit> = Unit.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Unit.sortOrder, ascending: true)]
        
        // Units are typically small datasets, use smaller batch size
        CoreDataFetchHelper.configureForSmallList(fetchRequest)

        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Error loading units: \(error)")
            return []
        }
    }
    
    // Delete products from Core Data
    func deleteProducts(products: [Product]) throws {
        for product in products {
            context.delete(product)
        }
        try context.save()
    }
    
    func addProduct(name: String, unit: Unit) throws {
        let newProduct = Product(context: context)
        newProduct.name = name
        newProduct.unit = unit
        
        try context.save()
    }
}
