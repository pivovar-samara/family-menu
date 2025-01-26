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
    @Published private(set) var allProducts: [Product] = []
    let currentProduct: Product?
    let onProductSelected: (Product) -> Void
    
    private let productSelectionService: ProductSelectionService
    private var cancellables = Set<AnyCancellable>()
    
    init(productSelectionService: ProductSelectionService, currentProduct: Product?, onProductSelected: @escaping (Product) -> Void) {
        self.productSelectionService = productSelectionService
        self.currentProduct = currentProduct
        self.onProductSelected = onProductSelected
        $searchText
            .debounce(for: 0.3, scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] text in
                self?.filterProducts(with: text)
            }
            .store(in: &cancellables)
    }
    
    func loadProducts() {
        allProducts = productSelectionService.fetchAllProducts()
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
}
