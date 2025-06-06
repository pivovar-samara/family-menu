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
    func deleteProductsInBackground(products: [Product], completion: @escaping (Result<Void, Error>) -> Void)
    func addProduct(name: String, unit: Unit) throws
    func addProductInBackground(name: String, unit: Unit, completion: @escaping (Result<Product, Error>) -> Void)
    func createProductsBulk(productData: [(name: String, unit: Unit)], completion: @escaping (Result<[Product], Error>) -> Void)
}

extension ProductListService: ProductListServiceProtocol {}

class ProductListService {
    private let context: NSManagedObjectContext
    private let backgroundOperationManager: BackgroundOperationManagerProtocol

    init(context: NSManagedObjectContext, backgroundOperationManager: BackgroundOperationManagerProtocol = BackgroundOperationManager.shared) {
        self.context = context
        self.backgroundOperationManager = backgroundOperationManager
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
    
    // Delete products from Core Data (synchronous - for backward compatibility)
    func deleteProducts(products: [Product]) throws {
        for product in products {
            context.delete(product)
        }
        try context.save()
    }
    
    // Delete products using background context for better UI responsiveness
    func deleteProductsInBackground(products: [Product], completion: @escaping (Result<Void, Error>) -> Void) {
        // For small number of products, use synchronous deletion
        if products.count <= 3 {
            do {
                try deleteProducts(products: products)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
            return
        }
        
        // For larger batches, use background context
        let objectIDs = products.map { $0.objectID }
        
        backgroundOperationManager.executeBatchSaveOperation(objectIDs: objectIDs) { backgroundObjects in
            // Delete all products in background context
            for object in backgroundObjects {
                if let product = object as? Product {
                    object.managedObjectContext?.delete(product)
                }
            }
        } completion: { result in
            completion(result)
        }
    }
    
    // Add product to Core Data (synchronous - for backward compatibility)
    func addProduct(name: String, unit: Unit) throws {
        let product = Product(context: context)
        product.name = name
        product.unit = unit
        try context.save()
    }
    
    // Add product using background context for better UI responsiveness
    func addProductInBackground(name: String, unit: Unit, completion: @escaping (Result<Product, Error>) -> Void) {
        let unitObjectID = unit.objectID
        
        backgroundOperationManager.executeHeavyOperation { backgroundContext in
            // Get unit in background context
            guard let backgroundUnit = try? backgroundContext.existingObject(with: unitObjectID) as? Unit else {
                throw ProductListServiceError.unitNotFound
            }
            
            // Create new product
            let product = Product(context: backgroundContext)
            product.name = name
            product.unit = backgroundUnit
            
            // Save in background context
            if backgroundContext.hasChanges {
                try backgroundContext.save()
            }
            
            return product.objectID
        } completion: { result in
            switch result {
            case .success(let objectID):
                // Get the product in main context
                do {
                    let mainProduct = try self.context.existingObject(with: objectID) as! Product
                    completion(.success(mainProduct))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Bulk Operations
    
    /// Creates multiple products in a single background operation
    func createProductsBulk(productData: [(name: String, unit: Unit)], completion: @escaping (Result<[Product], Error>) -> Void) {
        guard !productData.isEmpty else {
            completion(.success([]))
            return
        }
        
        // For small batches, use regular synchronous approach
        if productData.count <= 5 {
            do {
                var createdProducts: [Product] = []
                for data in productData {
                    let product = Product(context: context)
                    product.name = data.name
                    product.unit = data.unit
                    createdProducts.append(product)
                }
                try context.save()
                completion(.success(createdProducts))
            } catch {
                completion(.failure(error))
            }
            return
        }
        
        // For larger batches, use background context
        let unitObjectIDs = productData.map { $0.unit.objectID }
        
        backgroundOperationManager.executeHeavyOperation { backgroundContext in
            var createdProducts: [Product] = []
            
            for (index, data) in productData.enumerated() {
                guard let backgroundUnit = try? backgroundContext.existingObject(with: unitObjectIDs[index]) as? Unit else {
                    throw ProductListServiceError.unitNotFound
                }
                
                let product = Product(context: backgroundContext)
                product.name = data.name
                product.unit = backgroundUnit
                createdProducts.append(product)
            }
            
            if backgroundContext.hasChanges {
                try backgroundContext.save()
            }
            
            // Collect object IDs only after saving
            return createdProducts.map { $0.objectID }
        } completion: { result in
            switch result {
            case .success(let objectIDs):
                // Get products in main context
                do {
                    let mainProducts = try objectIDs.map { objectID in
                        try self.context.existingObject(with: objectID) as! Product
                    }
                    completion(.success(mainProducts))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Service Errors
enum ProductListServiceError: LocalizedError {
    case unitNotFound
    case invalidProductData
    
    var errorDescription: String? {
        switch self {
        case .unitNotFound:
            return "Selected unit not found"
        case .invalidProductData:
            return "Invalid product data provided"
        }
    }
}
