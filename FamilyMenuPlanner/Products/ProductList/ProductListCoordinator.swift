//
//  ProductListCoordinator.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 19.01.25.
//

import SwiftUI

class ProductListCoordinator {
    func createProductListView(productListService: ProductListServiceProtocol = ProductListService(context: PersistenceController.shared.container.viewContext)) -> some View {
        let viewModel = ProductListViewModel(productListService: productListService)
        return ProductListView(viewModel: viewModel)
    }
}
