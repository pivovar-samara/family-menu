//
//  DishDetailsService.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.01.25.
//

import CoreData

protocol DishDetailsServiceProtocol {
    func fetchAllUnits() -> [Unit]
    func fetchAllMealTypes() -> [MealType]
    func fetchAllDishCategories() -> [DishCategory]
    func createDish() throws -> Dish
    func createIngredient() throws -> IngredientDetail
    func deleteIngredient(ingredient: IngredientDetail)
    func saveChanges() throws
    func saveChangesInBackground(completion: @escaping (Result<Void, Error>) -> Void)
    func rollback()
}

extension DishDetailsService: DishDetailsServiceProtocol {}

class DishDetailsService {
    private let context: NSManagedObjectContext
    private let backgroundOperationManager: BackgroundOperationManager
    
    init(context: NSManagedObjectContext, backgroundOperationManager: BackgroundOperationManager = BackgroundOperationManager.shared) {
        self.context = context
        self.backgroundOperationManager = backgroundOperationManager
    }
    
    func fetchAllUnits() -> [Unit] {
        let fetchRequest: NSFetchRequest<Unit> = Unit.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Unit.sortOrder, ascending: true)]
        
        // Units are typically small datasets, use smaller batch size
        CoreDataFetchHelper.configureForSmallList(fetchRequest)

        do {
            return try context.fetch(fetchRequest)
        } catch {
            AppLogger.error("Error loading units", error: error, category: AppLogger.service)
            return []
        }
    }
    
    func fetchAllMealTypes() -> [MealType] {
        let fetchRequest: NSFetchRequest<MealType> = MealType.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MealType.sortOrder, ascending: true)]
        
        // Meal types are typically small datasets, use smaller batch size
        CoreDataFetchHelper.configureForSmallList(fetchRequest)

        do {
            return try context.fetch(fetchRequest)
        } catch {
            AppLogger.error("Error loading meal types", error: error, category: AppLogger.service)
            return []
        }
    }
    
    func fetchAllDishCategories() -> [DishCategory] {
        let fetchRequest: NSFetchRequest<DishCategory> = DishCategory.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \DishCategory.sortOrder, ascending: true)]
        
        // Dish categories are typically small datasets, use smaller batch size
        CoreDataFetchHelper.configureForSmallList(fetchRequest)

        do {
            return try context.fetch(fetchRequest)
        } catch {
            AppLogger.error("Error loading dish categories", error: error, category: AppLogger.service)
            return []
        }
    }
    
    func createDish() throws -> Dish {
        let dish = Dish(context: context)
        dish.isDraft = true
        return dish
    }
    
    func createIngredient() throws -> IngredientDetail {
        let ingredient = IngredientDetail(context: context)
        return ingredient
    }
    
    func deleteIngredient(ingredient: IngredientDetail) {
        context.delete(ingredient)
    }
    
    // Synchronous save for backward compatibility
    func saveChanges() throws {
        AppLogger.info("Saving dish changes", category: AppLogger.service)
        try context.save()
        AppLogger.info("Dish changes saved successfully", category: AppLogger.service)
    }
    
    // Background save for better UI responsiveness
    func saveChangesInBackground(completion: @escaping (Result<Void, Error>) -> Void) {
        // Check if there are any changes to save
        guard context.hasChanges else {
            completion(.success(()))
            return
        }
        
        // For simple saves with few changes, use synchronous approach
        let changedObjects = context.insertedObjects.union(context.updatedObjects).union(context.deletedObjects)
        if changedObjects.count <= 3 {
            do {
                try saveChanges()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
            return
        }
        
        // For more complex changes (dishes with many ingredients), use background context
        AppLogger.info("Saving dish changes in background", category: AppLogger.service)
        
        // Get object IDs of changed objects to transfer to background context
        let insertedObjectIDs = context.insertedObjects.compactMap { $0.objectID.isTemporaryID ? nil : $0.objectID }
        let updatedObjectIDs = context.updatedObjects.map { $0.objectID }
        let deletedObjectIDs = context.deletedObjects.map { $0.objectID }
        
        backgroundOperationManager.executeHeavyOperation { backgroundContext in
            // Transfer inserted objects (if any have permanent IDs)
            for objectID in insertedObjectIDs {
                if let _ = try? backgroundContext.existingObject(with: objectID) {
                    // Object already exists in background context
                }
            }
            
            // Transfer updated objects
            for objectID in updatedObjectIDs {
                if let _ = try? backgroundContext.existingObject(with: objectID) {
                    // Changes will be automatically merged
                }
            }
            
            // Handle deleted objects
            for objectID in deletedObjectIDs {
                if let object = try? backgroundContext.existingObject(with: objectID) {
                    backgroundContext.delete(object)
                }
            }
            
            // Save changes in background context
            if backgroundContext.hasChanges {
                try backgroundContext.save()
            }
            
            return ()
        } completion: { result in
            switch result {
            case .success:
                AppLogger.info("Dish changes saved successfully in background", category: AppLogger.service)
                completion(.success(()))
            case .failure(let error):
                AppLogger.error("Failed to save dish changes in background", error: error, category: AppLogger.service)
                completion(.failure(error))
            }
        }
    }
    
    func rollback() {
        context.rollback()
    }
}
