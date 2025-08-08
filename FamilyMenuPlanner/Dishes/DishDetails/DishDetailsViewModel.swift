//
//  DishDetailsViewModel.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.01.25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Ingredient Sort Option
enum IngredientSortOption: String, CaseIterable {
    case custom = "Default"
    case alphabetical = "A-Z"
    case reverseAlphabetical = "Z-A"
    case quantityHighToLow = "Quantity: High to Low"
    case quantityLowToHigh = "Quantity: Low to High"
    case unitType = "By Unit Type"
    
    var icon: String {
        switch self {
        case .custom: return "list.number"
        case .alphabetical: return "textformat.abc"
        case .reverseAlphabetical: return "textformat"
        case .quantityHighToLow: return "arrow.down.square"
        case .quantityLowToHigh: return "arrow.up.square"
        case .unitType: return "scale.3d"
        }
    }
}

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
    @Published var currentSortOption: IngredientSortOption = .custom
    
    private let dishDetailsService: DishDetailsServiceProtocol
    private let alertManager = AlertQueueManager()
    private var cancellables = Set<AnyCancellable>()
    private let onDismiss: ((Bool) -> Void)?
    private var hasSavedChanges = false
    
    // UserDefaults key for storing ingredient sort preference
    private static let ingredientSortPreferenceKey = "IngredientSortPreference"
    
    init(dishDetailsService: DishDetailsServiceProtocol, dish: Dish? = nil, onDismiss: ((Bool) -> Void)? = nil) {
        self.dishDetailsService = dishDetailsService
        self.dish = dish
        self.isCreatingNewDish = dish == nil
        self.onDismiss = onDismiss
        
        // Load persistent sort preference
        loadSortPreference()
        
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
    
    /// Loads the persistent sort preference from UserDefaults
    private func loadSortPreference() {
        let savedSortOption = UserDefaults.standard.string(forKey: Self.ingredientSortPreferenceKey) ?? IngredientSortOption.custom.rawValue
        currentSortOption = IngredientSortOption(rawValue: savedSortOption) ?? .custom
        AppLogger.info("Loaded ingredient sort preference: \(currentSortOption.rawValue)", category: AppLogger.viewModel)
    }
    
    /// Saves the current sort preference to UserDefaults
    private func saveSortPreference() {
        UserDefaults.standard.set(currentSortOption.rawValue, forKey: Self.ingredientSortPreferenceKey)
        AppLogger.info("Saved ingredient sort preference: \(currentSortOption.rawValue)", category: AppLogger.viewModel)
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
            
            // Apply the current sort preference to the loaded ingredients
            applySortPreference()
        }
    }
    
    /// Applies the current sort preference to the selected ingredients without saving the preference
    private func applySortPreference() {
        switch currentSortOption {
        case .custom:
            selectedIngredients.sort { $0.sortOrder < $1.sortOrder }
        case .alphabetical:
            selectedIngredients.sort { 
                ($0.product?.name ?? "").localizedCaseInsensitiveCompare($1.product?.name ?? "") == .orderedAscending 
            }
        case .reverseAlphabetical:
            selectedIngredients.sort { 
                ($0.product?.name ?? "").localizedCaseInsensitiveCompare($1.product?.name ?? "") == .orderedDescending 
            }
        case .quantityHighToLow:
            selectedIngredients.sort { $0.quantity > $1.quantity }
        case .quantityLowToHigh:
            selectedIngredients.sort { $0.quantity < $1.quantity }
        case .unitType:
            selectedIngredients.sort { 
                let unit1 = $0.product?.unit?.name ?? ""
                let unit2 = $1.product?.unit?.name ?? ""
                if unit1 == unit2 {
                    return ($0.product?.name ?? "").localizedCaseInsensitiveCompare($1.product?.name ?? "") == .orderedAscending
                }
                return unit1.localizedCaseInsensitiveCompare(unit2) == .orderedAscending
            }
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
        
        // Check if dish is still valid before setting category
        guard let dish = ensureValidDish() else {
            AppLogger.warning("Attempted to set category on deleted dish entity", category: AppLogger.viewModel)
            return
        }
        
        dish.category = category
    }

    func addIngredient(product: Product, quantity: Double) {
        guard let dish = ensureValidDish() else {
            enqueueAlert(title: "Error", message: "Unable to add ingredient. Please try creating the dish again.")
            return
        }
        
        // Validate quantity to prevent NaN values that cause CoreGraphics errors
        let validQuantity = validateQuantity(quantity)
        
        do {
            let ingredientDetail = try dishDetailsService.createIngredient()
            ingredientDetail.dish = dish
            ingredientDetail.product = product
            ingredientDetail.quantity = validQuantity
            
            // Set sortOrder to maximum from existing ingredients + 1 to ensure new ingredient appears at the end
            let maxSortOrder = selectedIngredients.map { $0.sortOrder }.max() ?? -1
            ingredientDetail.sortOrder = maxSortOrder + 1
            
            try dishDetailsService.saveChanges()
            // Refresh ingredients list
            loadIngredients()
        } catch {
            AppLogger.error("Failed to create a new ingredient", error: error, category: AppLogger.viewModel)
        }
    }

    /// Adds multiple ingredients at once. Each product becomes a new ingredient detail with quantity 1.0 by default.
    func addIngredients(products: [Product], defaultQuantity: Double = 1.0) {
        guard let dish = ensureValidDish() else {
            enqueueAlert(title: "Error", message: "Unable to add ingredient. Please try creating the dish again.")
            return
        }
        let validQuantity = validateQuantity(defaultQuantity)
        do {
            var nextSortOrder: Int16 = (selectedIngredients.map { $0.sortOrder }.max() ?? -1) + 1
            for product in products {
                let ingredientDetail = try dishDetailsService.createIngredient()
                ingredientDetail.dish = dish
                ingredientDetail.product = product
                ingredientDetail.quantity = validQuantity
                ingredientDetail.sortOrder = nextSortOrder
                nextSortOrder += 1
            }
            try dishDetailsService.saveChanges()
            loadIngredients()
        } catch {
            AppLogger.error("Failed to create ingredients in batch", error: error, category: AppLogger.viewModel)
        }
    }

    func sortIngredients(by sortOption: IngredientSortOption) {
        // Update the current sort option and save it persistently (UI thread)
        currentSortOption = sortOption
        saveSortPreference()
        
        // Immediately update the UI with sorted ingredients (this is fast)
        applySortPreference()
        
        // For custom sort, we need to persist the new order to Core Data
        // Do this on a background thread to avoid UI freezing
        if sortOption == .custom {
            // Update the sort orders immediately in the current context (fast UI update)
            for (index, ingredient) in selectedIngredients.enumerated() {
                ingredient.sortOrder = Int16(index)
            }
            
            // Persist changes in the background to avoid UI freezing
            updateSortOrderInBackground()
        }
    }
    
    /// Persists the current ingredient sort order changes in Core Data on a background thread
    private func updateSortOrderInBackground() {
        // Use the existing background operation manager pattern to save changes
        dishDetailsService.saveChangesInBackground { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    AppLogger.info("Ingredient sort order updated successfully in background", category: AppLogger.viewModel)
                case .failure(let error):
                    AppLogger.error("Failed to save ingredient reordering in background", error: error, category: AppLogger.viewModel)
                    // If background save fails, try synchronous save as fallback
                    self?.fallbackSyncSave()
                }
            }
        }
    }
    
    /// Fallback synchronous save if background save fails
    private func fallbackSyncSave() {
        do {
            try dishDetailsService.saveChanges()
            AppLogger.info("Ingredient sort order saved with fallback sync save", category: AppLogger.viewModel)
        } catch {
            AppLogger.error("Failed to save ingredient reordering with fallback", error: error, category: AppLogger.viewModel)
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
        // Check if dish is still valid before modifying meal types
        guard let dish = ensureValidDish() else {
            AppLogger.warning("Attempted to modify meal types on deleted dish entity", category: AppLogger.viewModel)
            return
        }
        
        if selectedMealTypes.contains(mealType) {
            selectedMealTypes.remove(mealType)
            mealType.removeFromDishes(dish)
        } else {
            selectedMealTypes.insert(mealType)
            mealType.addToDishes(dish)
        }
    }
    
    func saveChanges(onSuccess: ()->Void) {
        do {
            guard self.validate(), validationError == nil else {
                return
            }
            
            // Check if dish is still valid before saving
            guard let dish = ensureValidDish() else {
                AppLogger.error("Attempted to save deleted dish entity", category: AppLogger.viewModel)
                enqueueAlert(title: "Error", message: "The dish was removed during editing. Please create the dish again.")
                return
            }
            
            // Mark dish as complete when successfully saved
            dish.isDraft = false
            
            try dishDetailsService.saveChanges()
            hasSavedChanges = true
            onDismiss?(true) // Indicate user saved successfully
            onSuccess()
        } catch let error as NSError {
            enqueueAlert(title: "Error", message: error.localizedDescription)
        } catch {
            enqueueAlert(title: "Error", message: "Failed to save changes. Please try again.")
        }
    }
    
    func rollback() {
        dishDetailsService.rollback()
        onDismiss?(false) // Indicate user dismissed without saving
    }
    
    /// Called when user dismisses sheet without explicit cancel - ensures rollback happens
    func dismissWithoutSaving() {
        if !hasSavedChanges {
            rollback()
        }
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
    
    /// Checks if the dish entity is still valid and accessible
    private func isDishValid() -> Bool {
        guard let dish = dish else { return false }
        return !dish.isDeleted && dish.managedObjectContext != nil
    }
    
    /// Attempts to recreate the dish if it was deleted by cleanup processes
    private func ensureValidDish() -> Dish? {
        if let dish = dish, isDishValid() {
            return dish
        }
        
        // Dish was deleted, try to recreate it
        do {
            let newDish = try dishDetailsService.createDish()
            self.dish = newDish
            newDish.name = "" // Will be set by the user again
            newDish.details = ""
            newDish.isDraft = true
            AppLogger.info("Recreated dish entity after cleanup deletion", category: AppLogger.viewModel)
            return newDish
        } catch {
            AppLogger.error("Failed to recreate dish after cleanup deletion", error: error, category: AppLogger.viewModel)
            return nil
        }
    }
    
    /// Validates and sanitizes quantity values to prevent NaN/Infinite values that cause CoreGraphics errors
    private func validateQuantity(_ quantity: Double) -> Double {
        if quantity.isNaN || quantity.isInfinite {
            return 0.0
        }
        return max(0.0, quantity)
    }
    
    /// Safely updates ingredient quantity with validation
    func updateIngredientQuantity(_ ingredient: IngredientDetail, quantity: Double) {
        let validQuantity = validateQuantity(quantity)
        ingredient.quantity = validQuantity
        
        // Trigger immediate UI update
        objectWillChange.send()
        
        // Save changes to Core Data
        do {
            try dishDetailsService.saveChanges()
        } catch {
            AppLogger.error("Failed to save ingredient quantity update", error: error, category: AppLogger.viewModel)
        }
    }
    
    /// Performs essential data validation cleanup to prevent CoreGraphics NaN errors
    private func performDataValidationCleanup() {
        guard let dish = dish else { return }
        
        // Validate and fix ingredient quantities that may have been corrupted
        if let ingredientDetails = dish.ingredientDetails as? Set<IngredientDetail> {
            var hasChanges = false
            
            for detail in ingredientDetails {
                if detail.quantity.isNaN || detail.quantity.isInfinite {
                    let oldValue = detail.quantity
                    detail.quantity = 0.0
                    hasChanges = true
                    AppLogger.warning("Fixed invalid quantity value (\(oldValue)) in ingredient detail for dish: \(dish.name ?? "unknown")", category: AppLogger.viewModel)
                }
            }
            
            // Save changes if any fixes were made
            if hasChanges {
                do {
                    try dishDetailsService.saveChanges()
                    AppLogger.info("Data validation cleanup completed successfully", category: AppLogger.viewModel)
                } catch {
                    AppLogger.error("Failed to save data validation cleanup changes", error: error, category: AppLogger.viewModel)
                }
            }
        }
    }
    
    // Fallback cleanup when ViewModel is deallocated. Avoid UI callbacks from deinit.
    deinit {
        AppLogger.info("🔴 DishDetailsViewModel deinit called", category: AppLogger.viewModel)
        // No explicit rollback here to avoid double rollback; handled by dismissWithoutSaving
    }
}
