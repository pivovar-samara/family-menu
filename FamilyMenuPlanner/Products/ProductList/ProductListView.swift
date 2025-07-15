//
//  ProductListView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 17.12.24.
//

import SwiftUI

struct ProductListView: View {
    @StateObject private var viewModel: ProductListViewModel
    // Sorting dialog state
    @State private var showingSortOptions = false
    // Additional UI state variables can be added here as needed

    init(viewModel: ProductListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            // Empty state handling
            if viewModel.filteredProducts.isEmpty {
                if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // On-boarding style empty state when there are no products at all
                    EmptyProductListView {
                        viewModel.isAddingNewProduct = true
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("product_list_empty_state")
                } else {
                    // No search results
                    Color.clear
                        .emptyState(message: "No results found".localized())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("product_list_no_results_state")
                }
            } else {
                // Card-style product rows
                ForEach(viewModel.filteredProducts, id: \.self) { product in
                    ProductCardView(
                        product: product,
                        onEdit: {
                            viewModel.selectedProduct = product
                        },
                        onDelete: {
                            viewModel.deleteProduct(product)
                        }
                    )
                    .padding(.vertical, 8)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("product_list_item_\(product.name ?? "unnamed")")
                }
            }

            // Spacer to keep content above the floating action button
            Color.clear
                .frame(height: 80)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .accessibilityIdentifier("ProductList")
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color("BackgroundColor"))
        .searchable(text: $viewModel.searchText, prompt: "Search products...".localized())
        .navigationTitle("Products".localized())
        .overlay(alignment: .bottomTrailing) {
            FloatingActionButton {
                viewModel.isAddingNewProduct = true
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
            .accessibilityIdentifier("add_product_button")
        }
        // Toolbar with sort button
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingSortOptions = true }) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.body)
                        .foregroundColor(Color("AccentColor"))
                }
                .accessibilityIdentifier("sort_products_button")
                .accessibilityLabel("Sort products".localized())
                .confirmationDialog("Sort products".localized(), isPresented: $showingSortOptions, titleVisibility: .visible) {
                    Button("Name A-Z".localized()) {
                        viewModel.updateSortOption(.nameAscending)
                    }
                    Button("Name Z-A".localized()) {
                        viewModel.updateSortOption(.nameDescending)
                    }
                    Button("Unit".localized()) {
                        viewModel.updateSortOption(.unit)
                    }
                    Button("Cancel".localized(), role: .cancel) {}
                }
            }
        }
        // Sheet for adding new product
        .sheet(isPresented: $viewModel.isAddingNewProduct, onDismiss: {
            viewModel.isAddingNewProduct = false
        }) {
            NavigationStack {
                EditProductCoordinator().createEditProductView()
            }
        }
        // Sheet for editing selected product
        .sheet(item: $viewModel.selectedProduct, onDismiss: {
            // Reset selection after sheet dismissal
            viewModel.selectedProduct = nil
        }) { product in
            NavigationStack {
                EditProductCoordinator().createEditProductView(
                    product: product,
                    onDismiss: { shouldSave in
                        if !shouldSave {
                            // User dismissed without saving - ensure rollback happens
                            // The EditProductViewModel's deinit will handle rollback as fallback
                            AppLogger.info("Product editing dismissed without saving", category: AppLogger.viewModel)
                        }
                        viewModel.selectedProduct = nil
                    }
                )
            }
        }
        // Alerts queue support
        .alert(item: Binding(
            get: { viewModel.currentAlert },
            set: { _ in viewModel.dismissAlert() }
        )) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK".localized())) {
                    alert.action?()
                }
            )
        }
        .onAppear {
            viewModel.loadProducts()
        }
    }
}

// MARK: - Product Card Component
struct ProductCardView: View {
    let product: Product
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with unit chip and actions
            HStack {
                if let unitName = product.unit?.name?.localized(), !unitName.isEmpty {
                    ProductListUnitChip(title: unitName)
                }

                Spacer()

                HStack(spacing: 12) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.title3)
                            .foregroundColor(Color("AccentColor"))
                            .frame(width: 32, height: 32)
                            .background(Color("AccentColor").opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("EditProductButton")
                    .accessibilityLabel("Edit product")

                    Button(action: { showDeleteConfirmation = true }) {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundColor(.red)
                            .frame(width: 32, height: 32)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("DeleteProductButton")
                    .accessibilityLabel("Delete product")
                }
            }

            // Product name
            Text(product.name ?? "Unnamed Product".localized())
                .font(.title2.weight(.semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .accessibilityIdentifier("ProductNameLabel")
        }
        .padding(20)
        .background(Color("SecondaryBackgroundColor"))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .onTapGesture {
            onEdit()
        }
        .confirmationDialog(
            "Delete Product".localized(),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete".localized(), role: .destructive) {
                onDelete()
            }
            Button("Cancel".localized(), role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this product?".localized())
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Supporting Components
struct ProductListUnitChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [Color("AccentColor"), Color("AccentColor").opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color("AccentColor").opacity(0.3), radius: 2)
    }
}

struct EmptyProductListView: View {
    let onAddProduct: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Illustration
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color("AccentColor").opacity(0.1), Color("AccentColor").opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "cart")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(Color("AccentColor").opacity(0.6))
                )

            VStack(spacing: 12) {
                Text("No Products Yet".localized())
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)

                Text("Start building your pantry by adding your first product".localized())
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            Button(action: onAddProduct) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add Your First Product".localized())
                }
                .font(.body.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color("AccentColor"))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 4)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}

