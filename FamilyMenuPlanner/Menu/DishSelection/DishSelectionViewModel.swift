//
//  DishSelectionViewModel.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 18.01.25.
//

import Foundation
import SwiftUI

class DishSelectionViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedDish: Dish? = nil
    
    @Published var currentDish: Dish? // Currently selected dish for this day and meal type
    @Published var mealType: String // Meal type for filtering dishes
    @Published var onDishSelected: (Dish) -> Void
    
    private let dishSelectionService: DishSelectionService
    
    init(currentDish: Dish?, mealType: String, dishSelectionService: DishSelectionService, onDishSelected: @escaping (Dish) -> Void) {
        self.currentDish = currentDish
        self.mealType = mealType
        self.onDishSelected = onDishSelected
        self.dishSelectionService = dishSelectionService
    }
    
    func rollback() {
        dishSelectionService.rollback()
    }
    
    /// Splits dishes into two sections: those matching the meal type and others.
    func splitDishes() -> (dishesForMealType: [Dish], otherDishes: [Dish]) {
        var dishesForMealType: [Dish] = []
        var otherDishes: [Dish] = []

        for dish in dishSelectionService.fetchAllDishes() {
            // Filter by search text
            let matchesSearch = searchText.isEmpty || (dish.name?.localizedCaseInsensitiveContains(searchText) ?? false)
            
            guard matchesSearch else { continue }
            
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
