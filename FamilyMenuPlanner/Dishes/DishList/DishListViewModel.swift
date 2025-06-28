//
//  DishListViewModel.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.01.25.
//

import Foundation
import SwiftUI
import Combine

class DishListViewModel: ObservableObject {
    @Published var selectedDish: Dish? = nil // For editing
    @Published var isAddingNewDish: Bool = false
    @Published var currentAlert: AlertItem? = nil
    
    // Published properties for search functionality
    @Published var searchText: String = ""
    @Published var filteredDishes: [Dish] = []
    
    // Use SearchOptimizationHelper for better performance
    private let searchHelper: SearchOptimizationHelper<Dish>
    
    private(set) var allDishes: [Dish] = [] {
        didSet {
            searchHelper.updateItems(allDishes)
        }
    }
    
    private var dishListService: DishListServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private let alertManager = AlertQueueManager()

    init(dishListService: DishListServiceProtocol) {
        self.dishListService = dishListService
        
        // Initialize search helper with proper filter predicate
        self.searchHelper = SearchOptimizationHelper<Dish> { dish, searchText in
            guard let name = dish.name else { return false }
            let matchesName = name.localizedCaseInsensitiveContains(searchText)
            let matchesDetails = dish.details?.localizedCaseInsensitiveContains(searchText) ?? false
            let matchesCategory = dish.category?.name?.localizedCaseInsensitiveContains(searchText) ?? false
            
            // Check meal types
            let matchesMealType: Bool = {
                guard let mealTypes = dish.mealTypes as? Set<MealType> else { return false }
                return mealTypes.contains { mealType in
                    mealType.name?.localizedCaseInsensitiveContains(searchText) ?? false
                }
            }()
            
            return matchesName || matchesDetails || matchesCategory || matchesMealType
        }
        
        // Setup bindings between ViewModel and SearchHelper
        setupSearchBindings()
        
        self.dishListService.delegate = self
        alertManager.$currentAlert
                    .receive(on: RunLoop.main)
                    .assign(to: &$currentAlert)
    }
    
    private func setupSearchBindings() {
        // Forward search text changes to helper
        $searchText
            .assign(to: \.searchText, on: searchHelper)
            .store(in: &cancellables)
        
        // Forward filtered results back to ViewModel
        searchHelper.$filteredItems
            .receive(on: RunLoop.main)
            .assign(to: \.filteredDishes, on: self)
            .store(in: &cancellables)
    }
    
    func loadDishes() {
        dishListService.fetchAllDishes()
    }
    
    func deleteDishes(at offsets: IndexSet) {
        do {
            var dishesToDelete: [Dish] = []
            for index in offsets {
                let dish = filteredDishes[index]
                dishesToDelete.append(dish)
                if let index = allDishes.firstIndex(of: dish) {
                    allDishes.remove(at: index)
                }
            }
            try dishListService.deleteDishes(dishes: dishesToDelete)
        } catch {
            enqueueAlert(title: "Error", message: "Failed to delete dishes. Please try again.")
        }
    }

    func enqueueAlert(title: String, message: String, action: (() -> Void)? = nil) {
        let alert = AlertItem(title: title.localized(), message: message.localized(), action: action)
        alertManager.enqueue(alert: alert)
    }
    
    func dismissAlert() {
        alertManager.dismissCurrentAlert()
    }
}

extension DishListViewModel: DishListServiceDelegate {
    func serviceDidChangeContent(_ dishes: [Dish]) {
        self.allDishes = dishes
    }
}
