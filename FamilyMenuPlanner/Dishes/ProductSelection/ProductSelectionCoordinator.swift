//
//  ProductSelectionCoordinator.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 26.01.25.
//

import SwiftUI

class ProductSelectionCoordinator {
    func createProductSelectionView(
        currentProduct: Product?,
        productSelectionService: ProductSelectionServiceProtocol = ProductSelectionService(context: PersistenceController.shared.container.viewContext),
        selectionMode: ProductSelectionViewModel.SelectionMode = .single,
        preselectedProducts: [Product] = [],
        onProductSelected: @escaping (Product) -> Void,
        onProductsSelected: (([Product]) -> Void)? = nil
    ) -> some View {
        let viewModel = ProductSelectionViewModel(
            productSelectionService: productSelectionService,
            currentProduct: currentProduct,
            selectionMode: selectionMode,
            preselectedProducts: preselectedProducts,
            onProductSelected: onProductSelected,
            onProductsSelected: onProductsSelected
        )
        return ProductSelectionView(viewModel: viewModel)
    }
}
