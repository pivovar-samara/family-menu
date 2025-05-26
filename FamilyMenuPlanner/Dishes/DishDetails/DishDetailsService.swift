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
    func createDish() throws -> Dish
    func createIngredient() throws -> IngredientDetail
    func deleteIngredient(ingredient: IngredientDetail)
    func saveChanges() throws
    func rollback()
}

extension DishDetailsService: DishDetailsServiceProtocol {}

class DishDetailsService {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func fetchAllUnits() -> [Unit] {
        let fetchRequest: NSFetchRequest<Unit> = Unit.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Unit.sortOrder, ascending: true)]

        do {
            try context.setQueryGenerationFrom(.current)
            return try context.fetch(fetchRequest)
        } catch {
            print("Error loading units: \(error)")
            return []
        }
    }
    
    func fetchAllMealTypes() -> [MealType] {
        let fetchRequest: NSFetchRequest<MealType> = MealType.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MealType.sortOrder, ascending: true)]

        do {
            try context.setQueryGenerationFrom(.current)
            return try context.fetch(fetchRequest)
        } catch {
            print("Error loading meal types: \(error)")
            return []
        }
    }
    
    func createDish() throws -> Dish {
        try context.setQueryGenerationFrom(.current)
        return Dish(context: context)
    }
    
    func createIngredient() throws -> IngredientDetail {
        try context.setQueryGenerationFrom(.current)
        return IngredientDetail(context: context)
    }
    
    func deleteIngredient(ingredient: IngredientDetail) {
        context.delete(ingredient)
    }
    
    func saveChanges() throws {
        try context.setQueryGenerationFrom(.current)
        try context.save()
    }
    
    func rollback() {
        context.rollback()
    }
}
