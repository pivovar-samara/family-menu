//
//  EditProductService.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 20.01.25.
//

import CoreData

protocol EditProductServiceProtocol {
    func fetchAllUnits() -> [Unit]
    func saveChanges() throws
    func saveChangesInBackground(completion: @escaping (Result<Void, Error>) -> Void)
    func rollback()
}

extension EditProductService: EditProductServiceProtocol {}

class EditProductService {
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
            let units = try context.fetch(fetchRequest)
            return units
        } catch {
            AppLogger.error("Error loading units", error: error, category: AppLogger.service)
            return []
        }
    }
    
    // Synchronous save for backward compatibility
    func saveChanges() throws {
        AppLogger.info("Saving product changes", category: AppLogger.service)
        try context.save()
        AppLogger.info("Product changes saved successfully", category: AppLogger.service)
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
        if changedObjects.count <= 2 {
            do {
                try saveChanges()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
            return
        }
        
        // For more complex changes, use background context
        AppLogger.info("Saving product changes in background", category: AppLogger.service)
        
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
                AppLogger.info("Product changes saved successfully in background", category: AppLogger.service)
                completion(.success(()))
            case .failure(let error):
                AppLogger.error("Failed to save product changes in background", error: error, category: AppLogger.service)
                completion(.failure(error))
            }
        }
    }
    
    func rollback() {
        context.rollback()
    }
}
