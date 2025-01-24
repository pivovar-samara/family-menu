//
//  ProductListCoordinator.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 19.01.25.
//

import SwiftUI

class ProductListCoordinator {
    func createProductListView() -> some View {
        let context = PersistenceController.shared.container.viewContext
        let service = ProductListService(context: context)
        let viewModel = ProductListViewModel(productListService: service)
        return ProductListView(viewModel: viewModel)
    }
}
