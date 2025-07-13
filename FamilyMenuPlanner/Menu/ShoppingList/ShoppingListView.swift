//
//  ShoppingListView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 18.12.24.
//

import SwiftUI

struct ShoppingListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ShoppingListViewModel()
    @State private var showingSortOptions = false
    @State private var showingSelectionOptions = false
    
    let shoppingList: [String: [String: Double]] // Dictionary where key is the product name and value is quantity with unit
    let weekDate: Date // The date for the current week
    
    var body: some View {
        List {
            listContent
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color("BackgroundColor"))
        .navigationTitle("Shopping List".localized())
        .searchable(text: $viewModel.searchText, prompt: "Search items...".localized())
        .toolbar { toolbarContent }
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
            viewModel.clearOldSelections()
            viewModel.loadShoppingList(from: shoppingList, for: weekDate)
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if viewModel.filteredItems.isEmpty {
            if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                EmptyShoppingListView()
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("shopping_list_empty_state")
            } else {
                Color.clear
                    .emptyState(message: "No results found".localized())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("shopping_list_no_results_state")
            }
        } else {
            ForEach(viewModel.filteredItems, id: \.id) { item in
                ShoppingListCardView(
                    item: item,
                    onToggleSelection: {
                        viewModel.toggleSelection(for: item)
                    }
                )
                .padding(.vertical, 8)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("shopping_list_item_\(item.productName)")
            }
        }
        Color.clear
            .frame(height: 20)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Close".localized()) {
                dismiss()
            }
            .foregroundColor(Color("AccentColor"))
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 12) {
                // Selection options button
                if !viewModel.shoppingItems.isEmpty {
                    Button(action: {
                        showingSelectionOptions = true
                    }) {
                        Image(systemName: "checkmark.circle")
                            .font(.body)
                            .foregroundColor(Color("AccentColor"))
                    }
                    .accessibilityIdentifier("selection_options_button")
                    .accessibilityLabel("Selection options".localized())
                    .confirmationDialog("Selection options".localized(), isPresented: $showingSelectionOptions, titleVisibility: .visible) {
                        Button("Select All".localized()) {
                            viewModel.selectAll()
                        }
                        Button("Deselect All".localized()) {
                            viewModel.deselectAll()
                        }
                        Button("Cancel".localized(), role: .cancel) {}
                    }
                }
                // Sort button
                Button(action: {
                    showingSortOptions = true
                }) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.body)
                        .foregroundColor(Color("AccentColor"))
                }
                .accessibilityIdentifier("sort_shopping_list_button")
                .accessibilityLabel("Sort shopping list".localized())
                .confirmationDialog("Sort shopping list".localized(), isPresented: $showingSortOptions, titleVisibility: .visible) {
                    ForEach(ShoppingListSortOption.allCases, id: \.self) { option in
                        Button(option.displayName) {
                            viewModel.updateSortOption(option)
                        }
                    }
                    Button("Cancel".localized(), role: .cancel) {}
                }
            }
        }
    }
}

// MARK: - Shopping List Card Component
struct ShoppingListCardView: View {
    let item: ShoppingListItem
    let onToggleSelection: () -> Void
    
    var body: some View {
        Button(action: onToggleSelection) {
            HStack(spacing: 16) {
                // Selection checkbox
                ZStack {
                    Circle()
                        .fill(item.isSelected ? Color("AccentColor") : Color("AccentColor").opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    if item.isSelected {
                        Image(systemName: "checkmark")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "circle")
                            .font(.title3)
                            .foregroundColor(Color("AccentColor"))
                    }
                }
                
                // Item Information
                VStack(alignment: .leading, spacing: 8) {
                    // Product name
                    Text(item.productName)
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .strikethrough(item.isSelected)
                    
                    // Quantity and unit
                    HStack(spacing: 4) {
                        Image(systemName: "scalemass")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("\(formattedDoubleForUnits(item.quantity)) \(item.unitName.localized())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Shopping cart icon
                Image(systemName: "cart")
                    .font(.title3)
                    .foregroundColor(item.isSelected ? .green : Color("AccentColor"))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(item.isSelected ? Color.green.opacity(0.05) : Color("SecondaryBackgroundColor"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                item.isSelected ? Color.green : Color.gray.opacity(0.2),
                                lineWidth: item.isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(ShoppingListScaleButtonStyle())
        .accessibilityIdentifier("shopping_list_card_\(item.productName)")
        .accessibilityLabel("\(item.productName), \(formattedDoubleForUnits(item.quantity)) \(item.unitName.localized())")
        .accessibilityHint(item.isSelected ? "Selected".localized() : "Tap to select this item".localized())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: item.isSelected)
    }
}

// MARK: - Empty State Component
struct EmptyShoppingListView: View {
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
                Text("No Shopping Items".localized())
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)

                Text("Generate a menu first to see your shopping list".localized())
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Scale Button Style
struct ShoppingListScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

