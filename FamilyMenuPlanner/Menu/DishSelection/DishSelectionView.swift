//
//  EditMenuDishView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 18.12.24.
//

import SwiftUI

struct DishSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: DishSelectionViewModel

    init(viewModel: DishSelectionViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        let (dishesForMealType, otherDishes) = viewModel.splitDishes()
        List {
            if dishesForMealType.isEmpty && otherDishes.isEmpty {
                if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    EmptyDishSelectionView()
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("dish_selection_empty_state")
                } else {
                    ViewHelper.emptyState(Color.clear, message: "No results found".localized())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("dish_selection_no_results_state")
                }
            } else {
                if !dishesForMealType.isEmpty {
                    // Custom header for dishes for meal type
                    Text(String(format: "Dishes for %@".localized(), localizedMealTypeName(viewModel.mealType)))
                        .font(.headline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appBackground)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.appBackground)
                        .listRowSeparator(.hidden)
                    ForEach(dishesForMealType, id: \.self) { dish in
                        DishSelectionCardView(
                            dish: dish,
                            isSelected: viewModel.selectedDishes.contains(dish),
                            onSelect: {
                                if !viewModel.selectedDishes.contains(dish) {
                                    viewModel.selectedDishes.append(dish)
                                } else {
                                    viewModel.selectedDishes.removeAll { $0 == dish }
                                }
                                viewModel.onDishesSelected(viewModel.selectedDishes)
                            }
                        )
                        .padding(.vertical, 6)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("dish_selection_item_\(dish.name ?? "unnamed")")
                    }
                }
                if !otherDishes.isEmpty {
                    // Custom header for other dishes
                    Text("Other Dishes".localized())
                        .font(.headline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appBackground)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.appBackground)
                        .listRowSeparator(.hidden)
                    ForEach(otherDishes, id: \.self) { dish in
                        DishSelectionCardView(
                            dish: dish,
                            isSelected: viewModel.selectedDishes.contains(dish),
                            onSelect: {
                                if !viewModel.selectedDishes.contains(dish) {
                                    viewModel.selectedDishes.append(dish)
                                } else {
                                    viewModel.selectedDishes.removeAll { $0 == dish }
                                }
                                viewModel.onDishesSelected(viewModel.selectedDishes)
                            }
                        )
                        .padding(.vertical, 6)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("dish_selection_item_\(dish.name ?? "unnamed")")
                    }
                }
            }
            Color.clear
                .frame(height: 20)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Select Dish".localized())
        .searchable(text: $viewModel.searchText, prompt: "Search dishes...".localized())
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done".localized()) {
                    dismiss()
                }
                .foregroundColor(Color.accent)
                .accessibilityIdentifier("dish_selection_done_button")
            }
        }
    }
    
    private func dishRow(dish: Dish) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text((dish.name ?? "Unnamed Dish").localized())
                    
                    // Show category badge
                    if let categoryName = dish.category?.name {
                        Text(categoryName.localized())
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(categoryColor(for: categoryName))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    
                    Spacer()
                }
            }
            Spacer()
            if viewModel.selectedDishes.contains(dish) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.accent)
            }
        }
        .listRowBackground(Color.appSecondaryBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            if !viewModel.selectedDishes.contains(dish) {
                viewModel.selectedDishes.append(dish)
            } else {
                viewModel.selectedDishes.removeAll { $0 == dish }
            }
            viewModel.onDishesSelected(viewModel.selectedDishes)
        }
    }
    
    // Helper function to get color for different categories
    private func categoryColor(for categoryName: String) -> Color {
        return StylingHelper.categoryColor(for: categoryName)
    }
}

// Add this helper function inside DishSelectionView
private func localizedMealTypeName(_ mealType: String) -> String {
    // Try to localize the meal type name using the keys in Localizable.strings
    switch mealType {
    case "Breakfast":
        return "Breakfast".localized()
    case "Lunch":
        return "Lunch".localized()
    case "Dinner":
        return "Dinner".localized()
    default:
        return mealType.localized()
    }
}

// MARK: - Card-Based Dish Selection Component
struct DishSelectionCardView: View {
    let dish: Dish
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "fork.knife")
                        .foregroundColor(Color.accent)
                        .font(.title2)
                        .frame(width: 24, height: 24)
                    Text(dish.name ?? "Unnamed Dish".localized())
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color.accent)
                    } else {
                        Image(systemName: "circle")
                            .font(.title2)
                            .foregroundColor(.secondary.opacity(0.3))
                    }
                }
                // Category chip
                if let categoryName = dish.category?.name {
                    DishListCategoryChip(
                        title: categoryName.localized(),
                        color: categoryColor(for: categoryName)
                    )
                }
                // Meal type chips
                if let mealTypes = dish.mealTypes?.allObjects as? [MealType], !mealTypes.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(mealTypes, id: \.self) { mealType in
                            DishListMealTypeChip(mealType: mealType)
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accent.opacity(0.05) : Color.appSecondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color.accent : Color.appBorder,
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier("dish_selection_card_\(dish.name ?? "unnamed")")
        .accessibilityLabel("\(dish.name ?? "Unnamed Dish".localized())")
        .accessibilityHint(isSelected ? "Currently selected".localized() : "Tap to select this dish".localized())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    // Helper function to get color for different categories
    private func categoryColor(for categoryName: String) -> Color {
        return StylingHelper.categoryColor(for: categoryName)
    }
}
// MARK: - Empty State Component
struct EmptyDishSelectionView: View {
    var body: some View {
        VStack(spacing: 24) {
            // Illustration
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.accent.opacity(0.1), Color.accent.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "fork.knife")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(Color.accent.opacity(0.6))
                )
            VStack(spacing: 12) {
                Text("No Dishes Available".localized())
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                Text("Create dishes first to select them for your menu".localized())
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
