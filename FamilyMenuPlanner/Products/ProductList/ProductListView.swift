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
            Section(header: Text("Products")) {
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
            
            // Add new product
            Section(header: Text("Add New Product")) {
                TextField("Product Name", text: $viewModel.newProductName)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("ProductNameTextField")

                Picker("Unit", selection: Binding(
                    get: {
                        viewModel.selectedUnit ?? viewModel.units.first
                    },
                    set: {
                        viewModel.selectedUnit = $0
                    }
                )) {
                    ForEach(viewModel.units, id: \.self) { unit in
                        Text((unit.name ?? "").localized()).tag(unit as Unit?)
                    }
                }
                .accessibilityIdentifier("UnitPicker")

                if let error = viewModel.validationError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .accessibilityIdentifier("ValidationErrorText")
                }

                Button("Add Product") {
                    if viewModel.validateNewProduct() {
                        viewModel.addProduct()
                    }
                }
                .foregroundColor(Color("AccentColor"))
                .accessibilityIdentifier("AddProductButton")
            }
            .listRowBackground(Color("SecondaryBackgroundColor"))
        }
        .accessibilityIdentifier("ProductList")
        .searchable(text: $viewModel.searchText, prompt: "Search products...")
        .scrollContentBackground(.hidden)
        .background(Color("BackgroundColor"))
        .navigationTitle("Products")
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
            viewModel.updateSelectedUnit()
        }

    }
    
}

