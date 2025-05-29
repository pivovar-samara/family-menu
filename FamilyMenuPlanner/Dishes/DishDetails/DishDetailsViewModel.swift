//
//  DishDetailsViewModel.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.01.25.
//

import Foundation
import SwiftUI
import Combine

class DishDetailsViewModel: ObservableObject {
    @Published var units: [Unit]
    @Published var allMealTypes: [MealType]
    @Published var descriptionText: String = ""
    @Published var selectedMealTypes: Set<MealType> = []
    @Published var validationError: String?
    @Published var currentAlert: AlertItem? = nil
    @Published var showProductSelection = false
    @Published var selectedIngredient: IngredientDetail?
    @Published var selectedIngredients: [IngredientDetail] = []
    @Published var isAddingIngredient: Bool = false
    @Published var dish: Dish?
    
    private let dishDetailsService: DishDetailsServiceProtocol
    private let alertManager = AlertQueueManager()
    
    init(dishDetailsService: DishDetailsServiceProtocol, dish: Dish? = nil) {
        self.dishDetailsService = dishDetailsService
        self.dish = dish
        self.units = dishDetailsService.fetchAllUnits()
        self.allMealTypes = dishDetailsService.fetchAllMealTypes()
        alertManager.$currentAlert
                    .receive(on: RunLoop.main)
                    .assign(to: &$currentAlert)
    }
    
    func loadDish() {
        guard dish == nil else { return }
        
        do {
            try dish = dishDetailsService.createDish()
        } catch {
            print("Failed to create a new dish: \(error)")
        }
    }
    
    func loadIngredients() {
        if let ingredientDetails = dish?.ingredientDetails as? Set<IngredientDetail> {
            selectedIngredients = Array(ingredientDetails).sorted { $0.sortOrder < $1.sortOrder }
        }
    }
    
    func loadSelectedMealTypes() {
        if let mealTypes = dish?.mealTypes as? Set<MealType> {
            selectedMealTypes = mealTypes
        }
    }

    func addIngredient(for product: Product) {
        do {
            let newIngredient = try dishDetailsService.createIngredient()
            newIngredient.dish = dish
            newIngredient.product = product
            newIngredient.quantity = 1.0
            newIngredient.sortOrder = (selectedIngredients.last?.sortOrder ?? 0) + 1

            selectedIngredients.append(newIngredient)
        } catch {
            print("Failed to create a new ingredient: \(error)")
        }
    }

    func moveIngredient(from source: IndexSet, to destination: Int) {
        selectedIngredients.move(fromOffsets: source, toOffset: destination)

        for (index, ingredient) in selectedIngredients.enumerated() {
            ingredient.sortOrder = Int16(index)
        }
    }
    
    func deleteIngredient(at offsets: IndexSet) {
        for index in offsets {
            let detail = selectedIngredients[index]
            dishDetailsService.deleteIngredient(ingredient: detail)
        }
        selectedIngredients.remove(atOffsets: offsets)
    }
    
    func toggleMealTypeSelection(_ mealType: MealType) {
        if selectedMealTypes.contains(mealType) {
            selectedMealTypes.remove(mealType)
            if let dish = dish {
                mealType.removeFromDishes(dish)
            }
        } else {
            selectedMealTypes.insert(mealType)
            if let dish = dish {
                mealType.addToDishes(dish)
            }
        }
    }
    
    func saveChanges(onSuccess: ()->Void) {
        do {
            guard self.validate(), validationError == nil else {
                return
            }
            try dishDetailsService.saveChanges()
            onSuccess()
        } catch let error as NSError {
            enqueueAlert(title: "Error", message: error.localizedDescription)
        } catch {
            enqueueAlert(title: "Error", message: "Failed to save changes. Please try again.")
        }
    }
    
    func rollback() {
        dishDetailsService.rollback()
    }

    // Validate dish data
    private func validate() -> Bool {
        // Clear previous errors
        validationError = nil

        // Validate name
        if dish?.name?.isEmpty ?? true {
            validationError = "Dish name cannot be empty.".localized()
            return false
        }

        // Validate ingredients
        if selectedIngredients.isEmpty {
            validationError = "Dish must have at least one ingredient.".localized()
            return false
        }
        
        // Validate meal type
        if selectedMealTypes.isEmpty {
            validationError = "Dish must have at least one meal type.".localized()
            return false
        }

        return true
    }
    
    func enqueueAlert(title: String, message: String, action: (() -> Void)? = nil) {
        let alert = AlertItem(title: title.localized(), message: message.localized(), action: action)
        alertManager.enqueue(alert: alert)
    }
    
    func dismissAlert() {
        alertManager.dismissCurrentAlert()
    }
}
