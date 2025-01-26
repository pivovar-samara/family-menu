//
//  DishDetailsCoordinator.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.01.25.
//

import SwiftUI

class DishDetailsCoordinator {
    func createDishDetailsView(dish: Dish? = nil) -> some View {
        let context = PersistenceController.shared.container.viewContext
        let service = DishDetailsService(context: context)
        let viewModel = DishDetailsViewModel(dishDetailsService: service, dish: dish)
        return DishDetailsView(viewModel: viewModel)
    }
}
