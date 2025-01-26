//
//  ProductSelectionCoordinator.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 26.01.25.
//

import SwiftUI

class ProductSelectionCoordinator {
    func createProductSelectionView(currentProduct: Product?, onProductSelected: @escaping (Product) -> Void) -> some View {
        let context = PersistenceController.shared.container.viewContext
        let service = ProductSelectionService(context: context)
        let viewModel = ProductSelectionViewModel(productSelectionService: service, currentProduct: currentProduct, onProductSelected: onProductSelected)
        return ProductSelectionView(viewModel: viewModel)
    }
}
