//
//  ProductSelectionView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 19.12.24.
//

import SwiftUI

struct ProductSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        entity: Product.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Product.name, ascending: true)]
    ) private var products: FetchedResults<Product>

    @State private var searchText: String = ""
    @State private var selectedProduct: Product?
    let currentProduct: Product?
    let onProductSelected: (Product) -> Void

    var body: some View {
        List {
            if filteredProducts.isEmpty {
                Color.clear.emptyState(message: "No results found".localized())
            } else {
                ForEach(filteredProducts, id: \.self) { product in
                    HStack {
                        Text(product.name ?? "Unnamed Product")
                        Spacer()
                        if product == selectedProduct || product == currentProduct {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color("AccentColor"))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedProduct = product
                        onProductSelected(product)
                        dismiss()
                    }
                    .listRowBackground(Color("SecondaryBackgroundColor"))
                }
            }
        }
        .navigationTitle("Select Product")
        .searchable(text: $searchText, prompt: "Search products...")
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
    }

    private var filteredProducts: [Product] {
        if searchText.isEmpty {
            return Array(products)
        } else {
            return products.filter { $0.name?.localizedCaseInsensitiveContains(searchText) ?? false }
        }
    }
}

