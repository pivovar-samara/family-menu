//
//  DishDetailsCoordinator.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.01.25.
//

import SwiftUI

class DishDetailsCoordinator {
    func createDishDetailsView(dish: Dish? = nil, dishDetailsService: DishDetailsServiceProtocol = DishDetailsService(context: PersistenceController.shared.container.viewContext)) -> some View {
        let viewModel = DishDetailsViewModel(
            dishDetailsService: dishDetailsService,
            dish: dish
        )
        return DishDetailsView(viewModel: viewModel)
    }
}
