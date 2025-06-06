//
//  TestCoreDataStack.swift
//  FamilyMenuPlanner
//
//  Created by Pivovar 63 on 03.06.25.
//

import XCTest
import CoreData
@testable import FamilyMenuPlanner

// MARK: - Core Data Test Stack
class TestCoreDataStack {
    static let shared = TestCoreDataStack()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let modelName = "FamilyMenuPlanner"
        
        guard let modelURL = Bundle(for: type(of: self)).url(forResource: modelName, withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to load Core Data model")
        }
        
        // Always use NSPersistentContainer (not CloudKit version) for tests
        let container = NSPersistentContainer(name: modelName, managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        
        // Ensure CloudKit is completely disabled for tests
        description.cloudKitContainerOptions = nil
        
        // Configure for test environment
        description.setOption(false as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(false as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Failed to load store: \(error)")
            }
        }
        
        // Configure view context for tests
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.undoManager = nil
        container.viewContext.shouldDeleteInaccessibleFaults = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    /// Creates a new background context for concurrent testing
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    /// Clears all data from the test database
    func clearDatabase() {
        let context = viewContext
        
        // Use simple reset approach to avoid memory access issues
        context.performAndWait {
            // Reset clears all managed objects from the context
            context.reset()
        }
    }
    
    /// Legacy method for complex clearing - kept for compatibility
    func clearDatabaseLegacy() {
        let context = viewContext
        
        let entities = persistentContainer.managedObjectModel.entities
        
        for entity in entities {
            guard let entityName = entity.name else { continue }
            
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            
            do {
                // Fetch all objects first
                let objects = try context.fetch(fetchRequest)
                
                // Delete them one by one (batch delete doesn't work with in-memory stores)
                for object in objects {
                    if !object.isDeleted {
                        context.delete(object)
                    }
                }
            } catch {
                print("Failed to clear \(entityName): \(error)")
            }
        }
        
        // Simple save without complex error handling
        do {
            if context.hasChanges {
                try context.save()
            }
        } catch {
            print("Failed to save after clearing database: \(error)")
            context.rollback()
        }
    }
}

