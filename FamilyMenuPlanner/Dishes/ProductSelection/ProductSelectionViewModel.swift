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
    enum SelectionMode {
        case single
        case multiple
    }

    @Published var searchText: String = ""
    // Single selection state
    @Published var selectedProduct: Product?
    // Multi selection state
    @Published var selectedProducts: Set<Product> = []

    @Published var filteredProducts: [Product] = []
    @Published private(set) var allProducts: [Product] = [] {
        didSet {
            searchHelper.updateItems(allProducts)
        }
    }

    let selectionMode: SelectionMode
    let currentProduct: Product?
    let preselectedProducts: [Product]

    // Callbacks
    let onProductSelected: (Product) -> Void
    let onProductsSelected: (([Product]) -> Void)?
    
    // Use SearchOptimizationHelper for better performance
    private let searchHelper: SearchOptimizationHelper<Product>
    
    private let productSelectionService: ProductSelectionServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(
        productSelectionService: ProductSelectionServiceProtocol,
        currentProduct: Product?,
        selectionMode: SelectionMode = .single,
        preselectedProducts: [Product] = [],
        onProductSelected: @escaping (Product) -> Void,
        onProductsSelected: (([Product]) -> Void)? = nil
    ) {
        self.productSelectionService = productSelectionService
        self.currentProduct = currentProduct
        self.selectionMode = selectionMode
        self.preselectedProducts = preselectedProducts
        self.onProductSelected = onProductSelected
        self.onProductsSelected = onProductsSelected
        
        // Initialize search helper with proper filter predicate
        self.searchHelper = SearchOptimizationHelper<Product> { product, searchText in
            guard let name = product.name else { return false }
            return name.localizedCaseInsensitiveContains(searchText)
        }
        
        // Setup bindings between ViewModel and SearchHelper
        setupSearchBindings()
        
        // Initialize selection state for multi-select
        if selectionMode == .multiple {
            self.selectedProducts = Set(preselectedProducts)
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
    
    func loadProducts() {
        allProducts = productSelectionService.fetchAllProducts()
    }
    
    // MARK: - Selection Handling
    func toggleSelection(for product: Product) {
        guard selectionMode == .multiple else { return }
        if selectedProducts.contains(product) {
            selectedProducts.remove(product)
        } else {
            selectedProducts.insert(product)
        }
    }
}
