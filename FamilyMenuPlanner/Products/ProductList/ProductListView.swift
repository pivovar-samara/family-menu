//
//  ProductListView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 17.12.24.
//

import SwiftUI

struct ProductListView: View {
    @StateObject private var viewModel: ProductListViewModel

    init(viewModel: ProductListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        List {
            // Product list
            Section() {
                ForEach(viewModel.filteredProducts, id: \.self) { product in
                    HStack {
                        Text(product.name ?? "Unnamed Product")
                        Spacer()
                        Text((product.unit?.name ?? "").localized())
                            .foregroundColor(.secondary)
                        Button(action: {
                            viewModel.selectedProduct = product
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(Color("AccentColor"))
                        }
                        .accessibilityIdentifier("EditProductButton")
                    }
                    .listRowBackground(Color("SecondaryBackgroundColor"))
                }
                .onDelete(perform: viewModel.deleteProducts)
            }
        }
        .accessibilityIdentifier("ProductList")
        .searchable(text: $viewModel.searchText, prompt: "Search products...")
        .scrollContentBackground(.hidden)
        .background(Color("BackgroundColor"))
        .navigationTitle("Products")
        .sheet(isPresented: $viewModel.isAddingNewProduct, onDismiss: {
            viewModel.isAddingNewProduct = false
        }) {
            NavigationStack {
                EditProductCoordinator().createEditProductView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                createToolbarButton(title: "Add Product".localized(), systemImage: "plus") {
                    viewModel.isAddingNewProduct = true
                }
            }
        }
        // Show sheet only when selectedProduct is set
        .sheet(item: $viewModel.selectedProduct) { product in
            NavigationStack {
                EditProductCoordinator().createEditProductView(product: product)
            }
        }
        .alert(item: Binding(
            get: { viewModel.currentAlert },
            set: { _ in viewModel.dismissAlert() }
        )) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK")) {
                    alert.action?()
                }
            )
        }
        .onAppear {
            viewModel.loadProducts()
        }
    }
    
}

