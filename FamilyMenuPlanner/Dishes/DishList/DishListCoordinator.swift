//
//  DishListCoordinator.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.01.25.
//

import SwiftUI

class DishListCoordinator {
    func createDishListView() -> some View {
        let context = PersistenceController.shared.container.viewContext
        let service = DishListService(context: context)
        let viewModel = DishListViewModel(dishListService: service)
        return DishListView(viewModel: viewModel)
    }
}
