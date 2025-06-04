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
    
    @Published var newProductName: String = ""
    @Published var selectedUnit: Unit? = nil
    @Published var validationError: LocalizedStringKey?
    
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
    
    private let productListService: ProductListServiceProtocol
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
        allProducts = productListService.fetchAllProducts()
    }
    
    func updateSelectedUnit() {
        if selectedUnit == nil {
            selectedUnit = units.first
        }
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
    
    func addProduct() {
        do {
            guard let unit = selectedUnit ?? units.first else {
                throw NSError(domain: "com.familymenuplanner.error",
                              code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Unit is not selected and no default unit is available."])
            }
            try productListService.addProduct(name: newProductName, unit: unit)

            newProductName = ""
            validationError = nil
            
            loadProducts()
        } catch let error as NSError {
            enqueueAlert(title: "Error", message: error.localizedDescription)
        } catch {
            enqueueAlert(title: "Error", message: "Error adding product. Please try again.")
        }
    }
    
    func validateNewProduct() -> Bool {
        validationError = nil

        if newProductName.isEmpty {
            validationError = "Product name cannot be empty."
            return false
        }

        if selectedUnit == nil {
            validationError = "Please select a unit for the product."
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
