//
//  ProductListView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 17.12.24.
//

import SwiftUI

struct ProductListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        entity: Product.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Product.name, ascending: true)]
    ) private var products: FetchedResults<Product>

    @FetchRequest(
        entity: Unit.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Unit.sortOrder, ascending: true)]
    ) private var units: FetchedResults<Unit>
    
    @State private var searchText: String = ""         // Search query
    @State private var selectedProduct: Product?       // Product for editing
    
    @State private var newProductName: String = ""
    @State private var selectedUnit: Unit? = nil
    @State private var validationError: LocalizedStringKey?
    
    @State private var showAlert: Bool = false
    @State private var currentAlert: Alert? = nil
    
    var body: some View {
        List {
            // Product list
            Section(header: Text("Products")) {
                ForEach(filteredProducts, id: \.self) { product in
                    HStack {
                        Text(product.name ?? "Unnamed Product")
                        Spacer()
                        Text((product.unit?.name ?? "").localized())
                            .foregroundColor(.secondary)
                        Button(action: {
                            selectedProduct = product
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(Color("AccentColor"))
                        }
                    }
                    .listRowBackground(Color("SecondaryBackgroundColor"))
                }
                .onDelete(perform: deleteProducts)
            }
            
            // Add new product
            Section(header: Text("Add New Product")) {
                TextField("Product Name", text: $newProductName)

                Picker("Unit", selection: Binding(
                    get: {
                        selectedUnit ?? units.first
                    },
                    set: {
                        selectedUnit = $0
                    }
                )) {
                    ForEach(units, id: \.self) { unit in
                        Text((unit.name ?? "").localized()).tag(unit as Unit?)
                    }
                }

                if let error = validationError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                Button("Add Product") {
                    if validateNewProduct() {
                        addProduct()
                    }
                }
                .foregroundColor(Color("AccentColor"))
            }
            .listRowBackground(Color("SecondaryBackgroundColor"))
        }
        .searchable(text: $searchText, prompt: "Search products...")
        .scrollContentBackground(.hidden)
        .background(Color("BackgroundColor"))
        .navigationTitle("Products")
        // Show sheet only when selectedProduct is set
        .sheet(item: $selectedProduct) { product in
            NavigationStack {
                EditProductView(product: product)
            }
        }
        .alert(isPresented: $showAlert) {
            currentAlert!
        }
        .onAppear {
            if selectedUnit == nil {
                selectedUnit = units.first
            }
        }

    }
    
    private var filteredProducts: [Product] {
        if searchText.isEmpty {
            return Array(products)
        } else {
            return products.filter { $0.name?.localizedCaseInsensitiveContains(searchText) ?? false }
        }
    }
    
    // Delete products from Core Data
    private func deleteProducts(at offsets: IndexSet) {
        do {
            try viewContext.setQueryGenerationFrom(.current)
            for index in offsets {
                let product = products[index]
                viewContext.delete(product)
            }
            try viewContext.save()
        } catch {
            currentAlert = AlertHelper.presentAlert(
                title: "Error",
                message: "Error deleting product. Please try again."
            )
            showAlert = true
        }
    }
    
    private func addProduct() {

        do {
            try viewContext.setQueryGenerationFrom(.current)
            
            let newProduct = Product(context: viewContext)
            newProduct.name = newProductName
            newProduct.unit = selectedUnit
            
            try viewContext.save()
            newProductName = ""
            selectedUnit = nil
            validationError = nil
        } catch {
            currentAlert = AlertHelper.presentAlert(
                title: "Error",
                message: "Error adding product. Please try again."
            )
            showAlert = true
        }
    }
    
    private func validateNewProduct() -> Bool {
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
}

