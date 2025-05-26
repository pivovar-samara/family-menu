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
    @Published var searchText: String = ""         // Search query
    @Published var selectedProduct: Product?       // Product for editing
    
    @Published var newProductName: String = ""
    @Published var selectedUnit: Unit? = nil
    @Published var validationError: LocalizedStringKey?
    
    @Published var filteredProducts: [Product] = []
    @Published private(set) var allProducts: [Product] = []
    
    @Published var currentAlert: AlertItem?
    
    var units: [Unit]
    
    private let productListService: ProductListServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private let alertManager = AlertQueueManager()

    init(productListService: ProductListServiceProtocol) {
        self.productListService = productListService
        self.units = productListService.fetchAllUnits()
        $searchText
            .debounce(for: 0.3, scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] text in
                self?.filterProducts(with: text)
            }
            .store(in: &cancellables)
        alertManager.$currentAlert
                    .receive(on: RunLoop.main)
                    .assign(to: &$currentAlert)
    }
    
    func loadProducts() {
        allProducts = productListService.fetchAllProducts()
        filteredProducts = allProducts
    }
    
    private func filterProducts(with text: String) {
        if text.isEmpty {
            filteredProducts = allProducts
        } else {
            filteredProducts = allProducts.filter {
                $0.name?.localizedCaseInsensitiveContains(text) ?? false
            }
        }
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
            filteredProducts.remove(atOffsets: offsets)
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
            filterProducts(with: searchText)
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
