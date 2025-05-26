//
//  MenuCoordinator.swift
//  FamilyMenuPlanner
//
//  Created by Ilya Khokhlov on 14.01.25.
//

import SwiftUI

class MenuCoordinator {
    func createMenuView(menuService: MenuServiceProtocol = MenuService(context: PersistenceController.shared.container.viewContext)) -> some View {
        let viewModel = MenuViewModel(menuService: menuService)
        return MenuView(viewModel: viewModel)
    }
}
