//
//  DishListService.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.01.25.
//

import CoreData
import Combine

// MARK: - Dish Sorting Options
enum DishSortOption: String, CaseIterable, SortOption {
    case nameAscending = "nameAsc"
    case nameDescending = "nameDesc"
    case category = "category"
    
    var displayName: String {
        switch self {
        case .nameAscending: return "Name A-Z".localized()
        case .nameDescending: return "Name Z-A".localized()
        case .category: return "Category".localized()
        }
    }
    
    var sortDescriptors: [NSSortDescriptor] {
        switch self {
        case .nameAscending:
            return [NSSortDescriptor(keyPath: \Dish.name, ascending: true)]
        case .nameDescending:
            return [NSSortDescriptor(keyPath: \Dish.name, ascending: false)]
        case .category:
            return [
                NSSortDescriptor(keyPath: \Dish.category?.sortOrder, ascending: true),
                NSSortDescriptor(keyPath: \Dish.name, ascending: true) // Secondary sort by name
            ]
        }
    }
}

protocol DishListServiceProtocol {
    func fetchAllDishes()
    func updateSortOption(_ sortOption: DishSortOption)
    func deleteDishes(dishes: [Dish]) throws
    func deleteDishesInBackground(dishes: [Dish], completion: @escaping (Result<Void, Error>) -> Void)
    
    var delegate: DishListServiceDelegate? { get set }
}

extension DishListService: DishListServiceProtocol {}

protocol DishListServiceDelegate {
    func serviceDidChangeContent(_ dishes: [Dish])
}

class DishListService: NSObject {
    private let context: NSManagedObjectContext
    private let backgroundOperationManager: BackgroundOperationManagerProtocol
    private var fetchedResultsController: NSFetchedResultsController<Dish>
    var delegate: DishListServiceDelegate? = nil
    
    // Performance optimization: debounce rapid changes
    private var changeDebounceTimer: Timer?
    private var hasPendingChanges = false
    private let debounceInterval: TimeInterval
    private var currentSortOption: DishSortOption = .nameAscending
    
    init(context: NSManagedObjectContext, debounceInterval: TimeInterval = 0.1, backgroundOperationManager: BackgroundOperationManagerProtocol = BackgroundOperationManager.shared) {
        self.context = context
        self.backgroundOperationManager = backgroundOperationManager
        self.debounceInterval = debounceInterval
        
        // Initialize with default sort option
        self.fetchedResultsController = Self.createFetchedResultsController(context: context, sortOption: currentSortOption)
        
        super.init()
        
        self.fetchedResultsController.delegate = self
    }
    
    private static func createFetchedResultsController(context: NSManagedObjectContext, sortOption: DishSortOption) -> NSFetchedResultsController<Dish> {
        let fetchRequest: NSFetchRequest<Dish> = Dish.fetchRequest()
        fetchRequest.sortDescriptors = sortOption.sortDescriptors
        
        // Filter out draft dishes from the list (show only complete dishes)
        fetchRequest.predicate = NSPredicate(format: "isDraft == NO OR isDraft == nil")
        
        // Configure batch fetching for better performance
        CoreDataFetchHelper.configure(fetchRequest, batchSize: CoreDataFetchHelper.standardBatchSize)
        
        return NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
    }
    
    func updateSortOption(_ sortOption: DishSortOption) {
        guard sortOption != currentSortOption else { return }
        
        currentSortOption = sortOption
        
        // Create new fetched results controller with updated sort descriptors
        fetchedResultsController = Self.createFetchedResultsController(context: context, sortOption: sortOption)
        fetchedResultsController.delegate = self
        
        // Perform fetch with new sort order - let the delegate handle the notification with debouncing
        do {
            try fetchedResultsController.performFetch()
            // Use debounced notification instead of immediate
            notifyDelegate(immediate: false)
        } catch {
            AppLogger.error("Error fetching dishes with new sort order", error: error, category: AppLogger.service)
            AnalyticsManager.shared.trackError(error, domain: "Dish List", category: "Error fetching dishes with new sort order")
        }
    }
    
    deinit {
        changeDebounceTimer?.invalidate()
    }
    
    func fetchAllDishes() {
        do {
            try fetchedResultsController.performFetch()
            notifyDelegate(immediate: true)
        } catch {
            AppLogger.error("Error fetching dishes", error: error, category: AppLogger.service)
            AnalyticsManager.shared.trackError(error, domain: "Dish List", category: "Error fetching dishes")
        }
    }
    
    // Synchronous deletion for backward compatibility
    func deleteDishes(dishes: [Dish]) throws {
        for dish in dishes {
            context.delete(dish)
        }
        try context.save()
    }
    
