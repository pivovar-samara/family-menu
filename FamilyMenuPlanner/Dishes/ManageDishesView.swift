//
//  ManageDishesView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 18.12.24.
//

import SwiftUI

struct ManageDishesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: Dish.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Dish.name, ascending: true)],
        animation: .default
    ) var dishes: FetchedResults<Dish>
    
    @State private var selectedDish: Dish? = nil // For editing
    @State private var isAddingNewDish: Bool = false
    @State private var showAlert: Bool = false
    @State private var currentAlert: Alert? = nil

    var body: some View {
        List {
            if dishes.isEmpty {
                Color.clear.emptyState(message: "No results found".localized())
            } else {
                ForEach(dishes, id: \.self) { dish in
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(dish.name ?? "Unnamed Dish")
                                .font(.headline)
                            Text(dish.details ?? "No Details")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Button(action: {
                            selectedDish = dish // Open the sheet for editing
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(Color("AccentColor"))
                        }
                    }
                    .listRowBackground(Color("SecondaryBackgroundColor"))
                }
                .onDelete(perform: deleteDishes)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("BackgroundColor"))
        .alert(isPresented: $showAlert) {
            currentAlert!
        }
        .sheet(item: $selectedDish) { dish in
            NavigationStack {
                EditDishView(dish: dish)
                .environment(\.managedObjectContext, viewContext)
            }
        }
        .sheet(isPresented: $isAddingNewDish, onDismiss: {
            isAddingNewDish = false
        }) {
            NavigationStack {
                EditDishView()
                .environment(\.managedObjectContext, viewContext)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                createToolbarButton(title: "Add New Dish".localized(), systemImage: "plus") {
                    isAddingNewDish = true
                }
            }
        }
    }
    
    private func deleteDishes(at offsets: IndexSet) {
        do {
            try viewContext.setQueryGenerationFrom(.current)
            
            for index in offsets {
                let dish = dishes[index]
                viewContext.delete(dish)
            }
            
            try viewContext.save()
        } catch {
            currentAlert = AlertHelper.presentAlert(
                title: "Error",
                message: "Failed to delete dishes. Please try again."
            )
            showAlert = true
        }
    }
}
