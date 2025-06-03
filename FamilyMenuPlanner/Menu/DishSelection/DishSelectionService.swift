//
//  DishSelectionService.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 18.01.25.
//


import CoreData

protocol DishSelectionServiceProtocol {
    func fetchAllDishes() -> [Dish]
    func rollback()
}

extension DishSelectionService: DishSelectionServiceProtocol {}

class DishSelectionService {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func rollback() {
        context.rollback()
    }
    
    func fetchAllDishes() -> [Dish] {
        let fetchRequest: NSFetchRequest<Dish> = Dish.fetchRequest()

        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Error loading dishes: \(error)")
            return []
        }
    }
}
