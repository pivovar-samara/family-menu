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
    
    // Published property for sorting functionality
    @Published var sortOption: DishSortOption = .nameAscending
    
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
    
    // UserDefaults key for storing sort preference
    private static let sortPreferenceKey = "DishListSortPreference"

    init(dishListService: DishListServiceProtocol) {
        self.dishListService = dishListService
        
        // Initialize search helper with proper filter predicate
        self.searchHelper = SearchOptimizationHelper<Dish> { dish, searchText in
            guard let name = dish.name else { return false }
            let matchesName = name.localizedCaseInsensitiveContains(searchText)
            let matchesDetails = dish.details?.localizedCaseInsensitiveContains(searchText) ?? false
            let matchesCategory = dish.category?.name?.localized().localizedCaseInsensitiveContains(searchText) ?? false
            
            // Check meal types
            let matchesMealType: Bool = {
                guard let mealTypes = dish.mealTypes as? Set<MealType> else { return false }
                return mealTypes.contains { mealType in
                    mealType.name?.localized().localizedCaseInsensitiveContains(searchText) ?? false
                }
            }()
            
            return matchesName || matchesDetails || matchesCategory || matchesMealType
        }
        
        // Load persistent sort preference after all stored properties are initialized
        loadSortPreference()
        
        // Setup bindings between ViewModel and SearchHelper
        setupSearchBindings()
        
        self.dishListService.delegate = self
        alertManager.$currentAlert
                    .receive(on: RunLoop.main)
                    .assign(to: &$currentAlert)
        
        // Setup sort option binding
        setupSortBinding()
        
        // Explicitly set the initial sort option in the service to match loaded preference
        dishListService.updateSortOption(sortOption)

        // Refresh dish list after CloudKit reconciliation
        NotificationCenter.default.addObserver(forName: .appDataDidReconcileAfterCloudKitImport, object: nil, queue: .main) { [weak self] _ in
            self?.loadDishes()
        }
    }
    
    /// Loads the persistent sort preference from UserDefaults
    private func loadSortPreference() {
        let savedSortOption = UserDefaults.standard.string(forKey: Self.sortPreferenceKey) ?? DishSortOption.nameAscending.rawValue
        sortOption = DishSortOption(rawValue: savedSortOption) ?? .nameAscending
        AppLogger.info("Loaded dish list sort preference: \(sortOption.rawValue)", category: AppLogger.viewModel)
    }
    
    /// Saves the current sort preference to UserDefaults
    private func saveSortPreference() {
        UserDefaults.standard.set(sortOption.rawValue, forKey: Self.sortPreferenceKey)
        AppLogger.info("Saved dish list sort preference: \(sortOption.rawValue)", category: AppLogger.viewModel)
    }
    
    private func setupSortBinding() {
        // Update service when sort option changes, but ignore initial value during initialization
        $sortOption
            .dropFirst() // Ignore the initial value to prevent premature service updates during init
            .removeDuplicates()
            .sink { [weak self] newSortOption in
                self?.dishListService.updateSortOption(newSortOption)
                self?.saveSortPreference()
            }
            .store(in: &cancellables)
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
    
    func updateSortOption(_ newSortOption: DishSortOption) {
        // Only update if it's actually different to prevent unnecessary operations
        guard sortOption != newSortOption else { return }
        sortOption = newSortOption
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
