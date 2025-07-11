//
//  EditProductCoordinator.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 20.01.25.
//

import SwiftUI

class EditProductCoordinator {
    func createEditProductView(
        product: Product? = nil, 
        editProductService: EditProductServiceProtocol = EditProductService(context: PersistenceController.shared.container.viewContext),
        onDismiss: ((Bool) -> Void)? = nil
    ) -> some View {
        let viewModel = EditProductViewModel(
            product: product,
            editProductService: editProductService,
            onDismiss: onDismiss
        )
        return EditProductView(viewModel: viewModel)
            .onDisappear {
                // Ensure rollback occurs if the user dismisses the sheet without saving
                AppLogger.info("🔴 EditProductView disappeared", category: AppLogger.viewModel)
                viewModel.dismissWithoutSaving()
            }
    }
}
