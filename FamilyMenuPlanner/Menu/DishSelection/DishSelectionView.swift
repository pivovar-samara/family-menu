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
                Color.clear.emptyState(message: "No results found".localized())
            } else {
                // Section for dishes matching the selected meal type
                if !dishesForMealType.isEmpty {
                    Section(header: Text(("Dishes for \(viewModel.mealType)").localized())) {
                        ForEach(dishesForMealType, id: \.self) { dish in
                            dishRow(dish: dish)
                        }
                    }
                }
                
                // Section for other dishes
                if !otherDishes.isEmpty {
                    Section(header: Text("Other Dishes")) {
                        ForEach(otherDishes, id: \.self) { dish in
                            dishRow(dish: dish)
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Dish")
        .searchable(text: $viewModel.searchText, prompt: "Search dishes...")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.rollback()
                    dismiss()
                }
                .foregroundColor(Color("AccentColor"))
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    dismiss()
                }
                .foregroundColor(Color("AccentColor"))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("BackgroundColor"))
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
                    .foregroundColor(Color("AccentColor"))
            }
        }
        .listRowBackground(Color("SecondaryBackgroundColor"))
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
