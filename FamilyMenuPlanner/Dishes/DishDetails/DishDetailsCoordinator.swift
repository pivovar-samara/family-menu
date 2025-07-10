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
                // Ensure rollback happens when view disappears (including swipe dismiss)
                // This is needed because the complex TabView structure prevents reliable deinit calls
                AppLogger.info("🔴 DishDetailsView disappeared - ensuring cleanup", category: AppLogger.viewModel)
                viewModel.dismissWithoutSaving()
            }
    }
}
