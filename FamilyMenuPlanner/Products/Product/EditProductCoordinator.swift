//
//  EditProductCoordinator.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 20.01.25.
//

import SwiftUI

class EditProductCoordinator {
    func createEditProductView(product: Product, editProductService: EditProductServiceProtocol = EditProductService(context: PersistenceController.shared.container.viewContext)) -> some View {
        let viewModel = EditProductViewModel(
            product: product,
            editProductService: editProductService
        )
        return EditProductView(viewModel: viewModel)
    }
}
