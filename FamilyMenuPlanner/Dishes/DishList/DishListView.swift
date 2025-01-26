//
//  DishListView.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.01.25.
//

import SwiftUI

struct DishListView: View {
    @StateObject private var viewModel: DishListViewModel

    init(viewModel: DishListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            if viewModel.dishes.isEmpty {
                Color.clear.emptyState(message: "No results found".localized())
            } else {
                ForEach(viewModel.dishes, id: \.self) { dish in
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(dish.name ?? "Unnamed Dish".localized())
                                .font(.headline)
                            Text(dish.details ?? "No Details".localized())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Button(action: {
                            viewModel.selectedDish = dish // Open the sheet for editing
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(Color("AccentColor"))
                        }
                    }
                    .listRowBackground(Color("SecondaryBackgroundColor"))
                }
                .onDelete(perform: viewModel.deleteDishes)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("BackgroundColor"))
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
        .sheet(item: $viewModel.selectedDish) { dish in
            NavigationStack {
                DishDetailsCoordinator().createDishDetailsView(dish: dish)
            }
        }
        .sheet(isPresented: $viewModel.isAddingNewDish, onDismiss: {
            viewModel.isAddingNewDish = false
        }) {
            NavigationStack {
                DishDetailsCoordinator().createDishDetailsView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                createToolbarButton(title: "Add New Dish".localized(), systemImage: "plus") {
                    viewModel.isAddingNewDish = true
                }
            }
        }
        .onAppear() {
            viewModel.loadDishes()
        }
    }
    
}

