//
//  EditProductCoordinator.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 20.01.25.
//

import SwiftUI

class EditProductCoordinator {
    func createEditProductView(product: Product) -> some View {
        let context = PersistenceController.shared.container.viewContext
        let service = EditProductService(context: context)
        let viewModel = EditProductViewModel(product: product, editProductService: service)
        return EditProductView(viewModel: viewModel)
    }
}
