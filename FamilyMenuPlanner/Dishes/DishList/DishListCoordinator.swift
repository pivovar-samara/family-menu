//
//  DishListCoordinator.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.01.25.
//

import SwiftUI

class DishListCoordinator {
    func createDishListView(dishListService: DishListServiceProtocol = DishListService(context: PersistenceController.shared.container.viewContext)) -> some View {
        let viewModel = DishListViewModel(dishListService: dishListService)
        return DishListView(viewModel: viewModel)
    }
}
