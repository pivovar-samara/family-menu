//
//  DishDetailsCoordinator.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 24.01.25.
//

import SwiftUI

class DishDetailsCoordinator {
    func createDishDetailsView(
        dish: Dish? = nil, 
        dishDetailsService: DishDetailsServiceProtocol = DishDetailsService(context: PersistenceController.shared.container.viewContext),
        onDismiss: ((Bool) -> Void)? = nil
    ) -> some View {
        let viewModel = DishDetailsViewModel(
            dishDetailsService: dishDetailsService,
            dish: dish,
            onDismiss: onDismiss
        )
        
        return DishDetailsView(viewModel: viewModel)
            .onDisappear {
                // Rely on the ViewModel to decide if a rollback is required.
                AppLogger.info("🔴 DishDetailsView disappeared", category: AppLogger.viewModel)
                viewModel.dismissWithoutSaving()
            }
    }
}
