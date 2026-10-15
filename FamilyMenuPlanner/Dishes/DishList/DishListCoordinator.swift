//
//  DishListCoordinator.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.01.25.
//

import SwiftUI

class DishListCoordinator {
    /// Called from `ContentView.body` on every render; the service and view model are only built once `DishListView` needs them.
    func createDishListView(dishListService: @autoclosure @escaping () -> DishListServiceProtocol = DishListService(context: PersistenceController.shared.container.viewContext)) -> some View {
        DishListView(viewModel: DishListViewModel(dishListService: dishListService()))
    }
}
