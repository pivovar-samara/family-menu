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
    // Use @Published properties that observe the cache for automatic UI updates
    @Published var units: [Unit] = []
    @Published var allMealTypes: [MealType] = []
    @Published var allDishCategories: [DishCategory] = []
    
    @Published var selectedCategory: DishCategory?
    @Published var descriptionText: String = ""
    @Published var selectedMealTypes: Set<MealType> = []
    @Published var validationError: String?
    @Published var currentAlert: AlertItem? = nil
    @Published var showProductSelection = false
    @Published var selectedIngredient: IngredientDetail?
    @Published var selectedIngredients: [IngredientDetail] = []
    @Published var isAddingIngredient: Bool = false
    @Published var dish: Dish?
    @Published var isCreatingNewDish: Bool = false
    
    private let dishDetailsService: DishDetailsServiceProtocol
    private let alertManager = AlertQueueManager()
    private var cancellables = Set<AnyCancellable>()
    
    init(dishDetailsService: DishDetailsServiceProtocol, dish: Dish? = nil) {
        self.dishDetailsService = dishDetailsService
        self.dish = dish
        self.isCreatingNewDish = dish == nil
        
        // Load initial static data
        self.units = StaticDataCacheManager.shared.getUnits()
        self.allMealTypes = StaticDataCacheManager.shared.getMealTypes()
        self.allDishCategories = StaticDataCacheManager.shared.getDishCategories()
        
        // Observe cache manager for automatic updates
        StaticDataCacheManager.shared.$units
            .receive(on: DispatchQueue.main)
            .assign(to: \.units, on: self)
            .store(in: &cancellables)
            
        StaticDataCacheManager.shared.$mealTypes
            .receive(on: DispatchQueue.main)
            .assign(to: \.allMealTypes, on: self)
            .store(in: &cancellables)
            
        StaticDataCacheManager.shared.$dishCategories
            .receive(on: DispatchQueue.main)
            .assign(to: \.allDishCategories, on: self)
            .store(in: &cancellables)
        
        // Load dish-specific data after static data is available
        if let dish = dish {
            self.selectedCategory = dish.category
            if let mealTypes = dish.mealTypes as? Set<MealType> {
                self.selectedMealTypes = mealTypes
            }
        }
        
        alertManager.$currentAlert
                    .receive(on: RunLoop.main)
                    .assign(to: &$currentAlert)
        
        // Clean up any existing NaN data immediately to prevent CoreGraphics errors
        performDataValidationCleanup()
    }
    
    /// Performs comprehensive data validation and cleanup to prevent CoreGraphics NaN errors
    private func performDataValidationCleanup() {
        guard let dish = dish else { return }
        
        // Validate and fix ingredient quantities that may have been corrupted
        if let ingredientDetails = dish.ingredientDetails as? Set<IngredientDetail> {
            var hasChanges = false
            
            for detail in ingredientDetails {
                if detail.quantity.isNaN || detail.quantity.isInfinite || detail.quantity < 0 {
                    let oldValue = detail.quantity
                    detail.quantity = 0.0
                    hasChanges = true
                    AppLogger.warning("Fixed invalid quantity value (\(oldValue)) in ingredient detail for dish: \(dish.name ?? "unknown")", category: AppLogger.viewModel)
                }
            }
            
            // Save changes if we fixed any NaN values
            if hasChanges {
                do {
                    try dishDetailsService.saveChanges()
                    AppLogger.info("Saved ingredient quantity fixes to prevent CoreGraphics errors", category: AppLogger.viewModel)
                } catch {
                    AppLogger.error("Failed to save ingredient quantity fixes", error: error, category: AppLogger.viewModel)
                }
            }
        }
    }
    
    func loadDish() {
        guard dish == nil else { return }
        
        do {
            try dish = dishDetailsService.createDish()
        } catch {
            AppLogger.error("Failed to create a new dish", error: error, category: AppLogger.viewModel)
        }
    }
    
    func loadIngredients() {
        if let ingredientDetails = dish?.ingredientDetails as? Set<IngredientDetail> {
            // Validate and fix any NaN quantities to prevent CoreGraphics errors
            for detail in ingredientDetails {
                if detail.quantity.isNaN || detail.quantity.isInfinite {
                    detail.quantity = 0.0
                    AppLogger.warning("Fixed NaN/Infinite quantity value in ingredient detail", category: AppLogger.viewModel)
                }
            }
            selectedIngredients = Array(ingredientDetails).sorted { $0.sortOrder < $1.sortOrder }
        }
    }
    
    func loadSelectedMealTypes() {
        // Data is already loaded in init, but refresh if dish changed
        if let dish = dish, let mealTypes = dish.mealTypes as? Set<MealType> {
            selectedMealTypes = mealTypes
        }
    }
    
    func loadSelectedCategory() {
        // Data is already loaded in init, but refresh if dish changed
        if let dish = dish {
            selectedCategory = dish.category
        }
    }
    
    func setDishCategory(_ category: DishCategory?) {
        selectedCategory = category
        dish?.category = category
    }

    func addIngredient(product: Product, quantity: Double) {
        guard let dish = dish else { return }
        
        // Validate quantity to prevent NaN values that cause CoreGraphics errors
        let validQuantity = validateQuantity(quantity)
        
        do {
            let ingredientDetail = try dishDetailsService.createIngredient()
            ingredientDetail.dish = dish
            ingredientDetail.product = product
            ingredientDetail.quantity = validQuantity
            
            try dishDetailsService.saveChanges()
            // Refresh ingredients list
            loadIngredients()
        } catch {
            AppLogger.error("Failed to create a new ingredient", error: error, category: AppLogger.viewModel)
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
    
    // MARK: - Helper Methods
    
    /// Validates and sanitizes quantity values to prevent NaN/Infinite values that cause CoreGraphics errors
    private func validateQuantity(_ quantity: Double) -> Double {
        if quantity.isNaN || quantity.isInfinite {
            return 0.0
        }
        return max(0.0, quantity)
    }
    
    /// Safely updates ingredient quantity with validation to prevent CoreGraphics errors
    func updateIngredientQuantity(_ ingredient: IngredientDetail, quantity: Double) {
        let validQuantity = validateQuantity(quantity)
        ingredient.quantity = validQuantity
    }
}
