//
//  ProductListViewModel.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 19.01.25.
//

import Foundation
import SwiftUI
import Combine

class ProductListViewModel: ObservableObject {
    @Published var selectedProduct: Product?       // Product for editing
    @Published var isAddingNewProduct: Bool = false
    
    @Published var currentAlert: AlertItem?
    
    // Published properties for search functionality
    @Published var searchText: String = ""
    @Published var filteredProducts: [Product] = []
    
    // Published property for sorting functionality
    @Published var sortOption: ProductSortOption = .nameAscending
    
    // Use cached data for better performance
    var units: [Unit] {
        return StaticDataCacheManager.shared.getUnits()
    }
    
    // Use SearchOptimizationHelper for better performance
    private let searchHelper: SearchOptimizationHelper<Product>
    
    private(set) var allProducts: [Product] = [] {
        didSet {
            searchHelper.updateItems(allProducts)
        }
    }
    
    private var productListService: ProductListServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private let alertManager = AlertQueueManager()
    
    // UserDefaults key for storing sort preference
    private static let sortPreferenceKey = "ProductListSortPreference"

    init(productListService: ProductListServiceProtocol) {
        self.productListService = productListService
        
        // Initialize search helper with proper filter predicate
        self.searchHelper = SearchOptimizationHelper<Product>(screenName: AnalyticsScreenName.ProductList, filterPredicate: { product, searchText in
            guard let name = product.name else { return false }
            return name.localizedCaseInsensitiveContains(searchText)
        })
        
        // Load persistent sort preference now that all stored properties are initialized
        loadSortPreference()
        
        // Setup bindings between ViewModel and SearchHelper
        setupSearchBindings()
        
        // Setup sort option binding
        setupSortBinding()
        
        // Setup alert manager
        alertManager.$currentAlert
                    .receive(on: RunLoop.main)
                    .assign(to: &$currentAlert)
        
        // Set up delegate to receive automatic updates BEFORE we trigger any service updates
        self.productListService.delegate = self
        
        // Explicitly set the initial sort option in the service to match loaded preference
        productListService.updateSortOption(sortOption)

        // Refresh after CloudKit reconciliation
        NotificationCenter.default.addObserver(forName: .appDataDidReconcileAfterCloudKitImport, object: nil, queue: .main) { [weak self] _ in
            self?.loadProducts()
        }
    }
    
    private func setupSearchBindings() {
        // Forward search text changes to helper
        $searchText
            .assign(to: \.searchText, on: searchHelper)
            .store(in: &cancellables)
        
        // Forward filtered results back to ViewModel
        searchHelper.$filteredItems
            .receive(on: RunLoop.main)
            .assign(to: \.filteredProducts, on: self)
            .store(in: &cancellables)
    }
    
    private func setupSortBinding() {
        $sortOption
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] newOption in
                self?.productListService.updateSortOption(newOption)
                self?.saveSortPreference()
            }
            .store(in: &cancellables)
    }
    
    func loadProducts() {
        productListService.fetchAllProducts()
    }
    
    // Delete products from Core Data
    func deleteProducts(at offsets: IndexSet) {
        do {
            var productsToDelete: [Product] = []
            for index in offsets {
                let product = filteredProducts[index]
                productsToDelete.append(product)
            }
            
            // Delete from Core Data - delegate callback will handle UI updates
            try productListService.deleteProducts(products: productsToDelete)
            
            // Note: allProducts will be updated automatically via delegate callback
            // No immediate UI update to avoid conflicts with NSFetchedResultsController
            
        } catch {
            enqueueAlert(title: "Error", message: "Error deleting product. Please try again.")
        }
    }

    func enqueueAlert(title: String, message: String, action: (() -> Void)? = nil) {
        let alert = AlertItem(title: title.localized(), message: message.localized(), action: action)
        alertManager.enqueue(alert: alert)
    }
    
    func dismissAlert() {
        alertManager.dismissCurrentAlert()
    }

    /// Deletes a single product, triggered from ProductCardView.
    func deleteProduct(_ product: Product) {
        guard let index = filteredProducts.firstIndex(of: product) else { return }
        deleteProducts(at: IndexSet([index]))
    }

    // MARK: - Sorting Preference Persistence
    private func loadSortPreference() {
        let saved = UserDefaults.standard.string(forKey: Self.sortPreferenceKey) ?? ProductSortOption.nameAscending.rawValue
        sortOption = ProductSortOption(rawValue: saved) ?? .nameAscending
        AppLogger.info("Loaded product list sort preference: \(sortOption.rawValue)", category: AppLogger.viewModel)
    }

    private func saveSortPreference() {
        UserDefaults.standard.set(sortOption.rawValue, forKey: Self.sortPreferenceKey)
        AppLogger.info("Saved product list sort preference: \(sortOption.rawValue)", category: AppLogger.viewModel)
    }

    func updateSortOption(_ newSortOption: ProductSortOption) {
        guard sortOption != newSortOption else { return }
        sortOption = newSortOption
    }
}

extension ProductListViewModel: ProductListServiceDelegate {
    func serviceDidChangeContent(_ products: [Product]) {
        self.allProducts = products
    }
}
