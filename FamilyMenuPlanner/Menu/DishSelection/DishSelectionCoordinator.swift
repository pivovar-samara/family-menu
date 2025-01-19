//
//  DishSelectionCoordinator.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 18.01.25.
//

import SwiftUI

class DishSelectionCoordinator {
    func createDishSelectionView(currentDish: Dish?, mealType: String, onDishSelected: @escaping (Dish) -> Void) -> some View {
        let context = PersistenceController.shared.container.viewContext
        let service = DishSelectionService(context: context)
        let viewModel = DishSelectionViewModel(currentDish: currentDish, mealType: mealType, dishSelectionService: service, onDishSelected: onDishSelected)
        return DishSelectionView(viewModel: viewModel)
    }
}
