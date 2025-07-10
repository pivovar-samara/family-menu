//
//  DishListView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.01.25.
//

import SwiftUI

struct DishListView: View {
    @StateObject private var viewModel: DishListViewModel
    @State private var showingSortOptions = false

    init(viewModel: DishListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            // Empty state
            if viewModel.filteredDishes.isEmpty {
                if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // No dishes at all – show onboarding empty state
                    EmptyDishListView {
                        viewModel.isAddingNewDish = true
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("dish_list_empty_state")
                } else {
                    // Search yielded no results
                    Color.clear
                        .emptyState(message: "No results found".localized())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("dish_list_no_results_state")
                }
            } else {
                // Dish cards
                ForEach(viewModel.filteredDishes, id: \.self) { dish in
                    DishCardView(
                        dish: dish,
                        onEdit: {
                            viewModel.selectedDish = dish
                        },
                        onDelete: {
                            viewModel.deleteDish(dish)
                        }
                    )
                    .padding(.vertical, 8)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("dish_list_item_\(dish.name ?? "unnamed")")
                }
            }

            // Spacer row to keep content above the floating action button
            Color.clear
                .frame(height: 80)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden) // Keep custom background
        .background(Color("BackgroundColor"))
        .searchable(text: $viewModel.searchText, prompt: "Search dishes...".localized())
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingSortOptions = true
                }) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.body)
                        .foregroundColor(Color("AccentColor"))
                }
                .accessibilityIdentifier("sort_dishes_button")
                .accessibilityLabel("Sort dishes".localized())
                .confirmationDialog("Sort dishes".localized(), isPresented: $showingSortOptions, titleVisibility: .visible) {
                    Button("Name A-Z".localized()) {
                        viewModel.updateSortOption(.nameAscending)
                    }
                    Button("Name Z-A".localized()) {
                        viewModel.updateSortOption(.nameDescending)
                    }
                    Button("Category".localized()) {
                        viewModel.updateSortOption(.category)
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            FloatingActionButton {
                viewModel.isAddingNewDish = true
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
            .accessibilityIdentifier("add_dish_button")
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
        .sheet(item: $viewModel.selectedDish, onDismiss: {
            // Reset selection after sheet dismissal
            viewModel.selectedDish = nil
        }) { dish in
            NavigationStack {
                DishDetailsCoordinator().createDishDetailsView(
                    dish: dish,
                    onDismiss: { shouldSave in
                        if !shouldSave {
                            // User dismissed without saving - ensure rollback happens
                            AppLogger.info("Dish editing dismissed without saving", category: AppLogger.viewModel)
                        }
                        viewModel.selectedDish = nil
                    }
                )
            }
        }
        .sheet(isPresented: $viewModel.isAddingNewDish, onDismiss: {
            viewModel.isAddingNewDish = false
        }) {
            NavigationStack {
                DishDetailsCoordinator().createDishDetailsView()
            }
        }
        .onAppear() {
            viewModel.loadDishes()
        }
    }
}

// MARK: - Dish Card Component
struct DishCardView: View {
    let dish: Dish
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with Category and Actions
            HStack {
                // Category chip
                if let categoryName = dish.category?.name {
                    DishListCategoryChip(
                        title: categoryName.localized(),
                        color: categoryColor(for: categoryName)
                    )
                }
                
                Spacer()
                
                // Action buttons
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
                    .accessibilityIdentifier("edit_dish_button_\(dish.name ?? "unnamed")")
                    .accessibilityLabel("Edit dish")
                    
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundColor(.red)
                            .frame(width: 32, height: 32)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("delete_dish_button_\(dish.name ?? "unnamed")")
                    .accessibilityLabel("Delete dish")
                }
            }
            
            // Main Content
            VStack(alignment: .leading, spacing: 12) {
                // Dish name with icon
                HStack(spacing: 12) {
                    Image(systemName: "fork.knife")
                        .foregroundColor(Color("AccentColor"))
                        .font(.title2)
                        .frame(width: 24, height: 24)
                    
                    Text(dish.name ?? "Unnamed Dish".localized())
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // Description
                if let details = dish.details, !details.isEmpty {
                    Text(details)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                } else {
                    Text("No recipe details".localized())
                        .font(.body)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            // Footer with meal types
            if let mealTypes = dish.mealTypes?.allObjects as? [MealType], !mealTypes.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(mealTypes, id: \.self) { mealType in
                                DishListMealTypeChip(mealType: mealType)
                            }
                        }
                        .padding(.horizontal, 1) // Prevent clipping
                    }
                }
            }
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
        .accessibilityElement(children: .contain)
        .confirmationDialog(
            "Delete Dish".localized(),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete".localized(), role: .destructive) {
                onDelete()
            }
            Button("Cancel".localized(), role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this dish?".localized())
        }
    }
    
    // Helper function to get color for different categories
    private func categoryColor(for categoryName: String) -> Color {
        switch categoryName {
        case "Main Course":
            return Color.blue
        case "Garnish":
            return Color.green
        case "Dessert":
            return Color.orange
        case "Appetizer":
            return Color.purple
        case "Sauce":
            return Color.red
        default:
            return Color.gray
        }
    }
}

// MARK: - Supporting Components

struct DishListCategoryChip: View {
    let title: String
    let color: Color
    
    var body: some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .shadow(color: color.opacity(0.3), radius: 2)
    }
}

struct DishListMealTypeChip: View {
    let mealType: MealType
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: ViewHelper.mealTypeIcon(for: mealType))
                .font(.caption2)
                .foregroundColor(ViewHelper.mealTypeColor(for: mealType))
            
            Text(mealType.name?.localized() ?? "")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color("BackgroundColor"))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ViewHelper.mealTypeColor(for: mealType).opacity(0.3), lineWidth: 1)
        )
    }
}

struct EmptyDishListView: View {
    let onAddDish: () -> Void
    
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
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(Color("AccentColor").opacity(0.6))
                )
            
            VStack(spacing: 12) {
                Text("No Dishes Yet".localized())
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text("Start building your recipe collection by adding your first dish".localized())
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            Button(action: onAddDish) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add Your First Dish".localized())
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

struct FloatingActionButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color("AccentColor"), Color("AccentColor").opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Extensions for ViewModel

extension DishListViewModel {
    func deleteDish(_ dish: Dish) {
        guard let index = filteredDishes.firstIndex(of: dish) else { return }
        deleteDishes(at: IndexSet([index]))
    }
}

