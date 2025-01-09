//
//  EditMenuDishView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 18.12.24.
//

import SwiftUI

struct EditMenuDishView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        entity: Dish.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Dish.name, ascending: true)]
    ) private var allDishes: FetchedResults<Dish>
    
    @State private var searchText: String = ""
    @State private var selectedDish: Dish?
    
    let currentDish: Dish? // Currently selected dish for this day and meal type
    let mealType: String // Meal type for filtering dishes
    let onDishSelected: (Dish) -> Void
    
    var body: some View {
        let (dishesForMealType, otherDishes) = splitDishes()
        List {
            if dishesForMealType.isEmpty && otherDishes.isEmpty {
                Color.clear.emptyState(message: "No results found".localized())
            } else {
                // Section for dishes matching the selected meal type
                if !dishesForMealType.isEmpty {
                    Section(header: Text(("Dishes for \(mealType)").localized())) {
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
        .searchable(text: $searchText, prompt: "Search dishes...")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewContext.rollback()
                    dismiss()
                }
                .foregroundColor(Color("AccentColor"))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("BackgroundColor"))
    }
    
    /// Splits dishes into two sections: those matching the meal type and others.
    private func splitDishes() -> (dishesForMealType: [Dish], otherDishes: [Dish]) {
        var dishesForMealType: [Dish] = []
        var otherDishes: [Dish] = []

        for dish in allDishes {
            // Filter by search text
            let matchesSearch = searchText.isEmpty || (dish.name?.localizedCaseInsensitiveContains(searchText) ?? false)
            
            guard matchesSearch else { continue }
            
            // Determine the section based on meal type
            if let mealTypes = dish.mealTypes as? Set<MealType>, mealTypes.contains(where: { $0.name == mealType }) {
                dishesForMealType.append(dish)
            } else {
                otherDishes.append(dish)
            }
        }

        return (dishesForMealType, otherDishes)
    }
    
    private func dishRow(dish: Dish) -> some View {
        HStack {
            Text((dish.name ?? "Unnamed Dish").localized())
            Spacer()
            if dish == selectedDish || dish == currentDish {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color("AccentColor"))
            }
        }
        .listRowBackground(Color("SecondaryBackgroundColor"))
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDish = dish
            onDishSelected(dish)
            dismiss()
        }
    }
}
