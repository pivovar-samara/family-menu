//
//  ProductListService.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 19.01.25.
//

import CoreData

protocol ProductListServiceProtocol {
    func fetchAllProducts()
    func fetchAllUnits() -> [Unit]
    func deleteProducts(products: [Product]) throws
    func deleteProductsInBackground(products: [Product], completion: @escaping (Result<Void, Error>) -> Void)
    
    var delegate: ProductListServiceDelegate? { get set }
}

extension ProductListService: ProductListServiceProtocol {}

protocol ProductListServiceDelegate {
    func serviceDidChangeContent(_ products: [Product])
}

class ProductListService: NSObject {
    private let context: NSManagedObjectContext
    private let backgroundOperationManager: BackgroundOperationManagerProtocol
    private let fetchedResultsController: NSFetchedResultsController<Product>
    var delegate: ProductListServiceDelegate? = nil
    
    // Performance optimization: debounce rapid changes
    private var changeDebounceTimer: Timer?
    private var hasPendingChanges = false
    private let debounceInterval: TimeInterval

    init(context: NSManagedObjectContext, debounceInterval: TimeInterval = 0.1, backgroundOperationManager: BackgroundOperationManagerProtocol = BackgroundOperationManager.shared) {
        self.context = context
        self.backgroundOperationManager = backgroundOperationManager
        self.debounceInterval = debounceInterval
        
        let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Product.name, ascending: true)]
        
        // Configure batch fetching for better performance
        CoreDataFetchHelper.configure(fetchRequest, batchSize: CoreDataFetchHelper.standardBatchSize)
        
        self.fetchedResultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        super.init()
        
        self.fetchedResultsController.delegate = self
    }
    
    deinit {
        changeDebounceTimer?.invalidate()
    }
    
    func fetchAllProducts() {
        do {
            try fetchedResultsController.performFetch()
            notifyDelegate(immediate: true)
        } catch {
            print("Error fetching products: \(error)")
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
    
    // MARK: - Private Methods
    
    private func notifyDelegate(immediate: Bool = false) {
        guard let delegate = delegate else { return }
        
        if immediate {
            // For direct calls (like fetchAllProducts), notify immediately
            let products = fetchedResultsController.fetchedObjects ?? []
            delegate.serviceDidChangeContent(products)
            return
        }
        
        // Debounce rapid changes for better performance
        changeDebounceTimer?.invalidate()
        hasPendingChanges = true
        
        changeDebounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            guard let self = self, self.hasPendingChanges else { return }
            
            let products = self.fetchedResultsController.fetchedObjects ?? []
            delegate.serviceDidChangeContent(products)
            self.hasPendingChanges = false
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate
extension ProductListService: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        notifyDelegate(immediate: false)
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