    // Background deletion for better UI responsiveness
    func deleteDishesInBackground(dishes: [Dish], completion: @escaping (Result<Void, Error>) -> Void) {
        // For small number of dishes, use synchronous deletion
        if dishes.count <= 3 {
            do {
                try deleteDishes(dishes: dishes)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
            return
        }
        
        // For larger batches, use background context
        let objectIDs = dishes.map { $0.objectID }
        
        backgroundOperationManager.executeBatchSaveOperation(objectIDs: objectIDs) { backgroundObjects in
            // Delete all dishes in background context
            for object in backgroundObjects {
                if let dish = object as? Dish {
                    object.managedObjectContext?.delete(dish)
                }
            }
        } completion: { result in
            completion(result)
        }
    }
    
    // MARK: - Bulk Operations
    
    /// Creates multiple dishes in a single background operation
    func createDishesBulk(dishData: [(name: String, details: String?, category: DishCategory?, mealTypes: Set<MealType>)], completion: @escaping (Result<[Dish], Error>) -> Void) {
        guard !dishData.isEmpty else {
            completion(.success([]))
            return
        }
        
        // For small batches, use regular synchronous approach
        if dishData.count <= 5 {
            do {
                var createdDishes: [Dish] = []
                for data in dishData {
                    // Upsert by key
                    let key = StaticKeyHelper.stableKey(from: data.name)
                    let fetch: NSFetchRequest<Dish> = Dish.fetchRequest()
                    fetch.predicate = NSPredicate(format: "key == %@ OR name == %@", key, data.name)
                    fetch.fetchLimit = 1
                    let existing = try context.fetch(fetch).first
                    let dish = existing ?? Dish(context: context)
                    dish.key = key
                    dish.name = data.name
                    dish.details = data.details
                    dish.category = data.category
                    dish.mealTypes = data.mealTypes as NSSet
                    dish.isDraft = false
                    createdDishes.append(dish)
                }
                try context.save()
                completion(.success(createdDishes))
            } catch {
                completion(.failure(error))
            }
            return
        }
        
        // For larger batches, use background context
        backgroundOperationManager.executeHeavyOperation { backgroundContext in
            var createdObjectIDs: [NSManagedObjectID] = []
            
            for data in dishData {
                let dish = Dish(context: backgroundContext)
                dish.key = StaticKeyHelper.stableKey(from: data.name)
                dish.name = data.name
                dish.details = data.details
                dish.isDraft = false  // Bulk created dishes are complete
                
                // Transfer category to background context
                if let categoryID = data.category?.objectID,
                   let backgroundCategory = try? backgroundContext.existingObject(with: categoryID) as? DishCategory {
                    dish.category = backgroundCategory
                }
                
                // Transfer meal types to background context
                var backgroundMealTypes = Set<MealType>()
                for mealType in data.mealTypes {
                    if let backgroundMealType = try? backgroundContext.existingObject(with: mealType.objectID) as? MealType {
                        backgroundMealTypes.insert(backgroundMealType)
                    }
                }
                dish.mealTypes = backgroundMealTypes as NSSet
                
                createdObjectIDs.append(dish.objectID)
            }
            
            if backgroundContext.hasChanges {
                try backgroundContext.save()
            }
            
            return createdObjectIDs
        } completion: { result in
            switch result {
            case .success(let objectIDs):
                // Get dishes in main context
                do {
                    let mainDishes = try objectIDs.map { objectID in
                        try self.context.existingObject(with: objectID) as! Dish
                    }
                    completion(.success(mainDishes))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Updates multiple dishes in a single background operation
    func updateDishesBulk(dishUpdates: [(dish: Dish, name: String?, details: String?, category: DishCategory?)], completion: @escaping (Result<Void, Error>) -> Void) {
        guard !dishUpdates.isEmpty else {
            completion(.success(()))
            return
        }
        
        // For small batches, use regular synchronous approach
        if dishUpdates.count <= 3 {
            do {
                for update in dishUpdates {
                    if let name = update.name {
                        update.dish.name = name
                    }
                    if let details = update.details {
                        update.dish.details = details
                    }
                    if let category = update.category {
                        update.dish.category = category
                    }
                }
                try context.save()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
            return
        }
        
        // For larger batches, use background context
        let dishObjectIDs = dishUpdates.map { $0.dish.objectID }
        
        backgroundOperationManager.executeBatchSaveOperation(objectIDs: dishObjectIDs) { backgroundObjects in
            for (index, object) in backgroundObjects.enumerated() {
                guard let dish = object as? Dish,
                      index < dishUpdates.count else { continue }
                
                let update = dishUpdates[index]
                
                if let name = update.name {
                    dish.name = name
                }
                if let details = update.details {
                    dish.details = details
                }
                if let categoryID = update.category?.objectID,
                   let backgroundCategory = try? object.managedObjectContext?.existingObject(with: categoryID) as? DishCategory {
                    dish.category = backgroundCategory
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
            // For direct calls (like fetchAllDishes), notify immediately
            let dishes = fetchedResultsController.fetchedObjects ?? []
            delegate.serviceDidChangeContent(dishes)
            return
        }
        
        // Debounce rapid changes for better performance
        changeDebounceTimer?.invalidate()
        hasPendingChanges = true
        
        changeDebounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            guard let self = self, self.hasPendingChanges else { return }
            
            let dishes = self.fetchedResultsController.fetchedObjects ?? []
            delegate.serviceDidChangeContent(dishes)
            self.hasPendingChanges = false
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate
extension DishListService: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        notifyDelegate(immediate: false)
    }
}
