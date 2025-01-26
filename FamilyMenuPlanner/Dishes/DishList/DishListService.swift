//
//  DishListService.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.01.25.
//

import CoreData

protocol DishListServiceDelegate {
    func serviceDidChangeContent(_ dishes: [Dish])
}

class DishListService: NSObject {
    private let context: NSManagedObjectContext
    private let fetchedResultsController: NSFetchedResultsController<Dish>
    var delegate: DishListServiceDelegate? = nil
    
    init(context: NSManagedObjectContext) {
        self.context = context
        let fetchRequest: NSFetchRequest<Dish> = Dish.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Dish.name, ascending: true)]
        self.fetchedResultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        super.init()
        
        self.fetchedResultsController.delegate = self
    }
    
    func fetchAllDishes() {
        do {
            try context.setQueryGenerationFrom(.current)
            try fetchedResultsController.performFetch()
            self.delegate?.serviceDidChangeContent(fetchedResultsController.fetchedObjects ?? [])
        } catch {
            print("Error loading dishes: \(error)")
            self.delegate?.serviceDidChangeContent([])
        }
    }
    
    func deleteDishes(dishes: [Dish]) throws {
        try context.setQueryGenerationFrom(.current)
        for dish in dishes {
            context.delete(dish)
        }
        try context.save()
    }
}

extension DishListService: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if let updatedDishes = controller.fetchedObjects as? [Dish] {
            DispatchQueue.main.async {
                self.delegate?.serviceDidChangeContent(updatedDishes)
            }
        }
    }
}
