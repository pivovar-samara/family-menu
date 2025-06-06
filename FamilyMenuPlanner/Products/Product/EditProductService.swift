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
    func rollback()
}

extension EditProductService: EditProductServiceProtocol {}

class EditProductService {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
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
    
    func saveChanges() throws {
        AppLogger.info("Saving product changes", category: AppLogger.service)
        try context.save()
        AppLogger.info("Product changes saved successfully", category: AppLogger.service)
    }
    
    func rollback() {
        context.rollback()
    }
}
