//
//  ProductListCoordinator.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 19.01.25.
//

import SwiftUI

class ProductListCoordinator {
    /// Called from `ContentView.body` on every render; the service and view model are only built once `ProductListView` needs them.
    func createProductListView(productListService: @autoclosure @escaping () -> ProductListServiceProtocol = ProductListService(context: PersistenceController.shared.container.viewContext)) -> some View {
        ProductListView(viewModel: ProductListViewModel(productListService: productListService()))
    }
}
