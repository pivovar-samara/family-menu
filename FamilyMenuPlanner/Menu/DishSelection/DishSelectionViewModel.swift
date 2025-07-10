//
//  DishSelectionViewModel.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 18.01.25.
//

import Foundation
import SwiftUI
import Combine

class DishSelectionViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedDishes: [Dish] = []
    @Published var filteredDishes: [Dish] = []
    
    @Published var mealType: String // Meal type for filtering dishes
    @Published var onDishesSelected: ([Dish]) -> Void
    
    // Use SearchOptimizationHelper for better performance
    private let searchHelper: SearchOptimizationHelper<Dish>
    private var allDishes: [Dish] = [] {
        didSet {
            searchHelper.updateItems(allDishes)
        }
    }
    
    private let dishSelectionService: DishSelectionServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(selectedDishes: [Dish], mealType: String, dishSelectionService: DishSelectionServiceProtocol, onDishesSelected: @escaping ([Dish]) -> Void) {
        self.selectedDishes = selectedDishes
        self.mealType = mealType
        self.onDishesSelected = onDishesSelected
        self.dishSelectionService = dishSelectionService
        
        // Initialize search helper with proper filter predicate
        self.searchHelper = SearchOptimizationHelper<Dish> { dish, searchText in
            guard let name = dish.name else { return false }
            return name.localizedCaseInsensitiveContains(searchText)
        }
        
        // Setup bindings between ViewModel and SearchHelper
        setupSearchBindings()
        
        // Load initial data
        loadDishes()
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
    
    private func loadDishes() {
        allDishes = dishSelectionService.fetchAllDishes()
    }
    
    func rollback() {
        dishSelectionService.rollback()
    }
    
    // Ensure unsaved changes in the editing context are reverted if the view model is deallocated without an explicit cancel.
    deinit {
        rollback()
    }
    
    /// Splits dishes into two sections: those matching the meal type and others.
    /// Now uses pre-filtered dishes from SearchOptimizationHelper for better performance.
    func splitDishes() -> (dishesForMealType: [Dish], otherDishes: [Dish]) {
        var dishesForMealType: [Dish] = []
        var otherDishes: [Dish] = []

        for dish in filteredDishes {
            // Determine the section based on meal type
            if let mealTypes = dish.mealTypes as? Set<MealType>, mealTypes.contains(where: { $0.name == mealType }) {
                dishesForMealType.append(dish)
            } else {
                otherDishes.append(dish)
            }
        }

        return (dishesForMealType, otherDishes)
    }
}
