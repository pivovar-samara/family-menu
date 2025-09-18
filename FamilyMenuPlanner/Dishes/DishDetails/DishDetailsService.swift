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
    func normalizeIngredients(for dish: Dish)
}

extension DishDetailsService: DishDetailsServiceProtocol {}

class DishDetailsService {
    private let context: NSManagedObjectContext
    private let backgroundOperationManager: BackgroundOperationManager
    private enum Thresholds {
        static let smallChangeCount: Int = 3
    }
    
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
        // Upsert-by-key before save to avoid duplicates when a draft gets named
        if let dishes = try? context.fetch(Dish.fetchRequest()) as? [Dish] {
            for d in dishes where !(d.name?.isEmpty ?? true) {
                let computed = StaticKeyHelper.stableKey(from: d.name!)
                if d.key != computed { d.key = computed }
            }
        }
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
        if changedObjects.count <= Thresholds.smallChangeCount {
            do {
                try saveChanges()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
            return
        }
        
        // For more complex changes (dishes with many ingredients), use background context and obtain permanent IDs
        AppLogger.info("Saving dish changes in background", category: AppLogger.service)

        // Ensure inserted objects have permanent IDs so they can be resolved in the background context
        let inserted = Array(context.insertedObjects)
        if !inserted.isEmpty {
            do { try context.obtainPermanentIDs(for: inserted) } catch { AppLogger.error("Failed to obtain permanent IDs before background save", error: error, category: AppLogger.service) }
        }

        let insertedObjectIDs = inserted.map { $0.objectID }
        let updatedObjectIDs = context.updatedObjects.map { $0.objectID }
        let deletedObjectIDs = context.deletedObjects.map { $0.objectID }

        backgroundOperationManager.executeHeavyOperation { backgroundContext in
            backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            // Apply updates
            for objectID in updatedObjectIDs {
                _ = try? backgroundContext.existingObject(with: objectID)
            }

            // Apply deletions
            for objectID in deletedObjectIDs {
                if let object = try? backgroundContext.existingObject(with: objectID) {
                    backgroundContext.delete(object)
                }
            }

            // Touch inserted to register them in background context
            for objectID in insertedObjectIDs {
                _ = try? backgroundContext.existingObject(with: objectID)
            }

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

    // Deduplicate ingredients for a single dish within the same context (UI-safe)
    func normalizeIngredients(for dish: Dish) {
        guard let details = dish.ingredientDetails as? Set<IngredientDetail>, !details.isEmpty else { return }
        func norm(_ s: String?) -> String { (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
        var buckets: [String: (keep: IngredientDetail, others: [IngredientDetail], maxQty: Double, minSort: Int16)] = [:]
        for d in details {
            // Drop orphan/invalid immediately
            if d.product == nil || (d.product?.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
                context.delete(d)
                continue
            }
            guard let p = d.product else { continue }
            let unitKey = p.unit?.key ?? (p.unit?.name.map { StaticKeyHelper.stableKey(from: $0) } ?? "")
            let key = StaticKeyHelper.productKey(name: norm(p.name), unitKey: unitKey)
            if var b = buckets[key] {
                // choose deterministic keeper
                let curKeep = b.keep
                let newKeep = (d.sortOrder < curKeep.sortOrder || (d.sortOrder == curKeep.sortOrder && d.objectID.uriRepresentation().absoluteString < curKeep.objectID.uriRepresentation().absoluteString)) ? d : curKeep
                b.keep = newKeep
                b.others.append(d)
                b.maxQty = max(b.maxQty, d.quantity)
                b.minSort = min(b.minSort, d.sortOrder)
                buckets[key] = b
            } else {
                buckets[key] = (keep: d, others: [], maxQty: d.quantity, minSort: d.sortOrder)
            }
        }
        var removed = 0
        for (_, bucket) in buckets {
            var keep = bucket.keep
            // Re-evaluate among all candidates to ensure correct keeper set
            for candidate in [bucket.keep] + bucket.others {
                if candidate.sortOrder < keep.sortOrder || (candidate.sortOrder == keep.sortOrder && candidate.objectID.uriRepresentation().absoluteString < keep.objectID.uriRepresentation().absoluteString) {
                    keep = candidate
                }
            }
            keep.quantity = bucket.maxQty
            keep.sortOrder = bucket.minSort
            for d in bucket.others where d != keep { context.delete(d); removed += 1 }
        }
        if context.hasChanges {
            do { try context.save(); AppLogger.info("Deduped \(removed) ingredient rows for a dish", category: AppLogger.service) } catch {
                AppLogger.error("Failed to dedupe ingredients for a dish", error: error, category: AppLogger.service)
            }
        }
    }
}
