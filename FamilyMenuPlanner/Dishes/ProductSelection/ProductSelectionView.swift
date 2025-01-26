//
//  ProductSelectionView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 19.12.24.
//

import SwiftUI

struct ProductSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: ProductSelectionViewModel
    
    init(viewModel: ProductSelectionViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            if viewModel.filteredProducts.isEmpty {
                Color.clear.emptyState(message: "No results found".localized())
            } else {
                ForEach(viewModel.filteredProducts, id: \.self) { product in
                    HStack {
                        Text(product.name ?? "Unnamed Product")
                        Spacer()
                        if product == viewModel.selectedProduct || product == viewModel.currentProduct {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color("AccentColor"))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectedProduct = product
                        viewModel.onProductSelected(product)
                        dismiss()
                    }
                    .listRowBackground(Color("SecondaryBackgroundColor"))
                }
            }
        }
        .navigationTitle("Select Product")
        .searchable(text: $viewModel.searchText, prompt: "Search products...")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(Color("AccentColor"))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("BackgroundColor"))
        .onAppear {
            viewModel.loadProducts()
        }
    }
}

