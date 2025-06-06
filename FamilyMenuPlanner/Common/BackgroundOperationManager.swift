//
//  BackgroundOperationManager.swift
//  FamilyMenuPlanner
//
//  Created by Assistant on 27.01.25.
//

import CoreData
import Foundation
import os

// MARK: - Protocol for BackgroundOperationManager
protocol BackgroundOperationManagerProtocol {
    func executeHeavyOperation<T>(
        operation: @escaping (NSManagedObjectContext) throws -> T,
        completion: @escaping (Result<T, Error>) -> Void
    )
    
    func executeBatchSaveOperation(
        objectIDs: [NSManagedObjectID],
        operation: @escaping ([NSManagedObject]) throws -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    )
    
    func executeBulkOperation(
        operation: @escaping (NSManagedObjectContext) throws -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    )
    
    func executeHeavyFetch<T: NSManagedObject, R>(
        fetchRequest: NSFetchRequest<T>,
        transform: @escaping ([T]) -> R,
        completion: @escaping (Result<R, Error>) -> Void
    )
    
    func executeTransaction(
        operations: [(NSManagedObjectContext) throws -> Void],
        completion: @escaping (Result<Void, Error>) -> Void
    )
}

/// Manager for handling heavy operations in background contexts
/// Provides a centralized way to execute CoreData operations that might block the UI
final class BackgroundOperationManager: BackgroundOperationManagerProtocol {
    
    // MARK: - Singleton
    static let shared = BackgroundOperationManager()
    
    // MARK: - Private Properties
    private let persistenceController: PersistenceController
    private let logger = Logger(subsystem: "com.familymenuplanner", category: "BackgroundOperations")
    
    // Queue for background operations
    private let backgroundQueue = DispatchQueue(label: "com.familymenuplanner.background", qos: .utility)
    
    // MARK: - Initialization
    private init(persistenceController: PersistenceController = PersistenceController.shared) {
        self.persistenceController = persistenceController
    }
    
    // Internal initializer for testing
    internal init(testPersistenceController: PersistenceController) {
        self.persistenceController = testPersistenceController
    }
    
    // MARK: - Public Interface
    
    /// Executes a heavy operation in a background context
    /// - Parameters:
    ///   - operation: The operation to execute in background context
    ///   - completion: Completion handler called on main queue with result
    func executeHeavyOperation<T>(
        operation: @escaping (NSManagedObjectContext) throws -> T,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        backgroundQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(BackgroundOperationError.managerDeallocated))
                }
                return
            }
            
            let backgroundContext = self.persistenceController.newBackgroundContext()
            
            do {
                let result = try backgroundContext.performAndWait {
                    try operation(backgroundContext)
                }
                
                DispatchQueue.main.async {
                    completion(.success(result))
                }
                
                self.logger.info("Heavy operation completed successfully")
            } catch {
                self.logger.error("Heavy operation failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Executes a batch save operation in background context
    /// - Parameters:
    ///   - objectIDs: Array of NSManagedObjectID to transfer to background context
    ///   - operation: The operation to execute on the transferred objects
    ///   - completion: Completion handler called on main queue
    func executeBatchSaveOperation(
        objectIDs: [NSManagedObjectID],
        operation: @escaping ([NSManagedObject]) throws -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        backgroundQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(BackgroundOperationError.managerDeallocated))
                }
                return
            }
            
            let backgroundContext = self.persistenceController.newBackgroundContext()
            
            do {
                try backgroundContext.performAndWait {
                    // Transfer objects to background context
                    let backgroundObjects = objectIDs.compactMap { objectID in
                        try? backgroundContext.existingObject(with: objectID)
                    }
                    
                    // Execute the operation
                    try operation(backgroundObjects)
                    
                    // Save if there are changes
                    if backgroundContext.hasChanges {
                        try backgroundContext.save()
                    }
                }
                
                DispatchQueue.main.async {
                    completion(.success(()))
                }
                
                self.logger.info("Batch save operation completed successfully for \(objectIDs.count) objects")
            } catch {
                self.logger.error("Batch save operation failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Executes a bulk data operation (like bulk insert or delete)
    /// - Parameters:
    ///   - operation: The bulk operation to execute
    ///   - completion: Completion handler called on main queue
    func executeBulkOperation(
        operation: @escaping (NSManagedObjectContext) throws -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        backgroundQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(BackgroundOperationError.managerDeallocated))
                }
                return
            }
            
            let backgroundContext = self.persistenceController.newBackgroundContext()
            
            do {
                try backgroundContext.performAndWait {
                    try operation(backgroundContext)
                    
                    if backgroundContext.hasChanges {
                        try backgroundContext.save()
                    }
                }
                
                DispatchQueue.main.async {
                    completion(.success(()))
                }
                
                self.logger.info("Bulk operation completed successfully")
            } catch {
                self.logger.error("Bulk operation failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Executes a heavy fetch operation in background context
    /// - Parameters:
    ///   - fetchRequest: The fetch request to execute
    ///   - transform: Optional transform function to convert results
    ///   - completion: Completion handler called on main queue with results
    func executeHeavyFetch<T: NSManagedObject, R>(
        fetchRequest: NSFetchRequest<T>,
        transform: @escaping ([T]) -> R = { $0 },
        completion: @escaping (Result<R, Error>) -> Void
    ) {
        backgroundQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(BackgroundOperationError.managerDeallocated))
                }
                return
            }
            
            let backgroundContext = self.persistenceController.newBackgroundContext()
            
            do {
                let results = try backgroundContext.performAndWait {
                    try backgroundContext.fetch(fetchRequest)
                }
                
                let transformed = transform(results)
                
                DispatchQueue.main.async {
                    completion(.success(transformed))
                }
                
                self.logger.info("Heavy fetch operation completed successfully, fetched \(results.count) objects")
            } catch {
                self.logger.error("Heavy fetch operation failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Executes multiple operations as a single transaction in background context
    /// - Parameters:
    ///   - operations: Array of operations to execute
    ///   - completion: Completion handler called on main queue
    func executeTransaction(
        operations: [(NSManagedObjectContext) throws -> Void],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        backgroundQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(BackgroundOperationError.managerDeallocated))
                }
                return
            }
            
            let backgroundContext = self.persistenceController.newBackgroundContext()
            
            do {
                try backgroundContext.performAndWait {
                    // Execute all operations
                    for operation in operations {
                        try operation(backgroundContext)
                    }
                    
                    // Save if there are changes
                    if backgroundContext.hasChanges {
                        try backgroundContext.save()
                    }
                }
                
                DispatchQueue.main.async {
                    completion(.success(()))
                }
                
                self.logger.info("Transaction with \(operations.count) operations completed successfully")
            } catch {
                self.logger.error("Transaction failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}

// MARK: - Error Types
enum BackgroundOperationError: LocalizedError {
    case managerDeallocated
    case contextNotAvailable
    case operationCancelled
    
    var errorDescription: String? {
        switch self {
        case .managerDeallocated:
            return "Background operation manager was deallocated"
        case .contextNotAvailable:
            return "Background context is not available"
        case .operationCancelled:
            return "Background operation was cancelled"
        }
    }
} 