//
//  ShoppingListViewModel.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 18.12.24.
//

import Foundation
import SwiftUI
import Combine

struct ShoppingListItem: Identifiable, Hashable {
    let id = UUID()
    let productName: String
    let unitName: String
    let quantity: Double
    var isSelected: Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(productName)
        hasher.combine(unitName)
    }
    
    static func == (lhs: ShoppingListItem, rhs: ShoppingListItem) -> Bool {
        return lhs.productName == rhs.productName && lhs.unitName == rhs.unitName
    }
}

enum ShoppingListSortOption: String, CaseIterable {
    case nameAscending = "nameAsc"
    case nameDescending = "nameDesc"
    case quantityHighToLow = "quantityHigh"
    case quantityLowToHigh = "quantityLow"
    case unit = "unit"
    
    var displayName: String {
        switch self {
        case .nameAscending:
            return "Name A-Z".localized()
        case .nameDescending:
            return "Name Z-A".localized()
        case .quantityHighToLow:
            return "Quantity: High to Low".localized()
        case .quantityLowToHigh:
            return "Quantity: Low to High".localized()
        case .unit:
            return "Unit".localized()
        }
    }
}

class ShoppingListViewModel: ObservableObject {
    @Published var shoppingItems: [ShoppingListItem] = []
    @Published var filteredItems: [ShoppingListItem] = []
    @Published var searchText: String = ""
    @Published var sortOption: ShoppingListSortOption = .nameAscending
    @Published var currentAlert: AlertItem?
    
    // MARK: - Progress
    /// Number of purchased (selected) items across the whole list
    var purchasedCount: Int {
        shoppingItems.filter { $0.isSelected }.count
    }
    
    /// Total number of items in the shopping list
    var totalCount: Int {
        shoppingItems.count
    }
    
    private let alertManager = AlertQueueManager()
    private static let sortPreferenceKey = "ShoppingListSortPreference"
    private static let selectionKey = "ShoppingListSelection"
    private static let quantityKey = "ShoppingListQuantity"
    private var cancellables = Set<AnyCancellable>()
    private var currentWeekDate: Date?
    
