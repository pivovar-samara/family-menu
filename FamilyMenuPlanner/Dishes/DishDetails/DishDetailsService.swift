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
        return dish
    }
    
    func createIngredient() throws -> IngredientDetail {
        let ingredient = IngredientDetail(context: context)
        return ingredient
    }
    
    func deleteIngredient(ingredient: IngredientDetail) {
        context.delete(ingredient)
    }
    
    func saveChanges() throws {
        try context.save()
    }
    
    func rollback() {
        context.rollback()
    }
}
