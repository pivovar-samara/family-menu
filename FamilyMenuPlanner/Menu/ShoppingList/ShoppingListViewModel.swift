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
    
    private let alertManager = AlertQueueManager()
    private static let sortPreferenceKey = "ShoppingListSortPreference"
    private static let selectionKey = "ShoppingListSelection"
    private var cancellables = Set<AnyCancellable>()
    private var currentWeekDate: Date?
    
    init() {
        alertManager.$currentAlert
            .receive(on: RunLoop.main)
            .assign(to: &$currentAlert)
        
        loadSortPreference()
        
        // Observe search text changes
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyFiltersAndSort()
            }
            .store(in: &cancellables)
    }
    
    func loadShoppingList(from rawShoppingList: [String: [String: Double]], for weekDate: Date) {
        self.currentWeekDate = weekDate
        var items: [ShoppingListItem] = []
        
        for (productName, unitDetails) in rawShoppingList {
            for (unitName, quantity) in unitDetails {
                let isSelected = loadSelectionState(for: productName, unit: unitName, weekDate: weekDate)
                items.append(ShoppingListItem(
                    productName: productName,
                    unitName: unitName,
                    quantity: quantity,
                    isSelected: isSelected
                ))
            }
        }
        
        self.shoppingItems = items
        applyFiltersAndSort()
    }
    
    func toggleSelection(for item: ShoppingListItem) {
        guard let weekDate = currentWeekDate else { return }
        
        if let index = shoppingItems.firstIndex(where: { $0.id == item.id }) {
            shoppingItems[index].isSelected.toggle()
            saveSelectionState(for: item.productName, unit: item.unitName, isSelected: shoppingItems[index].isSelected, weekDate: weekDate)
            applyFiltersAndSort()
        }
    }
    
    func selectAll() {
        guard let weekDate = currentWeekDate else { return }
        
        for index in shoppingItems.indices {
            shoppingItems[index].isSelected = true
            saveSelectionState(for: shoppingItems[index].productName, unit: shoppingItems[index].unitName, isSelected: true, weekDate: weekDate)
        }
        applyFiltersAndSort()
    }
    
    func deselectAll() {
        guard let weekDate = currentWeekDate else { return }
        
        for index in shoppingItems.indices {
            shoppingItems[index].isSelected = false
            saveSelectionState(for: shoppingItems[index].productName, unit: shoppingItems[index].unitName, isSelected: false, weekDate: weekDate)
        }
        applyFiltersAndSort()
    }
    
    func updateSortOption(_ option: ShoppingListSortOption) {
        sortOption = option
        saveSortPreference()
        applyFiltersAndSort()
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
    
    private func loadSelectionState(for productName: String, unit: String, weekDate: Date) -> Bool {
        let encodedWeek = encodeWeek(for: weekDate)
        let key = "\(Self.selectionKey)_\(encodedWeek)_\(productName)_\(unit)"
        return UserDefaults.standard.bool(forKey: key)
    }
    
    private func saveSelectionState(for productName: String, unit: String, isSelected: Bool, weekDate: Date) {
        let encodedWeek = encodeWeek(for: weekDate)
        let key = "\(Self.selectionKey)_\(encodedWeek)_\(productName)_\(unit)"
        UserDefaults.standard.set(isSelected, forKey: key)
    }
    
    func clearOldSelections() {
        let calendar = Calendar.current
        let today = Date()
        let startOfCurrentWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        let currentEncodedWeek = encodeWeek(for: startOfCurrentWeek)
        
        let defaults = UserDefaults.standard
        let allKeys = defaults.dictionaryRepresentation().keys
        
        for key in allKeys {
            if key.hasPrefix(Self.selectionKey) {
                // Extract encoded week from key and check if it's old
                let components = key.components(separatedBy: "_")
                if components.count >= 3 {
                    let encodedWeekString = components[1]
                    if let encodedWeek = Int(encodedWeekString),
                       encodedWeek < currentEncodedWeek {
                        // Delete ALL weeks older than the current week
                        // This prevents accumulation of old data when app is used infrequently
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
