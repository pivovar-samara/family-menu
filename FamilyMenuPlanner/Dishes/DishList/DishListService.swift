//
//  DishListService.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.01.25.
//

import CoreData
import Combine

protocol DishListServiceProtocol {
    func fetchAllDishes()
    func deleteDishes(dishes: [Dish]) throws
    
    var delegate: DishListServiceDelegate? { get set }
}

extension DishListService: DishListServiceProtocol {}

protocol DishListServiceDelegate {
    func serviceDidChangeContent(_ dishes: [Dish])
}

class DishListService: NSObject {
    private let context: NSManagedObjectContext
    private let fetchedResultsController: NSFetchedResultsController<Dish>
    var delegate: DishListServiceDelegate? = nil
    
    // Performance optimization: debounce rapid changes
    private var changeDebounceTimer: Timer?
    private var hasPendingChanges = false
    private let debounceInterval: TimeInterval
    
    init(context: NSManagedObjectContext, debounceInterval: TimeInterval = 0.1) {
        self.context = context
        self.debounceInterval = debounceInterval
        let fetchRequest: NSFetchRequest<Dish> = Dish.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Dish.name, ascending: true)]
        
        // Configure batch fetching for better performance
        CoreDataFetchHelper.configure(fetchRequest, batchSize: CoreDataFetchHelper.standardBatchSize)
        
        self.fetchedResultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        super.init()
        
        self.fetchedResultsController.delegate = self
    }
    
    deinit {
        changeDebounceTimer?.invalidate()
    }
    
    func fetchAllDishes() {
        do {
            try fetchedResultsController.performFetch()
            self.delegate?.serviceDidChangeContent(fetchedResultsController.fetchedObjects ?? [])
        } catch {
            print("Error loading dishes: \(error)")
            self.delegate?.serviceDidChangeContent([])
        }
    }
    
    func deleteDishes(dishes: [Dish]) throws {
        for dish in dishes {
            context.delete(dish)
        }
        try context.save()
    }
    
    // MARK: - Performance Optimization Helpers
    
    private func scheduleDataRefresh() {
        // Cancel existing timer if present
        changeDebounceTimer?.invalidate()
        hasPendingChanges = true
        
        // Schedule new timer to batch multiple rapid changes
        changeDebounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            self?.performDataRefresh()
        }
    }
    
    private func performDataRefresh() {
        guard hasPendingChanges else { return }
        
        hasPendingChanges = false
        changeDebounceTimer = nil
        
        // Ensure we're on the main queue for UI updates
        DispatchQueue.main.async { [weak self] in
            if let updatedDishes = self?.fetchedResultsController.fetchedObjects {
                self?.delegate?.serviceDidChangeContent(updatedDishes)
            }
        }
    }
}

extension DishListService: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Use debouncing to prevent excessive UI updates during rapid changes
        scheduleDataRefresh()
    }
}