    init() {
        alertManager.$currentAlert
            .receive(on: RunLoop.main)
            .assign(to: &$currentAlert)
        
        loadSortPreference()
        
        // Observe search text changes with trimming, de-duplication, and debounced analytics tracking
        $searchText
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                guard let self = self else { return }
                self.applyFiltersAndSort()
                if !query.isEmpty {
                    AnalyticsManager.shared.track(
                        name: AnalyticsEventName.search_happened,
                        properties: [
                            AnalyticsPropertyKey.query: query,
                            AnalyticsPropertyKey.results: self.filteredItems.count,
                            AnalyticsPropertyKey.screen_name: AnalyticsScreenName.ShoppingList
                        ]
                    )
                }
            }
            .store(in: &cancellables)
    }
    
    func loadShoppingList(from rawShoppingList: [String: [String: Double]], for weekDate: Date) {
        self.currentWeekDate = weekDate
        var items: [ShoppingListItem] = []
        
        for (productName, unitDetails) in rawShoppingList {
            for (unitName, quantity) in unitDetails {
                let (isSelected, shouldResetSelection) = loadSelectionStateWithQuantityCheck(
                    for: productName, 
                    unit: unitName, 
                    currentQuantity: quantity, 
                    weekDate: weekDate
                )
                
                // If quantity changed and item was selected, reset the selection
                let finalIsSelected = shouldResetSelection ? false : isSelected
                
                items.append(ShoppingListItem(
                    productName: productName,
                    unitName: unitName,
                    quantity: quantity,
                    isSelected: finalIsSelected
                ))
                
                // Always save the current quantity state for baseline comparison
                saveQuantityState(for: productName, unit: unitName, quantity: quantity, weekDate: weekDate)
                // If quantity changed and item was selected, reset the selection
                if shouldResetSelection {
                    saveSelectionState(for: productName, unit: unitName, isSelected: false, weekDate: weekDate)
                }
            }
        }
        
        self.shoppingItems = items
        applyFiltersAndSort()
    }
    
    func toggleSelection(for item: ShoppingListItem) {
        guard let weekDate = currentWeekDate else { return }
        
        if let index = shoppingItems.firstIndex(where: { $0.id == item.id }) {
            shoppingItems[index].isSelected.toggle()
            let becomeSelected = shoppingItems[index].isSelected
            saveSelectionState(for: item.productName, unit: item.unitName, isSelected: becomeSelected, weekDate: weekDate)
            saveQuantityState(for: item.productName, unit: item.unitName, quantity: item.quantity, weekDate: weekDate)
            applyFiltersAndSort()
            AnalyticsManager.shared.track(name: becomeSelected ? AnalyticsEventName.shopping_list_item_selected : AnalyticsEventName.shopping_list_item_deselected, properties: [AnalyticsPropertyKey.selected_count: purchasedCount, AnalyticsPropertyKey.all_count: totalCount])
        }
    }
    
    func selectAll() {
        guard let weekDate = currentWeekDate else { return }
        
        for index in shoppingItems.indices {
            shoppingItems[index].isSelected = true
            saveSelectionState(for: shoppingItems[index].productName, unit: shoppingItems[index].unitName, isSelected: true, weekDate: weekDate)
            saveQuantityState(for: shoppingItems[index].productName, unit: shoppingItems[index].unitName, quantity: shoppingItems[index].quantity, weekDate: weekDate)
        }
        applyFiltersAndSort()
        
        AnalyticsManager.shared.track(name: AnalyticsEventName.shopping_list_all_selected, properties: [AnalyticsPropertyKey.all_count: totalCount])
    }
    
    func deselectAll() {
        guard let weekDate = currentWeekDate else { return }
        
        for index in shoppingItems.indices {
            shoppingItems[index].isSelected = false
            saveSelectionState(for: shoppingItems[index].productName, unit: shoppingItems[index].unitName, isSelected: false, weekDate: weekDate)
            saveQuantityState(for: shoppingItems[index].productName, unit: shoppingItems[index].unitName, quantity: shoppingItems[index].quantity, weekDate: weekDate)
        }
        applyFiltersAndSort()
        
        AnalyticsManager.shared.track(name: AnalyticsEventName.shopping_list_all_deselected, properties: [AnalyticsPropertyKey.all_count: totalCount])
    }
    
    func updateSortOption(_ option: ShoppingListSortOption) {
        sortOption = option
        saveSortPreference()
        applyFiltersAndSort()
        
        AnalyticsManager.shared.track(name: AnalyticsEventName.shopping_list_sorting_changed, properties: [AnalyticsPropertyKey.sort_type: option.rawValue])
    }
    
    private func applyFiltersAndSort() {
        // Apply search filter
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            filteredItems = shoppingItems
        } else {
            filteredItems = shoppingItems.filter { item in
                item.productName.localizedCaseInsensitiveContains(searchText) ||
                item.unitName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply sorting
        filteredItems.sort { first, second in
            switch sortOption {
            case .nameAscending:
                return first.productName.localizedCaseInsensitiveCompare(second.productName) == .orderedAscending
            case .nameDescending:
                return first.productName.localizedCaseInsensitiveCompare(second.productName) == .orderedDescending
            case .quantityHighToLow:
                return first.quantity > second.quantity
            case .quantityLowToHigh:
                return first.quantity < second.quantity
            case .unit:
                return first.unitName.localizedCaseInsensitiveCompare(second.unitName) == .orderedAscending
            }
        }
    }
    
    // MARK: - Persistence
    
    private func loadSortPreference() {
        let savedSortOption = UserDefaults.standard.string(forKey: Self.sortPreferenceKey) ?? ShoppingListSortOption.nameAscending.rawValue
        sortOption = ShoppingListSortOption(rawValue: savedSortOption) ?? .nameAscending
    }
    
    private func saveSortPreference() {
        UserDefaults.standard.set(sortOption.rawValue, forKey: Self.sortPreferenceKey)
    }
    
    private func encodeWeek(for weekDate: Date) -> Int {
        let weekComponents = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekDate)
        let year = weekComponents.yearForWeekOfYear ?? 0
        let week = weekComponents.weekOfYear ?? 0
        return year * 100 + week
    }
    
    private func percentEncode(_ string: String) -> String {
        // Escape everything except alphanumerics and dash
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }

    private func percentDecode(_ string: String) -> String {
        return string.removingPercentEncoding ?? string
    }
    
    private func loadSelectionStateWithQuantityCheck(for productName: String, unit: String, currentQuantity: Double, weekDate: Date) -> (isSelected: Bool, shouldResetSelection: Bool) {
        let encodedWeek = encodeWeek(for: weekDate)
        let encodedProduct = percentEncode(productName)
        let encodedUnit = percentEncode(unit)
        let selectionKey = "\(Self.selectionKey)_\(encodedWeek)_\(encodedProduct)_\(encodedUnit)"
        let quantityKey = "\(Self.quantityKey)_\(encodedWeek)_\(encodedProduct)_\(encodedUnit)"
        
        let isSelected = UserDefaults.standard.bool(forKey: selectionKey)
        let savedQuantity = UserDefaults.standard.double(forKey: quantityKey)
        
        // Check if we have a saved quantity
        let hasSavedQuantity = UserDefaults.standard.object(forKey: quantityKey) != nil
        
        // If quantity changed and item was selected, we should reset the selection
        // Only reset if we have a saved quantity and it's different from current
        let shouldResetSelection = isSelected && hasSavedQuantity && abs(savedQuantity - currentQuantity) > 0.001 // Use small epsilon for floating point comparison
        
        return (isSelected, shouldResetSelection)
    }
    
    private func loadSelectionState(for productName: String, unit: String, weekDate: Date) -> Bool {
        let encodedWeek = encodeWeek(for: weekDate)
        let encodedProduct = percentEncode(productName)
        let encodedUnit = percentEncode(unit)
        let key = "\(Self.selectionKey)_\(encodedWeek)_\(encodedProduct)_\(encodedUnit)"
        return UserDefaults.standard.bool(forKey: key)
    }
    
    private func saveSelectionState(for productName: String, unit: String, isSelected: Bool, weekDate: Date) {
        let encodedWeek = encodeWeek(for: weekDate)
        let encodedProduct = percentEncode(productName)
        let encodedUnit = percentEncode(unit)
        let key = "\(Self.selectionKey)_\(encodedWeek)_\(encodedProduct)_\(encodedUnit)"
        UserDefaults.standard.set(isSelected, forKey: key)
    }
    
    private func saveQuantityState(for productName: String, unit: String, quantity: Double, weekDate: Date) {
        let encodedWeek = encodeWeek(for: weekDate)
        let encodedProduct = percentEncode(productName)
        let encodedUnit = percentEncode(unit)
        let key = "\(Self.quantityKey)_\(encodedWeek)_\(encodedProduct)_\(encodedUnit)"
        UserDefaults.standard.set(quantity, forKey: key)
    }
    
    func clearOldSelections() {
        let calendar = Calendar.current
        let today = Date()
        let startOfCurrentWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        let currentEncodedWeek = encodeWeek(for: startOfCurrentWeek)
        
        let defaults = UserDefaults.standard
        let allKeys = defaults.dictionaryRepresentation().keys
        
        for key in allKeys {
            if key.hasPrefix(Self.selectionKey) || key.hasPrefix(Self.quantityKey) {
                // Extract encoded week from key and check if it's old
                let components = key.components(separatedBy: "_")
                if components.count >= 4 {
                    let encodedWeekString = components[1]
                    if let encodedWeek = Int(encodedWeekString),
                       encodedWeek < currentEncodedWeek {
                        // Optionally decode product/unit if needed:
                        // let productName = percentDecode(components[2])
                        // let unitName = percentDecode(components[3])
                        defaults.removeObject(forKey: key)
                    }
                }
            }
        }
    }
    
    // MARK: - Testing Support
    
    func clearAllSelections() {
        let defaults = UserDefaults.standard
        let allKeys = defaults.dictionaryRepresentation().keys
        
        for key in allKeys {
            if key.hasPrefix(Self.selectionKey) || key.hasPrefix(Self.quantityKey) {
                defaults.removeObject(forKey: key)
            }
        }
    }
    
    func clearSelectionsForWeek(_ weekDate: Date) {
        let targetEncodedWeek = encodeWeek(for: weekDate)
        let defaults = UserDefaults.standard
        let allKeys = defaults.dictionaryRepresentation().keys
        
        for key in allKeys {
            if key.hasPrefix(Self.selectionKey) || key.hasPrefix(Self.quantityKey) {
                let components = key.components(separatedBy: "_")
                if components.count >= 4 {
                    let encodedWeekString = components[1]
                    if let encodedWeek = Int(encodedWeekString),
                       encodedWeek == targetEncodedWeek {
                        defaults.removeObject(forKey: key)
                    }
                }
            }
        }
    }
    
    // MARK: - Alert Management
    
    func enqueueAlert(title: String, message: String, action: (() -> Void)? = nil) {
        let alert = AlertItem(title: title.localized(), message: message.localized(), action: action)
        alertManager.enqueue(alert: alert)
    }
    
    func dismissAlert() {
        alertManager.dismissCurrentAlert()
    }
} 

