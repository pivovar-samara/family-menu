//
//  CoreDataFetchHelper.swift
//  FamilyMenuPlanner
//
//  Created by Assistant on 27.01.25.
//

import CoreData

/// Helper class to configure fetch requests with optimal batch sizes for better performance
struct CoreDataFetchHelper {
    /// Standard batch size for typical list operations
    static let standardBatchSize = 20
    
    /// Smaller batch size for UI components with limited visible items
    static let smallBatchSize = 10
    
    /// Larger batch size for bulk operations
    static let largeBatchSize = 50
    
    /// Configures a fetch request with optimal batch size and performance settings
    /// - Parameters:
    ///   - fetchRequest: The fetch request to configure
    ///   - batchSize: The batch size to use (defaults to standardBatchSize)
    ///   - includesSubentities: Whether to include subentities (defaults to false for better performance)
    static func configure<T: NSManagedObject>(
        _ fetchRequest: NSFetchRequest<T>,
        batchSize: Int = standardBatchSize,
        includesSubentities: Bool = false
    ) {
        fetchRequest.fetchBatchSize = batchSize
        fetchRequest.includesSubentities = includesSubentities
        fetchRequest.returnsObjectsAsFaults = true // Enables faulting for better memory management
    }
    
    /// Configures a fetch request optimized for large datasets
    /// - Parameter fetchRequest: The fetch request to configure
    static func configureForLargeDataset<T: NSManagedObject>(_ fetchRequest: NSFetchRequest<T>) {
        configure(fetchRequest, batchSize: largeBatchSize)
    }
    
    /// Configures a fetch request optimized for small UI lists (like pickers, dropdowns)
    /// - Parameter fetchRequest: The fetch request to configure
    static func configureForSmallList<T: NSManagedObject>(_ fetchRequest: NSFetchRequest<T>) {
        // For small static reference lists (Units, MealTypes, DishCategories) we prefer
        // fully realized objects to avoid UI seeing empty attributes when objects are
        // kept in caches across CloudKit merges. Returning faults here can result in
        // inaccessible faults when query generations shift after sync. Loading full
        // property values is cheap for these tiny datasets and removes that class of bugs.
        configure(fetchRequest, batchSize: smallBatchSize)
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.includesPropertyValues = true
    }
} 