//
//  ProductSelectionCoordinator.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 26.01.25.
//

import SwiftUI

class ProductSelectionCoordinator {
    func createProductSelectionView(currentProduct: Product?, productSelectionService: ProductSelectionServiceProtocol = ProductSelectionService(context: PersistenceController.shared.container.viewContext), onProductSelected: @escaping (Product) -> Void) -> some View {
        let viewModel = ProductSelectionViewModel(
            productSelectionService: productSelectionService,
            currentProduct: currentProduct,
            onProductSelected: onProductSelected
        )
        return ProductSelectionView(viewModel: viewModel)
    }
}
