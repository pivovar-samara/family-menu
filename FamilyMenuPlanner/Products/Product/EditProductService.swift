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

        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Error loading units: \(error)")
            return []
        }
    }
    
    func saveChanges() throws {
        try context.save()
    }
    
    func rollback() {
        context.rollback()
    }
}
