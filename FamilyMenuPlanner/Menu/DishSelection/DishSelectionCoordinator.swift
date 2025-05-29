//
//  DishSelectionCoordinator.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 18.01.25.
//

import SwiftUI

class DishSelectionCoordinator {
    func createDishSelectionView(currentDishes: [Dish], mealType: String, dishSelectionService: DishSelectionServiceProtocol = DishSelectionService(context: PersistenceController.shared.container.viewContext), onDishesSelected: @escaping ([Dish]) -> Void) -> some View {
        let viewModel = DishSelectionViewModel(
            selectedDishes: currentDishes,
            mealType: mealType,
            dishSelectionService: dishSelectionService,
            onDishesSelected: onDishesSelected
        )
        return DishSelectionView(viewModel: viewModel)
    }
}
