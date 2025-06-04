//
//  ProductSelectionViewModel.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 26.01.25.
//

import Foundation
import SwiftUI
import Combine

class ProductSelectionViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedProduct: Product?
    @Published var filteredProducts: [Product] = []
    @Published private(set) var allProducts: [Product] = [] {
        didSet {
            searchHelper.updateItems(allProducts)
        }
    }
    let currentProduct: Product?
    let onProductSelected: (Product) -> Void
    
    // Use SearchOptimizationHelper for better performance
    private let searchHelper: SearchOptimizationHelper<Product>
    
    private let productSelectionService: ProductSelectionServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(productSelectionService: ProductSelectionServiceProtocol, currentProduct: Product?, onProductSelected: @escaping (Product) -> Void) {
        self.productSelectionService = productSelectionService
        self.currentProduct = currentProduct
        self.onProductSelected = onProductSelected
        
        // Initialize search helper with proper filter predicate
        self.searchHelper = SearchOptimizationHelper<Product> { product, searchText in
            guard let name = product.name else { return false }
            return name.localizedCaseInsensitiveContains(searchText)
        }
        
        // Setup bindings between ViewModel and SearchHelper
        setupSearchBindings()
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
        allProducts = productSelectionService.fetchAllProducts()
    }
}
