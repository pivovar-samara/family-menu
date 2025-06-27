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

    init(productListService: ProductListServiceProtocol) {
        self.productListService = productListService
        
        // Initialize search helper with proper filter predicate
        self.searchHelper = SearchOptimizationHelper<Product> { product, searchText in
            guard let name = product.name else { return false }
            return name.localizedCaseInsensitiveContains(searchText)
        }
        
        // Setup bindings between ViewModel and SearchHelper
        setupSearchBindings()
        
        // Setup alert manager
        alertManager.$currentAlert
                    .receive(on: RunLoop.main)
                    .assign(to: &$currentAlert)
        
        // Set up delegate to receive automatic updates
        self.productListService.delegate = self
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
    
    func loadProducts() {
        productListService.fetchAllProducts()
    }
    
    // Delete products from Core Data
    func deleteProducts(at offsets: IndexSet) {
        do {
            var products: [Product] = []
            for index in offsets {
                let product = filteredProducts[index]
                products.append(product)
                if let index = allProducts.firstIndex(of: product) {
                    allProducts.remove(at: index)
                }
            }
            
            try productListService.deleteProducts(products: products)
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
}

extension ProductListViewModel: ProductListServiceDelegate {
    func serviceDidChangeContent(_ products: [Product]) {
        self.allProducts = products
    }
}
