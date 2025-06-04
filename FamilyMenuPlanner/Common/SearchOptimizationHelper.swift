//
//  SearchOptimizationHelper.swift
//  FamilyMenuPlanner
//
//  Created by Performance Optimization on 28.01.25.
//

import Foundation
import Combine

/// Helper class that provides optimized search functionality for ViewModels
/// Reduces unnecessary UI updates and improves performance during filtering operations
final class SearchOptimizationHelper<T>: ObservableObject where T: Equatable {
    @Published private(set) var filteredItems: [T] = []
    @Published var searchText: String = ""
    
    private var allItems: [T] = []
    private var cancellables = Set<AnyCancellable>()
    private let filterPredicate: (T, String) -> Bool
    private var lastFilteredResult: [T] = []
    
    /// Initialize with a filter predicate that determines if an item matches the search text
    /// - Parameter filterPredicate: Closure that takes an item and search text, returns true if item matches
    init(filterPredicate: @escaping (T, String) -> Bool) {
        self.filterPredicate = filterPredicate
        setupSearchPublisher()
    }
    
    /// Updates the source data and triggers re-filtering if needed
    /// - Parameter items: New array of items to filter
    func updateItems(_ items: [T]) {
        allItems = items
        performFiltering(with: searchText)
    }
    
    /// Gets the current filtered items without triggering a publisher update
    var currentFilteredItems: [T] {
        return filteredItems
    }
    
    /// Returns true if search is currently active (non-empty search text)
    var isSearchActive: Bool {
        return !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func setupSearchPublisher() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] searchText in
                self?.performFiltering(with: searchText)
            }
            .store(in: &cancellables)
    }
    
    private func performFiltering(with searchText: String) {
        let trimmedText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let newFilteredItems: [T]
        if trimmedText.isEmpty {
            newFilteredItems = allItems
        } else {
            newFilteredItems = allItems.filter { item in
                filterPredicate(item, trimmedText)
            }
        }
        
        // Only update if the result actually changed to avoid unnecessary UI updates
        if newFilteredItems != lastFilteredResult {
            lastFilteredResult = newFilteredItems
            filteredItems = newFilteredItems
        }
    }
} 