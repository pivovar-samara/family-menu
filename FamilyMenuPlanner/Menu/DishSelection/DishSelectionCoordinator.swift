//
//  DishSelectionCoordinator.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 18.01.25.
//

import SwiftUI

class DishSelectionCoordinator {
    func createDishSelectionView(currentDishes: [Dish], mealType: String, onDishesSelected: @escaping ([Dish]) -> Void) -> some View {
        let context = PersistenceController.shared.container.viewContext
        let service = DishSelectionService(context: context)
        let viewModel = DishSelectionViewModel(selectedDishes: currentDishes, mealType: mealType, dishSelectionService: service, onDishesSelected: onDishesSelected)
        return DishSelectionView(viewModel: viewModel)
    }
}
